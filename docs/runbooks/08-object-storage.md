# Runbook 8: object storage within the free 20 GB, software Vault keys, S3 credentials

- **Issue:** iltiam/iltiam-deployment#13 (DEP-02). **Decision record:** [ADR-0004](../adr/0004-hosting.md), Decision 1. **Backend side:** iltiam/iltiam-backend#80 (BE-21).
- **Who:** anyone on the team with an administrator login to the OCI console (Runbook 1, section 3) and admin rights on `iltiam/iltiam-deployment`. No cloud experience needed; follow the steps in order.
- **Time:** about 2 hours the first time for both environments' buckets and staging's access. Production's access (section 9.6) takes about 20 minutes later.
- **Result:**
  - a Vault `iltiam` with one **software-protected** AES-256 key per environment (free);
  - **12 private buckets** in Riyadh: five for the backend's files and one for backups, per environment. Each is encrypted with its environment's key;
  - lifecycle rules that remove old object versions after 30 days;
  - per environment, a storage user whose key can read and write **only its own five backend buckets**: no delete, no backups, nothing of the other environment;
  - the key and the storage settings in the GitHub Environment;
  - alarms at 70 % of the free 20 GB and on the request count.

> **This repository is public. Never paste a secret into this runbook, an issue, a PR, a commit or a chat.** That includes the Customer Secret Keys, the Object Storage **namespace** (it names the tenancy), OCIDs and any presigned link. Use the placeholders below. The probe's output (section 10) contains none of these and may be pasted.

| Placeholder | Meaning |
|---|---|
| `<NAMESPACE>` | The Object Storage namespace (section 4.1) |
| `<ENV>` | `staging` or `production`: the GitHub Environment |
| `<SHORT>` | `staging` or `prod`: the short name in OCI names (`iltiam-prod-wound-images`, like the Compose project `iltiam-prod`) |
| `<SERVICE_USER_EMAIL>` | An address for the storage user, e.g. a plus-address of the team mailbox. Never written here |
| `<YOUR_EMAIL>`, `<TEAMMATE_EMAIL>` | Alarm recipients |

Console menu names move between Oracle console releases. If a menu below is not where this says, type its name into the console's search bar.

## As built

Filled in when the steps are done. Names and dates only: never the namespace, an OCID or a key.

| Item | Value |
|---|---|
| Account | Free Tier (Always Free, not upgraded), since 2026-10-27 |
| S3 endpoint | `https://<NAMESPACE>.compat.objectstorage.me-riyadh-1.oci.customer-oci.com`, path-style. The older `…oraclecloud.com` form also works (probe, 2026-10-29) |
| S3 designated compartment (section 4.2) | `iltiam` |
| Vault and keys (section 5) | vault `iltiam` (default, not virtual private); keys `iltiam-staging-objects` and `iltiam-prod-objects`, Software, AES-256, 2026-10-29 |
| Service policy (section 6) | `iltiam-objectstorage-key-policy`: `use keys` and `manage object-family` in compartment `iltiam` |
| Buckets (section 7) | the 12 of section 7: private, Standard, the environment's Vault key, versioning on the 10 backend buckets and off on the two `-backups`, 2026-10-29 |
| Lifecycle rules (section 8) | `delete-old-versions` (previous versions, 30 days) and `abort-unfinished-uploads` (1 day) on the 10 versioned buckets, 2026-10-29 |
| Staging access (section 9) | group `iltiam-staging-storage`; policy `iltiam-storage-staging` (exact bucket names); user `iltiam-staging-storage` |
| Production access (section 9.6) | later, with the production backend |
| Staging key in GitHub (section 11) | `STORAGE_ACCESS_KEY`, `STORAGE_SECRET_KEY` set 2026-10-29 |
| Staging storage settings in GitHub (section 11) | `STORAGE_ENDPOINT_URL` and `MASK_UPLOAD_ALLOWED_HOSTS` (secrets), `STORAGE_REGION`, the five `STORAGE_BUCKET_*`, `AI_MASK_UPLOAD_ENABLED=True` (variables), 2026-10-29; no stale variables |
| Probe objects (section 14.3) | removed from every staging bucket, 2026-10-29 |
| Alarms (section 12) | not done yet |
| Vault keys last rotated (section 15.1) | |

## 1. How it works

```
OCI Vault "iltiam" (software keys, free)
  iltiam-staging-objects ──encrypts──▶ every iltiam-staging-* bucket
  iltiam-prod-objects    ──encrypts──▶ every iltiam-prod-* bucket

backend web and worker ──S3 API, the environment's own key──▶ its 5 backend buckets   (read, write; never delete)
AI worker  ──presigned PUT, made by the backend────────────▶ <SHORT>-wound-masks     (the AI service has no key)
phones and browsers ──presigned GET, valid ≤ 15 min───────▶ photos, masks, PDFs
backup job (Runbook 6, #8) ──its own key, later───────────▶ <SHORT>-backups
```

- **The S3-compatible API.** The backend speaks S3 (boto3, django-storages) to OCI's S3-compatible endpoint, with path-style addressing (`…/<bucket>/<object>`) and region `me-riyadh-1`.
- **Credentials:** a **Customer Secret Key** of a dedicated user: an access key and a secret key. They go into `backend.env` from the GitHub Environment (Runbook 4).
- **Files never pass through Cloudflare or the VM's disk** (ADR-0004, Decision 4). Clients get presigned links, signed by the backend, that expire within 15 minutes.
- **Encryption:** every object is encrypted at rest with its environment's Vault key. OCI does this whatever the client asks: the backend still sends `x-amz-server-side-encryption: AES256` (OCI accepts it), and OCI reports `aws:kms` back.
- **PDPL:** buckets and keys are in Riyadh (`me-riyadh-1`), the home region.
- **Network:** `backend-web` (through `edge`), `backend-worker` and `ai-worker` (through `egress`) reach the endpoint over HTTPS through the VCN's internet gateway; the traffic stays inside Oracle's Riyadh region. Nothing in `compose.yml` changes. Don't add a network condition to the storage policy: presigned links are used from phones and browsers anywhere, with the storage user's authority.

## 2. Free limits and the budget

| Limit (Always Free, free-only account) | Our budget |
|---|---|
| **20 GB** in total, all storage tiers together | production **14 GB**, staging **3 GB**, backups **3 GB**; alarm at 70 % (14 GB), section 12 |
| **50,000 API requests a month** | about 1,600 a day; alarm at that, section 12 |
| Vault: software-protected keys | 2 keys, free |

- **Standard tier only.** Don't turn on Auto-Tiering or move anything to Infrequent Access or Archive. Infrequent Access has a 31-day minimum and a fee for each GB read back, and the weekly restore test (#8) reads the dumps.
- **What costs requests:**
  - **An analysis:** about 8 to 10 (the upload and its existence check, the backend reading the photo for the AI service, the mask upload, then each time someone views it).
  - **`/api/ready/`:** 5, a `HeadBucket` per bucket. **Uptime checks and smoke tests must use `/api/health/`, never `/api/ready/`.** A check every minute on `/api/ready/` would cost about 216,000 requests a month.
  - **`manage.py check_storage`:** about 30. **The probe of section 10:** about 60. Run them when you need them, not on a timer.
- **Beyond the free tier:** storage costs about $0.0255 per GB-month (ADR-0004, cost table). The budget alert of Runbook 1 catches any charge.

## 3. Before you start

1. **Done already:** [Runbook 1](01-oci-account-and-vm.md): the account in Riyadh, compartment `iltiam`, your administrator login with 2-Step Verification. [Runbook 4](04-secrets.md): the GitHub Environments.
2. **On your laptop:**
   - **Git Bash**, in this repository's folder, on an up-to-date `main`;
   - **Docker Desktop**, running (the probe runs in a container);
   - **GitHub CLI**: `gh auth status` says "Logged in".
3. **About 2 hours**, in one sitting: OCI shows a new secret key only once (section 9.5), and the probe and GitHub steps use it straight away.

## 4. Namespace and the S3 compartment (once)

### 4.1 The namespace

**☰ → Governance & Administration → Tenancy details →** section **Object storage settings → Object storage namespace.**

It is a short string of lower-case letters and digits. It is in every storage address, so it identifies the tenancy: **never write it in this repository, an issue or a chat.** Sections 10 and 11 type it into Git Bash with hidden input.

### 4.2 Where S3-created buckets go

Same page → **Object storage settings → Edit object storage settings → Amazon S3 Compatibility API designated compartment: `iltiam` → Save.**

We create every bucket in the console, so this only keeps anything made through the S3 API out of the root compartment.

**What you should see:** the page shows `iltiam` for the S3 compatibility compartment.

## 5. Vault and keys (once)

### 5.1 The vault

1. **☰ → Identity & Security → Key Management & Secret Management → Vault.** Compartment `iltiam` (left) **→ Create Vault.**
2. Name: `iltiam`.
3. **Leave "Make it a virtual private vault" unticked.** A virtual private vault is **paid**; the default vault with software keys is free.
4. **Create Vault.** Wait for the state **Active** (a minute or two).

### 5.2 One key per environment

1. Vault `iltiam` **→ Master Encryption Keys → Create Key:**
   - Compartment: `iltiam`.
   - **Protection Mode: Software.**
   - Name: `iltiam-staging-objects`.
   - **Key Shape: Algorithm AES, Length 256 bits.**
   - **Create Key.**
2. Repeat with the name `iltiam-prod-objects`.

**What you should see:** both keys **Enabled**, Protection Mode **Software**, AES 256 bits.

**Never disable or delete these keys.** Every object they protect becomes unreadable (section 15.1).

## 6. Let Object Storage use the keys (once)

The buckets are encrypted by the Object Storage service itself, and its lifecycle rules run as that service. Both need a policy.

1. **☰ → Identity & Security → Policies.** Compartment `iltiam` **→ Create Policy.**
2. Name `iltiam-objectstorage-key-policy`, description "Object Storage uses the Vault keys and runs lifecycle rules". Compartment `iltiam`. **Show manual editor**, and paste:

   ```
   Allow service objectstorage-me-riyadh-1 to use keys in compartment iltiam
   Allow service objectstorage-me-riyadh-1 to manage object-family in compartment iltiam
   ```

3. **Create.**

- **Line 1:** lets buckets be encrypted with the Vault keys. Without it, creating a bucket with a key fails.
- **Line 2:** lets lifecycle rules delete old versions. **Without it, creating a lifecycle rule fails** (section 16).
- Line 1 covers every key in compartment `iltiam`: today only the two of section 5. If keys for anything else are ever created there, narrow it to ours with `where any {target.key.id = '<KEY_OCID>', target.key.id = '<KEY_OCID>'}` (the OCIDs stay in the console).

## 7. Buckets (once, both environments)

Twelve buckets. The names are final: the backend reads them from `STORAGE_BUCKET_*` (section 11).

| Bucket | Holds | Versioning | Key |
|---|---|---|---|
| `iltiam-staging-wound-images` | wound photos | **on** | `iltiam-staging-objects` |
| `iltiam-staging-wound-masks` | AI segmentation masks | **on** | `iltiam-staging-objects` |
| `iltiam-staging-reports` | generated PDF reports | **on** | `iltiam-staging-objects` |
| `iltiam-staging-prescriptions` | prescription PDFs | **on** | `iltiam-staging-objects` |
| `iltiam-staging-profile-photos` | patients' profile photos | **on** | `iltiam-staging-objects` |
| `iltiam-staging-backups` | encrypted database dumps (#8) | off | `iltiam-staging-objects` |
| `iltiam-prod-…` the same six | the same | the same | `iltiam-prod-objects` |

For each one: **☰ → Storage → Object Storage & Archive Storage → Buckets.** Compartment `iltiam` **→ Create Bucket:**

1. **Bucket Name:** from the table.
2. **Default Storage Tier: Standard.**
3. **Enable Auto-Tiering: off.**
4. **Enable Object Versioning:** on, except for the two `-backups` buckets.
5. **Emit Object Events: off.**
6. **Encryption: Encrypt using customer-managed keys →** Vault `iltiam`, the environment's key.
7. **Create.**

**What you should see** on each bucket's details page:
- **Visibility: Private.** Never use **Edit Visibility**.
- **Encryption Key:** the environment's key.
- **Object Versioning:** Enabled (or Disabled for `-backups`).

**Never create a pre-authenticated request** (the bucket's **Pre-Authenticated Requests** tab stays empty). It would be a link that bypasses the storage user's limits. The storage users can't create one either.

**Why versioning on the backend's buckets:** the backend never overwrites or deletes a file, so versions cost almost nothing, and they protect against a bug that would. The backend's own `check_storage` expects it. The `-backups` buckets have no versioning, so that a deleted dump is really gone.

**No exports bucket yet:** the backend has no setting for one. It comes with BE-13, with a rule that deletes exports after 7 days.

## 8. Lifecycle rules (once, the 10 versioned buckets)

On each of the 10 versioned buckets: bucket **→ Lifecycle Policy Rules** (under Resources) **→ Create Rule**, twice:

| Name | Target | Lifecycle action | Days |
|---|---|---|---|
| `delete-old-versions` | **Previous object versions** | Delete | **30** |
| `abort-unfinished-uploads` | **Uncommitted multipart uploads** | Delete | **1** |

**What you should see:** both rules listed and **Enabled** on each of the 10 buckets.

- **Why:** an overwritten or deleted object stays as a previous version until this rule removes it. That bounds the space it uses and how long deleted personal data lingers (PDPL): at most 30 days.
- **If creating a rule fails** with a permissions message: section 6, line 2 is missing.
- **The `-backups` buckets** get their rules from Runbook 6 (#8), which decides how many dumps to keep.

## 9. Storage access per environment

The staging steps below are done; production's (section 9.6) wait until production's backend is turned on (Runbook 5, section 8, "later").

### 9.1 The group

**☰ → Identity & Security → Domains → Default domain → User management → Groups → Create group.** Name `iltiam-staging-storage` → **Create.**

### 9.2 The user

**User management → Users → Create user:**
- **Last name:** the same name as the group, `iltiam-staging-storage`.
- **Email:** `<SERVICE_USER_EMAIL>`. Untick **Use the email address as the username** if shown, and set the **Username** to the same name.
- **Groups:** `iltiam-staging-storage`.
- **Create.**

Oracle emails an activation link to that address. **Ignore it:** the user never gets a password and never signs in to the console.

### 9.3 Only Customer Secret Keys

The user **→ Edit user capabilities:** tick **only Customer secret keys**, untick everything else (local password, API keys, auth tokens, SMTP credentials, OAuth 2.0 client credentials, DB credentials) **→ Save changes.**

### 9.4 The policy: exact bucket names

**☰ → Identity & Security → Policies.** Compartment `iltiam` **→ Create Policy.** Name `iltiam-storage-staging`, compartment `iltiam`, **Show manual editor**, and paste (each statement is one line):

```
Allow group 'Default'/'iltiam-staging-storage' to read buckets in compartment iltiam where any {target.bucket.name='iltiam-staging-wound-images', target.bucket.name='iltiam-staging-wound-masks', target.bucket.name='iltiam-staging-reports', target.bucket.name='iltiam-staging-prescriptions', target.bucket.name='iltiam-staging-profile-photos'}
Allow group 'Default'/'iltiam-staging-storage' to manage objects in compartment iltiam where all {any {target.bucket.name='iltiam-staging-wound-images', target.bucket.name='iltiam-staging-wound-masks', target.bucket.name='iltiam-staging-reports', target.bucket.name='iltiam-staging-prescriptions', target.bucket.name='iltiam-staging-profile-photos'}, any {request.permission='OBJECT_INSPECT', request.permission='OBJECT_READ', request.permission='OBJECT_CREATE', request.permission='OBJECT_OVERWRITE'}}
```

> **Never use a name pattern such as `target.bucket.name=/iltiam-staging-*/`.** It also matches `iltiam-staging-backups`. That happened on 2026-10-29: the backend's key could see the backups bucket until the pattern was replaced by these exact names. Write every bucket name out.

What this allows, and what it doesn't:
- **Allowed:** see the five buckets (`HeadBucket`), list, read, create and overwrite objects in them. That is all the backend does.
- **Not allowed:** delete (the backend never hard-deletes); anything in `-backups`; anything of the other environment; changing a bucket; pre-authenticated requests.
- **No key permission** is needed: the Object Storage service uses the Vault key (section 6), not the user.
- The retention jobs (BE-22) will need `OBJECT_DELETE` later. Add it then, by that issue.

### 9.5 The Customer Secret Key

1. The user **→ Customer secret keys → Generate secret key.** Name: `staging-<YYYY-MM>`, e.g. `staging-2026-10` → **Generate secret key.**
2. **The dialog shows the secret key once.** Copy it, and go straight to section 10, step 1, which takes it with hidden input. Then **Close.**
3. The **Access key** stays visible in the key list: copy it from there.

**Never paste either one anywhere else**, and never save them in a file. A user can have **two** keys at a time, which is how rotation works without downtime (`docs/secrets.md`, section 6.4).

**A new key takes a few minutes to reach every OCI server.** Until then some requests fail with `SignatureDoesNotMatch`; the probe reports those as `KEY` lines (section 10).

### 9.6 Production (later, when production's backend is turned on)

Sections 9.1 to 9.5 again, with:
- group and user `iltiam-prod-storage`;
- policy `iltiam-storage-prod`, with the five **`iltiam-prod-…`** names in both statements (copy section 9.4 and replace `staging` by `prod` everywhere);
- key name `prod-<YYYY-MM>`;
- then sections 10 and 11 with `production`.

## 10. Probe the key

[`scripts/check-storage.sh`](../../scripts/check-storage.sh) uses the key exactly as the backend will, from your laptop: boto3, the backend's library, in a pinned container. It prints `PASS`, `FAIL`, `KEY`, `SKIP` and `NOTE` lines, and **never** a key, the namespace, an endpoint or a link.

1. In **Git Bash**, in this repository's folder, with Docker Desktop running. Each `read` takes a value without showing it: paste, Enter.

   ```bash
   read -rs -p "namespace: " STORAGE_NAMESPACE; echo
   read -rs -p "access key: " STORAGE_ACCESS_KEY; echo
   read -rs -p "secret key: " STORAGE_SECRET_KEY; echo
   export STORAGE_NAMESPACE STORAGE_ACCESS_KEY STORAGE_SECRET_KEY
   bash scripts/check-storage.sh staging
   ```

2. **Keep this window open** for section 11.

**What it checks:**

| Output section | Checks |
|---|---|
| 1. endpoint | which of OCI's two domains accepts the key (`NOTE` lines), then uses `oci.customer-oci.com` if it works |
| 2. own buckets | each of the five: `HeadBucket`, `ListObjects`, `PutObject`, `GetObject` gives back what was written, an anonymous read is refused |
| 3. AES256 header test | a baseline upload without the header, then the same with `x-amz-server-side-encryption: AES256` (the backend sends it on every upload); the same pair as a 6 MiB two-part upload. Only "baseline passed, header failed" blames the header |
| 4. check_storage's bucket calls | `NOTE` lines only, for the backend (#80) |
| 5. presigned links | a download link (as a phone opens a photo), an upload link with `Content-Type` only (as the AI service uploads a mask), and the same upload link refused with another `Content-Type` |
| 6. no deletes | a delete is refused |
| 7. cross-environment refusal | the other environment's six buckets: not visible, not listable, not readable, not writable |
| 8. own backups bucket | the same refusals for the environment's own `-backups` |

**What you should see** (staging, 2026-10-29):
- `NOTE  checksum mode: request_checksum_calculation=when_required, …`
- section 1: both domains `works`, then `PASS  an endpoint accepts this key: using oci.customer-oci.com`;
- section 3: `OCI ACCEPTS the AES256 header` twice; `NOTE  HeadObject ServerSideEncryption: aws:kms`;
- section 4: `GetBucketEncryption: answers, algorithm aws:kms`, `GetBucketVersioning: answers, Status Enabled`;
- sections 7 and 8: every line `PASS … refused, … (HTTP 404)`. **OCI answers 404, not 403**, for a bucket the key has no rights on, so it doesn't even confirm the bucket exists;
- at the end: `==> 47 passed, 0 failed, 0 key not accepted, 0 skipped`, exit code 0.

**If it isn't that:**
- **`KEY` lines** (exit code 2): the new key hasn't reached every OCI server yet. Wait 10 minutes and run step 1's last line again. If they don't go away, the secret was copied wrong: generate a new key (section 9.5), delete the old one, and start again.
- **`FAIL` lines:** section 16.

**The probe leaves small objects** under `.healthcheck/` in the staging buckets (about 12 MiB in `-wound-images`). The key can't delete them; each run overwrites them, and the lifecycle rule removes the old versions. To remove them all, see section 14.3.

## 11. Put the values into GitHub

From the **same** Git Bash window, where the three values are still in the environment. Each value goes to GitHub through a pipe, so nothing is shown or saved.

| Name | Kind | Goes to | Value |
|---|---|---|---|
| `STORAGE_ACCESS_KEY`, `STORAGE_SECRET_KEY` | **secret** | backend.env | the key (section 9.5) |
| `STORAGE_ENDPOINT_URL` | **secret** | backend.env | `https://<NAMESPACE>.compat.objectstorage.me-riyadh-1.oci.customer-oci.com` |
| `MASK_UPLOAD_ALLOWED_HOSTS` | **secret** | ai.env | `<NAMESPACE>.compat.objectstorage.me-riyadh-1.oci.customer-oci.com` |
| `STORAGE_REGION` | var | backend.env | `me-riyadh-1` |
| `STORAGE_BUCKET_WOUND_IMAGES`, `…_WOUND_MASKS`, `…_REPORTS`, `…_PRESCRIPTIONS`, `…_PROFILE_PHOTOS` | var | backend.env | `iltiam-<SHORT>-wound-images` etc. (section 7) |
| `AI_MASK_UPLOAD_ENABLED` | var | backend.env | `True`: the AI service uploads the mask itself (section 10, part 5) |

**Why the endpoint and the mask host are secrets:** they are not credentials, but they contain the namespace. GitHub hides secrets in this public repository's Actions logs and doesn't hide variables. `DEPLOY_HOST` is a secret for the same reason.

Leave out `STORAGE_PUBLIC_ENDPOINT_URL` (the endpoint is already public) and `STORAGE_PRESIGNED_*` (15 minutes by default, the maximum).

```bash
ENV=staging; SHORT=staging; REPO=iltiam/iltiam-deployment
host="$STORAGE_NAMESPACE.compat.objectstorage.me-riyadh-1.oci.customer-oci.com"
printf '%s' "$STORAGE_ACCESS_KEY" | gh secret set STORAGE_ACCESS_KEY --env "$ENV" -R "$REPO"
printf '%s' "$STORAGE_SECRET_KEY" | gh secret set STORAGE_SECRET_KEY --env "$ENV" -R "$REPO"
printf '%s' "https://$host" | gh secret set STORAGE_ENDPOINT_URL --env "$ENV" -R "$REPO"
printf '%s' "$host" | gh secret set MASK_UPLOAD_ALLOWED_HOSTS --env "$ENV" -R "$REPO"
gh variable set STORAGE_REGION --env "$ENV" --body me-riyadh-1 -R "$REPO"
for pair in WOUND_IMAGES:wound-images WOUND_MASKS:wound-masks REPORTS:reports PRESCRIPTIONS:prescriptions \
    PROFILE_PHOTOS:profile-photos; do
  gh variable set "STORAGE_BUCKET_${pair%%:*}" --env "$ENV" --body "iltiam-$SHORT-${pair#*:}" -R "$REPO"
done
gh variable set AI_MASK_UPLOAD_ENABLED --env "$ENV" --body True -R "$REPO"
unset host STORAGE_NAMESPACE STORAGE_ACCESS_KEY STORAGE_SECRET_KEY
clear
```

For production: `ENV=production; SHORT=prod`.

**What you should see:** a `✓ Set Actions secret …` line for each of the four secrets and a `✓ Created variable …` (or `Updated`) line for each of the seven variables. No value is printed.

**Check:**
- Run [Runbook 4](04-secrets.md), section 10.2 for the environment: both `comm` commands print nothing.
- `gh variable list --env staging -R iltiam/iltiam-deployment` must **not** list `STORAGE_ENDPOINT_URL` or `MASK_UPLOAD_ALLOWED_HOSTS`. They are secrets now. If an older variable of that name is there, delete it: `gh variable delete STORAGE_ENDPOINT_URL --env staging -R iltiam/iltiam-deployment`.

## 12. Alarms (once, the last console step)

### 12.1 Where alarms go

1. **☰ → Developer Services → Application Integration → Notifications.** Compartment `iltiam` **→ Create Topic.** Name `iltiam-alerts` → **Create.**
2. The topic **→ Create Subscription:** Protocol **Email**, `<YOUR_EMAIL>` → **Create.** Again for `<TEAMMATE_EMAIL>`.
3. Each address gets a confirmation email: open its link. The subscription turns **Active**.

Always Free includes 1,000 notification emails a month. Runbook 7 (#10) sends its own alerts to the same topic.

### 12.2 Two alarms

**☰ → Observability & Management → Monitoring → Alarm Definitions.** Compartment `iltiam` **→ Create Alarm**, twice. In the **Metric description** part, choose compartment `iltiam` and namespace `oci_objectstorage`, then **Switch to Advanced Mode** and paste the query:

| Alarm name | Query | Trigger | Severity |
|---|---|---|---|
| `iltiam-object-storage-70pct` | `StoredBytes[1h].grouping().sum() > 15032385536` | 14 GiB, 70 % of the free 20 GB, all buckets together | Warning |
| `iltiam-object-storage-requests` | `AllRequests[1d].grouping().sum() > 1600` | 1,600 requests a day: the free 50,000 a month spread over 31 days | Warning |

For both: **Destination: Notifications, topic `iltiam-alerts`**; **Repeat notification**: every 24 hours. Then **Save alarm.**

- **Before saving the first one:** the preview chart's latest value must be about the sum of the buckets' **Approximate Size** (each bucket's details page), in bytes. `StoredBytes` is reported once an hour per bucket; **a bucket with no objects reports nothing**, so the chart may be empty until something is uploaded.
- **If the console refuses `[1d]`** for the second alarm: use `AllRequests[1h].grouping().sum() > 70`.

**What you should see:** both alarms in **Alarm Definitions**, state **OK**.

Runbook 7 (#10) adds the Grafana panel "object storage used vs 20 GB" next to these.

## 13. After the first staging deploy

**The staging backend must include iltiam-backend#80's checksum fix.** boto3 1.36 and later add a checksum to every upload, which OCI refuses with `501 NotImplemented`. The probe (section 10) sets `when_required`; the backend needs the same before any upload works.

On the VM, as `deploy` ([Runbook 5](05-compose-stack.md), section 4.4 for the `iltiam` shortcut):

1. **Readiness** from your laptop: [Runbook 5](05-compose-stack.md), section 7.3. `/api/ready/` shows `storage` `ok`.
2. **From inside the backend worker, with its own key:** its own bucket answers, production's doesn't. Nothing secret is printed:

   ```bash
   iltiam staging exec backend-worker python -c "
   import os, boto3
   from botocore.config import Config
   from botocore.exceptions import ClientError
   s3 = boto3.client('s3', endpoint_url=os.environ['STORAGE_ENDPOINT_URL'], region_name=os.environ['STORAGE_REGION'],
       aws_access_key_id=os.environ['STORAGE_ACCESS_KEY'], aws_secret_access_key=os.environ['STORAGE_SECRET_KEY'],
       config=Config(signature_version='s3v4', s3={'addressing_style': 'path'}))
   for b in (os.environ['STORAGE_BUCKET_WOUND_IMAGES'], 'iltiam-prod-wound-images'):
       try:
           s3.head_bucket(Bucket=b); print(b, 'reachable')
       except ClientError as e:
           print(b, 'refused, HTTP', e.response['ResponseMetadata']['HTTPStatusCode'])
   "
   ```

   **What you should see:** `iltiam-staging-wound-images reachable`, then `iltiam-prod-wound-images refused, HTTP 404`. This also proves the network path from the VM.
3. **`check_storage`** (acceptance criterion; after iltiam-backend#80 teaches it that OCI reports `aws:kms` and answers anonymous reads with 404):

   ```bash
   iltiam staging exec backend-web python manage.py check_storage
   ```

   **What you should see:** a `✓` on every line, then `All storage checks passed.`
4. **One analysis** (Runbook 5, section 11.4, or the staging app): the photo appears in `iltiam-staging-wound-images` and its mask in `iltiam-staging-wound-masks`, under the assessment's id.
5. **Customer-managed key on the objects** (acceptance criterion): console → bucket `iltiam-staging-wound-images` → the photo's **⋮ → View Object Details.** The encryption key is `iltiam-staging-objects`.

## 14. Day to day

### 14.1 Space and requests

- **Space:** each bucket's details page shows **Approximate Size** and **Approximate Count**. The 70 % alarm watches the total.
- **Staging over its 3 GB:** delete old test data in the console (your administrator login can delete; the backend's key can't). **Never in a `iltiam-prod-…` bucket.**
- **Requests:** the request alarm. If it fires, look for something polling `/api/ready/` (section 2).
- **Monthly:** **☰ → Billing & Cost Management → Cost Analysis:** $0.00.

### 14.2 What never to do

- Make a bucket public, or create a pre-authenticated request.
- Turn on Auto-Tiering, or move objects to Infrequent Access or Archive.
- Disable or delete a Vault key (section 15.1).
- Give a storage policy a name pattern (section 9.4).

### 14.3 Remove the probe's objects

The probe writes only under `.healthcheck/`. Remove those objects, every version, with **Cloud Shell**: console top bar **→ Developer tools → Cloud Shell**. It is already signed in as you, and needs no key or namespace.

1. **List** them:

   ```bash
   for b in iltiam-staging-wound-images iltiam-staging-wound-masks iltiam-staging-reports \
            iltiam-staging-prescriptions iltiam-staging-profile-photos iltiam-staging-backups; do
     echo "== $b"
     oci os object list-object-versions --bucket-name "$b" --prefix .healthcheck/ --all \
       | jq -r '(.data.items? // .data // [])[] | "\(.name)\t\(."version-id")"'
   done
   ```

   **What you should see:** each bucket's name, then one line per stored version (`.healthcheck/…` and a version id), or nothing for a bucket without probe objects.
2. **Delete** them, every version, for good:

   ```bash
   for b in iltiam-staging-wound-images iltiam-staging-wound-masks iltiam-staging-reports \
            iltiam-staging-prescriptions iltiam-staging-profile-photos iltiam-staging-backups; do
     oci os object list-object-versions --bucket-name "$b" --prefix .healthcheck/ --all \
       | jq -r '(.data.items? // .data // [])[] | "\(.name)\t\(."version-id")"' \
       | while IFS=$'\t' read -r name version; do
           oci os object delete --bucket-name "$b" --object-name "$name" --version-id "$version" --force \
             && echo "deleted $b/$name"
         done
   done
   ```

3. Run step 1 again: no lines under any bucket.

The `--prefix .healthcheck/` keeps these commands away from real files. For production, use the `iltiam-prod-…` names.

## 15. Rotation

### 15.1 The Vault keys: yearly (NFR-SEC-04)

1. **☰ → Identity & Security → Key Management & Secret Management → Vault → `iltiam` → Master Encryption Keys** → the key **→ Rotate Key → Rotate Key.**
2. **What you should see:** the key's **Versions** list has a new version, marked current. New objects use it; objects stored earlier still decrypt with their older version.
3. Nothing changes for the backend, the AI service or the links.
4. Do it for both keys. Write the date in the As built table, and put a calendar reminder for the same day next year.

**Never** choose **Disable** or **Schedule Deletion** on these keys. If a deletion was scheduled by mistake: the key **→ Cancel Deletion** (deletion waits 7 to 30 days).

### 15.2 The storage keys: yearly and on staff change

[`docs/secrets.md`](../secrets.md), section 6.4. Rotate staging first, and run the probe (section 10) with the new key before you redeploy.

## 16. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Probe: `PutObject: NotImplemented (HTTP 501)` | boto3 1.36 and later add a CRC32 checksum to uploads, which OCI's S3 API refuses. The probe sets `when_required`; an older copy of the script doesn't. In the backend: iltiam-backend#80 |
| Probe: `KEY` lines, or `SignatureDoesNotMatch` on some calls and not others | A new key is still reaching OCI's servers: wait 10 minutes and run again. If it stays: the secret was copied wrong. New key (section 9.5), delete the old one |
| Probe sections 7 or 8: `HeadBucket … ALLOWED` on `-backups` or another environment's bucket | The storage policy uses a name pattern such as `/iltiam-staging-*/`, which matches `-backups` too. **Never use name patterns**: replace them by the exact names of section 9.4. Also check that no other policy grants the group (or any user) `inspect`, `read` or `manage` on buckets or `object-family`, and that the storage user is in no other group |
| Creating a lifecycle rule fails (permissions) | Section 6, line 2 (`manage object-family`) is missing |
| Creating a bucket with a customer-managed key fails, "not authorized to use the key" | Section 6, line 1 (`use keys`) is missing |
| Section 1 of the probe: a domain `does not work` | Use the one that works. Both worked on 2026-10-29; the templates use `oci.customer-oci.com` |
| Refusals answer 404, not 403 | Normal: OCI doesn't confirm that a bucket exists to a key without rights on it |
| `/api/ready/` shows `storage` failing | A wrong key, endpoint or bucket name in the Environment (section 11), or a key that was deleted. Run the probe with the same values |
| Uploads fail in the app, `501` in the backend log | The backend image lacks iltiam-backend#80's checksum fix |
| `check_storage`: `default encryption is AES-256 — aws:kms`, or `anonymous read refused — HTTP 404` | Expected until iltiam-backend#80: OCI reports `aws:kms` and answers 404. Not a storage problem |
| Photos don't show in the web app; the browser console names a content security policy or CORS | The web app's policy (WEB-33) must allow images from the storage host. OCI's S3 API has no CORS settings: the web app must load files with `<img>`, not `fetch()` |
| The 70 % alarm fires | Section 14.1: staging's test data first. If production is near 14 GB, ADR-0004's paid step (about $0.0255 per GB-month) |
| The request alarm fires | Something calls `/api/ready/` or `check_storage` on a timer (section 2) |
| The budget alert (Runbook 1) fires after this runbook | A paid option was chosen: a **virtual private vault** (section 5.1), or a tier other than Standard. Check the Vault type and every bucket's tier |

## 17. Verification checklist

The **When** column says when a row can pass:
- **this PR:** in CI, before the merge;
- **console:** the OCI console or the probe from a laptop;
- **after the first deploy:** staging runs the backend (Runbook 5);
- **after #80:** the backend's fixes are in the deployed image;
- **later:** production's backend is on (Runbook 5, section 8).

The **Verified** column records the date each row last passed.

| # | Check | How | Expected | When | Verified |
|---|---|---|---|---|---|
| 1 | CI | the pull request's checks | `env-check` green: shellcheck (including `check-storage.sh`), `check-env.sh`, gitleaks | this PR | |
| 2 | S3 compartment | section 4.2 | `iltiam` | console | 2026-10-29 |
| 3 | Vault and keys | section 5 | vault `iltiam` (not virtual private); two keys Enabled, Software, AES 256 | console | 2026-10-29 |
| 4 | Service policy | section 6 | both lines in `iltiam-objectstorage-key-policy` | console | 2026-10-29 |
| 5 | Buckets | section 7 | 12; Private; the environment's key; versioning as in the table; no pre-authenticated requests | console | 2026-10-29 |
| 6 | Lifecycle rules | section 8 | both rules Enabled on the 10 versioned buckets | console | 2026-10-29 |
| 7 | Staging user | sections 9.2, 9.3 | in `iltiam-staging-storage` only; capabilities: Customer secret keys only | console | 2026-10-29 |
| 8 | Staging policy | section 9.4 | exact names, no pattern | console | 2026-10-29 |
| 9 | Probe, staging | section 10 | `47 passed, 0 failed, 0 key not accepted, 0 skipped` | console | 2026-10-29 |
| 10 | AES256 header | section 10, part 3 | `OCI ACCEPTS the AES256 header`, twice | console | 2026-10-29 |
| 11 | Cross-environment and backups refusal | section 10, parts 7 and 8 | every line `refused` | console | 2026-10-29 |
| 12 | Staging values in GitHub | section 11; Runbook 4, section 10.2 | four secrets, seven variables; the `comm` commands print nothing | console | 2026-10-29 |
| 13 | Alarms | section 12 | 2 alarms OK; topic with 2 confirmed emails | console | |
| 14 | `/api/ready/` storage | section 13, step 1 | `storage` `ok` | after the first deploy | |
| 15 | From inside the worker | section 13, step 2 | own bucket reachable; production's refused | after the first deploy | |
| 16 | `check_storage` on staging (AC 1) | section 13, step 3 | `All storage checks passed.` | after #80 | |
| 17 | Customer-managed key on objects (AC 2) | section 13, step 5 | `iltiam-staging-objects` | after the first deploy (first seen on a probe object) | 2026-10-29 (probe object) |
| 18 | Production access and probe | section 9.6, section 10 with `production` | as rows 7 to 11 | later | |
| 19 | `check_storage` on production (AC 1) | section 13 with `production` | `All storage checks passed.` | later | |
| 20 | No charges (AC 2) | **Billing & Cost Management → Cost Analysis**, a week after section 12 | $0.00 | console | |
| 21 | Key rotation reminder | section 15.1 | a calendar entry a year ahead | console | |

**Record the results as a comment on issue #13:** pass or fail per row, with the date. **Never include** the namespace, an OCID, a key, an endpoint or a link. The probe's output may be pasted as it is.

## 18. Security notes

- **Private buckets, short links:** no bucket is public, no pre-authenticated request exists, and clients only get presigned links valid for at most 15 minutes. The backend refuses a longer lifetime at start-up.
- **Least privilege, per environment:** each storage user's policy names its five buckets exactly. The key can't delete, can't touch `-backups`, can't see the other environment, and can't change a bucket. Sections 7 and 8 of the probe prove it.
- **The AI service has no storage credential:** it uploads masks only to a link the backend signed for one object, one content type, for 10 minutes.
- **Encryption at rest:** AES-256 with a Vault key per environment, rotated yearly (NFR-SEC-04). Software-protected keys are free; the key material stays inside OCI Vault.
- **Secrets:** the Customer Secret Keys live only in the GitHub Environments and in `backend.env` on the VM (`docs/secrets.md`). The namespace is treated like an address: in GitHub secrets, never in the repository.
- **Old versions:** kept 30 days, then removed by the lifecycle rule. So a file deleted for PDPL reasons is gone from storage within 30 days.
- **PDPL:** every bucket and key is in the Riyadh region.

## 19. What comes next

- **iltiam-backend#80 (BE-21):** the boto3 checksum setting (it blocks every upload), and `check_storage` accepting `aws:kms` and 404. Then the first staging deploy ([Runbook 5](05-compose-stack.md), section 6) and section 13 here.
- **Runbook 6 (#8):** a backup user per environment that can only write to its `-backups` bucket, the lifecycle rules for the dumps, and the weekly restore test.
- **Runbook 7 (#10):** the Grafana panel for space and requests, and alerts to the same topic.
- **Production** (section 9.6), when Runbook 5 turns production's backend on.
- **BE-13:** an exports bucket per environment, with a rule that deletes exports after 7 days.
- **BE-22:** retention jobs; the storage policy then gets `OBJECT_DELETE`.
