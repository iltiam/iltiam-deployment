#!/usr/bin/env bash
# Probe one environment's object storage with its own OCI Customer Secret Key (Runbook 8, issue #13): what the backend
# and the AI service will do with it, what the key must be refused, and whether OCI accepts the backend's AES256
# upload header.
#
# Usage, in Git Bash on a laptop (Docker Desktop running) or on iltiam-1:
#   bash scripts/check-storage.sh <staging|production>
#
# From the environment, or asked for with hidden input when unset (never arguments: they show up in `ps`):
#   STORAGE_ACCESS_KEY, STORAGE_SECRET_KEY  the environment's Customer Secret Key (Runbook 8)
#   STORAGE_NAMESPACE                        the Object Storage namespace: not a credential, but it names the tenancy
# Optional:
#   STORAGE_ENDPOINT_URL  test this endpoint only (then STORAGE_NAMESPACE isn't needed); by default both OCI domains
#                         of the region are tried, and the output says which one works
#   STORAGE_REGION        me-riyadh-1 when unset
#
# It runs boto3, the backend's own S3 library, in a pinned python image, so the probe sends what the backend sends.
# (The AWS CLI can't presign a PUT, which the AI service's mask upload needs.) boto3 1.36 and later add CRC32
# checksums to every upload by default, which OCI answers with 501 NotImplemented, so the client asks for checksums
# only when an operation requires them (request/response_checksum_calculation "when_required"). The backend needs
# the same setting (iltiam-backend#80).
#
# Output lines, never a key, the namespace, an endpoint or a URL:
#   PASS / FAIL  a check passed or failed
#   KEY          OCI didn't accept the key's signature, even after 3 tries: a new key can take a few minutes to reach
#                every OCI server. Not counted as a failure; wait 10 minutes and run again
#   SKIP         not run, because a check it depends on didn't pass, or the answer proves nothing
#   NOTE         facts for iltiam-backend#80; not counted
# Exit 0 when nothing failed and every signature was accepted; 1 when a check failed; 2 when nothing failed but some
# signatures weren't accepted (KEY lines). Costs about 60 storage requests (of the 50,000 free a month). Leaves small objects under .healthcheck/ in
# the environment's buckets; the key can't delete them (by design), and the lifecycle rule removes their old versions.

set -euo pipefail

PYTHON_IMAGE=python:3.13.15-slim
# boto3 and botocore are released together with the same version number.
BOTO3_VERSION=1.43.114

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 1 && ("$1" == staging || "$1" == production) ]] || die "usage: $0 <staging|production>"
env_name="$1"
command -v docker >/dev/null 2>&1 || die "docker not found (on a laptop: start Docker Desktop)"

# Read NAME with hidden input when it isn't in the environment already, then export it for `docker run -e NAME`.
ask() {
  local name="$1" prompt="$2" value
  if [[ -z "${!name:-}" ]]; then
    [[ -t 0 ]] || die "$name is not set"
    read -rs -p "$prompt: " value
    printf '\n' >&2
    export "$name=$value"
  fi
  [[ -n "${!name}" ]] || die "$name is empty"
  [[ ! "${!name}" =~ [[:space:]\'\"] ]] || die "$name contains a space or a quote: copy it again"
}

if [[ -z "${STORAGE_ENDPOINT_URL:-}" ]]; then
  ask STORAGE_NAMESPACE "Object Storage namespace (hidden)"
  [[ "$STORAGE_NAMESPACE" =~ ^[a-z0-9]+$ ]] || die "STORAGE_NAMESPACE must be lower-case letters and digits"
fi
ask STORAGE_ACCESS_KEY "Access key of the $env_name storage user (hidden)"
ask STORAGE_SECRET_KEY "Secret key of the $env_name storage user (hidden)"
export STORAGE_ACCESS_KEY STORAGE_SECRET_KEY

printf '==> pulling %s and installing boto3 %s (first run: about a minute)\n' "$PYTHON_IMAGE" "$BOTO3_VERSION" >&2

# `-e NAME` without a value copies NAME from this shell, so no value is on the command line. Unset names stay unset.
MSYS_NO_PATHCONV=1 docker run --rm -i \
  -e STORAGE_ACCESS_KEY -e STORAGE_SECRET_KEY -e STORAGE_NAMESPACE -e STORAGE_ENDPOINT_URL -e STORAGE_REGION \
  -e PROBE_ENV="$env_name" -e PIP_DISABLE_PIP_VERSION_CHECK=1 -e PYTHONDONTWRITEBYTECODE=1 \
  "$PYTHON_IMAGE" sh -c "pip install --quiet --root-user-action=ignore boto3==$BOTO3_VERSION \
    botocore==$BOTO3_VERSION </dev/null >&2 && exec python -u -" <<'PY'
import io
import os
import re
import sys
import time
import urllib.error
import urllib.request

import boto3
from boto3.exceptions import Boto3Error
from boto3.s3.transfer import TransferConfig
from botocore import UNSIGNED
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

ENV = os.environ["PROBE_ENV"]
PREFIXES = {"staging": "iltiam-staging", "production": "iltiam-prod"}
OWN = PREFIXES[ENV]
OTHER = PREFIXES["production" if ENV == "staging" else "staging"]
CLASSES = ("wound-images", "wound-masks", "reports", "prescriptions", "profile-photos")
IMAGES = f"{OWN}-wound-images"
REGION = os.environ.get("STORAGE_REGION") or "me-riyadh-1"
KEY = ".healthcheck/check-storage.txt"
BASE_KEY = ".healthcheck/check-storage-baseline.txt"
AES_KEY = ".healthcheck/check-storage-aes256.txt"
MULTIPART_BASE_KEY = ".healthcheck/check-storage-multipart-baseline.bin"
MULTIPART_AES_KEY = ".healthcheck/check-storage-multipart-aes256.bin"
MASK_KEY = ".healthcheck/check-storage-mask.png"
MIB = 1024 * 1024
SIGNATURE = "SignatureDoesNotMatch"
TRIES, WAIT_S = 3, 3
KEY_HINT = f"{SIGNATURE} after {TRIES} tries"
CHECKSUMS = {"request_checksum_calculation": "when_required", "response_checksum_validation": "when_required"}
ERRORS = (ClientError, BotoCoreError, Boto3Error, OSError)
counts = dict.fromkeys(("PASS", "FAIL", "KEY", "SKIP"), 0)


def safe(text):
    """Only characters an error code or status needs, so a stray value can never reach the output."""
    return re.sub(r"[^A-Za-z0-9 ():._-]", "", str(text))[:80]


def code_of(exc):
    return exc.response.get("Error", {}).get("Code", "") if isinstance(exc, ClientError) else ""


def status_of(exc):
    return exc.response.get("ResponseMetadata", {}).get("HTTPStatusCode") if isinstance(exc, ClientError) else None


def why(exc):
    """The error code and HTTP status. Never str(exc): it can hold the endpoint, which names the tenancy."""
    if isinstance(exc, ClientError):
        return safe(f"{code_of(exc) or '?'} (HTTP {status_of(exc)})")
    return safe(type(exc).__name__)


def result(word, label, detail=""):
    counts[word] += 1
    print(f"  {word:<4}  {label}" + (f": {detail}" if detail else ""))


def note(label, detail):
    print(f"  NOTE  {label}: {detail}")


def section(title):
    print(f"\n==> {title}")


def call(fn, disambiguate=None):
    """('ok', value), ('key', None) or ('err', exc). A SignatureDoesNotMatch is retried: a new key reaches OCI's
    servers one by one. A HEAD answer has no body, so its bare 403 can't say why: with `disambiguate` (a ListObjects
    on the same bucket, which has a body) it is retried too, then that call decides between a key problem and a real
    refusal."""
    last = None
    for attempt in range(TRIES):
        try:
            return "ok", fn()
        except ClientError as exc:
            bare_403 = disambiguate is not None and status_of(exc) == 403 and code_of(exc) in ("", "403")
            if code_of(exc) != SIGNATURE and not bare_403:
                return "err", exc
            last = exc
        except ERRORS as exc:
            return "err", exc
        if attempt < TRIES - 1:
            time.sleep(WAIT_S)
    if code_of(last) == SIGNATURE:
        return "key", None
    kind, _ = call(disambiguate)
    return ("key", None) if kind == "key" else ("err", last)


def allowed(label, fn, check=None, disambiguate=None):
    """PASS when the call succeeds and `check(value)` gives (True, detail). Returns (passed, value)."""
    kind, value = call(fn, disambiguate)
    if kind == "key":
        result("KEY", label, KEY_HINT)
        return False, None
    if kind == "err":
        result("FAIL", label, why(value))
        return False, None
    ok, detail = check(value) if check else (True, "")
    result("PASS" if ok else "FAIL", label, detail)
    return ok, value


def refused(label, fn, disambiguate=None):
    """PASS when OCI refuses with 403 or 404 (OCI answers 404 for a bucket the key may not see). NoSuchKey proves
    nothing (the key may read the bucket, and the object just isn't there), so it is a SKIP."""
    kind, value = call(fn, disambiguate)
    if kind == "key":
        result("KEY", label, KEY_HINT)
    elif kind == "ok":
        result("FAIL", label, "ALLOWED: this key reaches it")
    elif code_of(value) == "NoSuchKey":
        result("SKIP", label, "inconclusive, NoSuchKey: the ListObjects and PutObject lines decide")
    elif status_of(value) in (403, 404):
        result("PASS", label, f"refused, {why(value)}")
    else:
        result("FAIL", label, f"not a permission refusal, {why(value)}")
    return kind


def skip(label, needs):
    result("SKIP", label, f"needs {needs}")


def client(endpoint, signed=True):
    """The backend's settings (apps/storage/backends.py): SigV4, path-style addressing; plus checksums only when
    required, which OCI needs."""
    config = Config(
        signature_version="s3v4" if signed else UNSIGNED,
        s3={"addressing_style": "path"},
        connect_timeout=10,
        read_timeout=30,
        retries={"max_attempts": 2},
        **CHECKSUMS,
    )
    keys = {}
    if signed:
        keys = {
            "aws_access_key_id": os.environ["STORAGE_ACCESS_KEY"],
            "aws_secret_access_key": os.environ["STORAGE_SECRET_KEY"],
        }
    return boto3.client("s3", endpoint_url=endpoint, region_name=REGION, config=config, **keys)


def http(method, url, body=None, content_type=None, retry_signature=True):
    """A plain HTTP call, as a phone or the AI service makes it: ('ok', (status, body)) or ('key', None).
    The URL is never printed."""
    headers = {"Content-Type": content_type} if content_type else {}
    for attempt in range(TRIES):
        request = urllib.request.Request(url, data=body, method=method, headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return "ok", (response.status, response.read())
        except urllib.error.HTTPError as exc:
            answer = (exc.code, exc.read())
        except OSError as exc:
            return "ok", (safe(type(exc).__name__), b"")
        if not (retry_signature and answer[0] == 403 and SIGNATURE.encode() in answer[1]):
            return "ok", answer
        if attempt < TRIES - 1:
            time.sleep(WAIT_S)
    return "key", None


def http_check(label, outcome, expected_status, expected_body=None):
    kind, answer = outcome
    if kind == "key":
        result("KEY", label, KEY_HINT)
        return False
    status, body = answer
    ok = status == expected_status and (expected_body is None or body == expected_body)
    result("PASS" if ok else "FAIL", label, f"HTTP {status}" + ("" if ok or expected_body is None else ", other content"))
    return ok


def list_one(s3, bucket):
    return lambda: s3.list_objects_v2(Bucket=bucket, MaxKeys=1)


def put(s3, bucket, key, **extra):
    return lambda: s3.put_object(Bucket=bucket, Key=key, Body=b"ok", ContentType="text/plain", **extra)


def multipart(s3, key, **extra):
    """6 MiB in two parts, the way django-storages sends a photo over its 8 MB threshold (upload_fileobj)."""
    return lambda: s3.upload_fileobj(
        io.BytesIO(b"\0" * (6 * MIB)),
        IMAGES,
        key,
        ExtraArgs={"ContentType": "application/octet-stream", **extra},
        Config=TransferConfig(multipart_threshold=5 * MIB, multipart_chunksize=5 * MIB, use_threads=False),
    )


print(f"check-storage {ENV}: buckets {OWN}-*, region {REGION}, boto3 {boto3.__version__}")
note("checksum mode", ", ".join(f"{name}={value}" for name, value in CHECKSUMS.items()))

# --- 1. Endpoint ---------------------------------------------------------------------------------------------------
section(f"1. endpoint (signed ListObjects on {IMAGES})")
if os.environ.get("STORAGE_ENDPOINT_URL"):
    candidates = [("STORAGE_ENDPOINT_URL", os.environ["STORAGE_ENDPOINT_URL"])]
else:
    namespace = os.environ["STORAGE_NAMESPACE"]
    candidates = [
        (domain, f"https://{namespace}.compat.objectstorage.{REGION}.{domain}")
        for domain in ("oci.customer-oci.com", "oraclecloud.com")
    ]
endpoint, key_trouble = None, False
for name, url in candidates:
    kind, value = call(list_one(client(url), IMAGES))
    if kind == "ok":
        note(f"domain {name}", "works")
        endpoint = endpoint or (name, url)
    elif kind == "key":
        note(f"domain {name}", f"undecided, {KEY_HINT}")
        key_trouble = True
    else:
        note(f"domain {name}", f"does not work, {why(value)}")
if endpoint is None:
    if key_trouble:
        result("KEY", "an endpoint accepts this key", KEY_HINT)
        print("\nStopped: key not propagated yet or wrong secret. Wait 10 minutes and run again.")
        sys.exit(2)
    result("FAIL", "an endpoint accepts this key", "none did")
    print("\nStopped: nothing else can work. Check the namespace, the key and the bucket names (Runbook 8).")
    sys.exit(1)
result("PASS", "an endpoint accepts this key", f"using {endpoint[0]}")
s3 = client(endpoint[1])
anonymous = client(endpoint[1], signed=False)

# --- 2. Own buckets --------------------------------------------------------------------------------------------------
section(f"2. own buckets: read, write, private ({OWN}-*)")
written = {}
for cls in CLASSES:
    bucket = f"{OWN}-{cls}"
    allowed(f"{bucket}: HeadBucket", lambda: s3.head_bucket(Bucket=bucket), disambiguate=list_one(s3, bucket))
    allowed(f"{bucket}: ListObjects", list_one(s3, bucket))
    written[cls], _ = allowed(f"{bucket}: PutObject", put(s3, bucket, KEY))
    label = f"{bucket}: GetObject returns what was written"
    if written[cls]:
        allowed(
            label,
            lambda: s3.get_object(Bucket=bucket, Key=KEY)["Body"].read(),
            lambda body: (body == b"ok", "" if body == b"ok" else "other content"),
        )
    else:
        skip(label, "the PutObject above")
    refused(f"{bucket}: anonymous (unsigned) GetObject", lambda: anonymous.get_object(Bucket=bucket, Key=KEY))

# --- 3. The AES256 header ------------------------------------------------------------------------------------------
section("3. AES256 HEADER TEST: every backend upload sends x-amz-server-side-encryption: AES256")
print("        (each pair: a baseline without the header, then the same with it; only the pair decides)")


def aes_pair(what, baseline, with_aes):
    """Run the baseline, then the AES256 call. Only 'baseline passed, AES256 failed' blames the header."""
    base_ok, _ = allowed(f"{what}, baseline without the header", baseline)
    label = f"{what} with ServerSideEncryption=AES256"
    if not base_ok:
        skip(label, "the baseline: the AES256 test is inconclusive until it passes")
        return False
    kind, value = call(with_aes)
    if kind == "key":
        result("KEY", label, KEY_HINT)
    elif kind == "ok":
        result("PASS", label, "OCI ACCEPTS the AES256 header")
        return True
    else:
        result("FAIL", label, f"OCI REFUSES the AES256 header, {why(value)} (the baseline passed)")
        print("        -> every backend upload would fail: iltiam-backend#80")
    return False


if aes_pair(f"{IMAGES}: PutObject", put(s3, IMAGES, BASE_KEY), put(s3, IMAGES, AES_KEY, ServerSideEncryption="AES256")):
    kind, head = call(lambda: s3.head_object(Bucket=IMAGES, Key=AES_KEY))
    if kind == "ok":
        note("HeadObject ServerSideEncryption", safe(head.get("ServerSideEncryption") or "not returned"))
        note("HeadObject SSEKMSKeyId", "returned" if head.get("SSEKMSKeyId") else "not returned")
    else:
        note("HeadObject after it", KEY_HINT if kind == "key" else why(head))
aes_pair(
    f"{IMAGES}: multipart upload (6 MiB, 2 parts)",
    multipart(s3, MULTIPART_BASE_KEY),
    multipart(s3, MULTIPART_AES_KEY, ServerSideEncryption="AES256"),
)

# --- 4. What manage.py check_storage calls (iltiam-backend#80; not counted) ---------------------------------------
section("4. check_storage's bucket calls (NOTE only, for iltiam-backend#80)")
kind, value = call(lambda: s3.get_bucket_encryption(Bucket=IMAGES))
if kind == "ok":
    rules = value.get("ServerSideEncryptionConfiguration", {}).get("Rules", [])
    algorithms = sorted({r.get("ApplyServerSideEncryptionByDefault", {}).get("SSEAlgorithm", "?") for r in rules})
    note("GetBucketEncryption", "answers, algorithm " + safe(",".join(algorithms) or "none"))
else:
    note("GetBucketEncryption", KEY_HINT if kind == "key" else f"fails, {why(value)}")
kind, value = call(lambda: s3.get_bucket_versioning(Bucket=IMAGES))
if kind == "ok":
    note("GetBucketVersioning", "answers, Status " + safe(value.get("Status", "none")))
else:
    note("GetBucketVersioning", KEY_HINT if kind == "key" else f"fails, {why(value)}")

# --- 5. Presigned URLs -----------------------------------------------------------------------------------------------
section("5. presigned URLs: download links (web, phone) and the AI mask upload")
label = "presigned GET, as a browser or phone opens a photo"
if written["wound-images"]:
    get_url = s3.generate_presigned_url("get_object", Params={"Bucket": IMAGES, "Key": KEY}, ExpiresIn=60)
    http_check(label, http("GET", get_url), 200, b"ok")
else:
    skip(label, f"the PutObject on {IMAGES}")
masks = f"{OWN}-wound-masks"
put_url = s3.generate_presigned_url(
    "put_object", Params={"Bucket": masks, "Key": MASK_KEY, "ContentType": "image/png"}, ExpiresIn=120, HttpMethod="PUT"
)
mask_ok = http_check(
    "presigned PUT with Content-Type only, as the AI service uploads a mask",
    http("PUT", put_url, b"\x89PNG probe", "image/png"),
    200,
)
label = "the same presigned PUT with another Content-Type is refused"
if mask_ok:
    # A wrong Content-Type *is* a signature mismatch, so no retry here: the line above proved the key works.
    http_check(label, http("PUT", put_url, b"\x89PNG probe", "text/plain", retry_signature=False), 403)
else:
    skip(label, "the presigned PUT above")

# --- 6. No deletes ---------------------------------------------------------------------------------------------------
section("6. no deletes (the backend never hard-deletes)")
label = f"{IMAGES}: DeleteObject"
if written["wound-images"]:
    refused(label, lambda: s3.delete_object(Bucket=IMAGES, Key=KEY))
else:
    skip(label, f"an object to delete (the PutObject on {IMAGES})")


# --- 7. The other environment and the backups bucket -------------------------------------------------------------------
def must_not_reach(bucket):
    refused(f"{bucket}: HeadBucket", lambda: s3.head_bucket(Bucket=bucket), disambiguate=list_one(s3, bucket))
    refused(f"{bucket}: ListObjects", list_one(s3, bucket))
    refused(f"{bucket}: GetObject", lambda: s3.get_object(Bucket=bucket, Key=KEY))
    refused(f"{bucket}: PutObject", put(s3, bucket, KEY))


section(f"7. CROSS-ENVIRONMENT REFUSAL TEST: this {ENV} key must reach no {OTHER}-* bucket")
print("        (meaningful once all 12 buckets exist: a missing bucket also answers 404)")
for cls in CLASSES[1:] + ("backups",):
    bucket = f"{OTHER}-{cls}"
    refused(f"{bucket}: HeadBucket", lambda: s3.head_bucket(Bucket=bucket), disambiguate=list_one(s3, bucket))
must_not_reach(f"{OTHER}-wound-images")

section(f"8. OWN BACKUPS BUCKET: the backend key must not reach {OWN}-backups either")
must_not_reach(f"{OWN}-backups")

print(f"\n==> {counts['PASS']} passed, {counts['FAIL']} failed, {counts['KEY']} key not accepted, {counts['SKIP']} skipped")
if counts["KEY"]:
    print("    KEY lines: key not propagated yet or wrong secret. Wait 10 minutes and run again.")
sys.exit(1 if counts["FAIL"] else 2 if counts["KEY"] else 0)
PY
