#!/usr/bin/env bash
# Security scans for all five ILTIAM repositories, run on a laptop (issue #18, docs/security/scanning.md).
# GitHub Actions is off for the organisation, so this replaces the planned workflow jobs.
#
#   scripts/security-scan.sh [all | secrets | deps | images | dast]... [--platform linux/arm64]
#
#   secrets   gitleaks over the full git history of every repository (redacted), with each one's .gitleaksignore
#   deps      pip-audit on the exact Python packages inside the backend and AI images; npm audit of the web app's
#             runtime dependencies; osv-scanner on the mobile app's pubspec.lock; `flutter pub outdated` (report only)
#   images    Trivy on the backend, web, AI api and AI worker images the local stack runs (.dev/images.env), or
#             staging's tags; --platform linux/arm64 scans the arm64 variants (pulled from GHCR, needs docker login)
#   dast      OWASP ZAP baseline (passive) against the LOCAL stack only: the web app and the API with its OpenAPI.
#             It joins the iltiam-dev Compose network; there is no option to point it anywhere else, on purpose.
#
# Gates (exit 1 when any is broken): a secret found; a CRITICAL image vulnerability that has a fix; a Python, npm
# (high or critical) or pub vulnerability; a High ZAP alert. Accepted findings go in security/accepted.txt with a
# reason (docs/security/scanning.md, section 4). Reports: security-reports/<date>/ (gitignored: they name versions
# and weaknesses, and this repository is public).
#
# Tools run from pinned Docker images, so only Docker is needed (plus npm and flutter when installed; npm audit
# falls back to a Node image). Sibling clones are found in SCAN_SRC_ROOT (default ..).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

TRIVY_IMAGE="aquasec/trivy:0.67.2"
GITLEAKS_IMAGE="ghcr.io/gitleaks/gitleaks:v8.30.1"
ZAP_IMAGE="ghcr.io/zaproxy/zaproxy:2.16.1"
OSV_IMAGE="ghcr.io/google/osv-scanner:v2.2.4"
PYTHON_IMAGE="python:3.13-slim"
NODE_IMAGE="node:22-alpine"
PIP_AUDIT_SPEC="pip-audit==2.10.0"

SRC_ROOT="${SCAN_SRC_ROOT:-..}"
REPOS="iltiam-deployment iltiam-backend iltiam-web iltiam-ai-service iltiam-mobile"
OUT="security-reports/$(date +%Y-%m-%d)"
ACCEPTED="security/accepted.txt"                # vulnerability IDs (Trivy, pip-audit)
GITLEAKS_ACCEPTED="security/gitleaks-accepted.txt"  # gitleaks fingerprints
DEV_NETWORK="iltiam-dev_default"
PLATFORM=""

RESULTS=()
note() { printf '\n== %s\n' "$*"; }
record() { RESULTS+=("$1|$2|$3"); }   # record <scan> <PASS|FAIL|SKIPPED> <note>

# Paths as Docker Desktop on Windows wants them; unchanged elsewhere.
host_path() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$(cd "$1" && pwd)"; else (cd "$1" && pwd); fi; }
drun() { MSYS_NO_PATHCONV=1 docker run --rm "$@"; }

# IDs from security/accepted.txt ("ID  reason", # comments), one per line.
accepted_ids() { [ -f "$ACCEPTED" ] && sed -e 's/#.*//' "$ACCEPTED" | awk 'NF { print $1 }'; }

# --- secrets -------------------------------------------------------------------------------------------------------
scan_secrets() {
  note "secrets: gitleaks (full history, redacted)"
  local repo failed=0 found=""
  for repo in $REPOS; do
    if [ ! -d "$SRC_ROOT/$repo/.git" ] && [ "$repo" != iltiam-deployment ]; then
      echo "  $repo: no clone in $SRC_ROOT, skipped"; continue
    fi
    local dir="$SRC_ROOT/$repo"; [ "$repo" = iltiam-deployment ] && dir="."
    # The repository's own .gitleaksignore plus the findings reviewed here (security/gitleaks-accepted.txt).
    { cat "$dir/.gitleaksignore" 2>/dev/null
      sed -e 's/#.*//' "$GITLEAKS_ACCEPTED" 2>/dev/null | awk -v r="$repo" '$1 == r { print $2 }'; } >"$OUT/gitleaksignore-$repo"
    if drun -v "$(host_path "$dir"):/repo" -v "$(host_path "$OUT"):/out" -w /repo "$GITLEAKS_IMAGE" git /repo \
        --gitleaks-ignore-path "/out/gitleaksignore-$repo" \
        --redact --no-banner --no-color --report-format json --report-path "/out/gitleaks-$repo.json" \
        >"$OUT/gitleaks-$repo.log" 2>&1; then
      echo "  $repo: no leaks"
    else
      failed=1; found="$found $repo"
      echo "  $repo: LEAKS FOUND ($(jq length "$OUT/gitleaks-$repo.json" 2>/dev/null || echo '?')), see $OUT/gitleaks-$repo.json (redacted)"
    fi
  done
  if [ $failed = 0 ]; then record secrets PASS "no leaks in $(echo "$REPOS" | wc -w) repositories"
  else record secrets FAIL "leaks in:$found"; fi
}

# --- images --------------------------------------------------------------------------------------------------------
image_list() {
  local file=".dev/images.env"
  [ -f "$file" ] || file="env/staging.versions"
  sed -n 's/^\(BACKEND_IMAGE\|WEB_IMAGE\|AI_API_IMAGE\|AI_WORKER_IMAGE\)=//p' "$file" | tr -d '\r'
}

scan_images() {
  note "images: Trivy${PLATFORM:+ ($PLATFORM)} (fail on CRITICAL with a fix)"
  local image name crit high failed=0 scanned=0 ignore_args=()
  accepted_ids >"$OUT/trivyignore"
  [ -s "$OUT/trivyignore" ] && ignore_args=(--ignorefile /out/trivyignore)
  for image in $(image_list); do
    if [ -z "$PLATFORM" ] && ! docker image inspect "$image" >/dev/null 2>&1; then
      echo "  $image: not on this machine (scripts/dev.sh up pulls or builds it), skipped"; continue
    fi
    name="$(printf '%s' "$image" | tr '/:' '__')${PLATFORM:+_${PLATFORM//\//-}}"
    # Without --platform Trivy reads the local image through the Docker socket; with it, the registry's variant.
    local src=()
    [ -n "$PLATFORM" ] && src=(--platform "$PLATFORM" --image-src remote)
    # The Docker socket lets Trivy read local images; its vulnerability database is cached in a volume.
    if ! drun -v /var/run/docker.sock:/var/run/docker.sock -v iltiam-trivy-cache:/root/.cache/ \
        -v "$(host_path "$OUT"):/out" "$TRIVY_IMAGE" image --quiet --scanners vuln --format json \
        --output "/out/trivy-$name.json" "${ignore_args[@]}" "${src[@]}" "$image" >"$OUT/trivy-$name.log" 2>&1; then
      echo "  $image: Trivy failed, see $OUT/trivy-$name.log"; failed=1; continue
    fi
    scanned=$((scanned + 1))
    crit=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL" and (.FixedVersion // "") != "")] | length' "$OUT/trivy-$name.json")
    high=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH")] | length' "$OUT/trivy-$name.json")
    echo "  $image: $crit critical with a fix, $high high"
    [ "$crit" = 0 ] || failed=1
  done
  if [ $scanned = 0 ]; then record "images${PLATFORM:+ $PLATFORM}" SKIPPED "no image found"
  elif [ $failed = 0 ]; then record "images${PLATFORM:+ $PLATFORM}" PASS "$scanned images, no fixable CRITICAL"
  else record "images${PLATFORM:+ $PLATFORM}" FAIL "fixable CRITICAL or scan error, see $OUT/trivy-*.json"; fi
}

# --- deps ----------------------------------------------------------------------------------------------------------
pip_audit_image() {  # pip_audit_image <label> <image>
  local label="$1" image="$2" ignore="" id
  if [ -z "$image" ] || ! docker image inspect "$image" >/dev/null 2>&1; then
    echo "  $label: image ${image:-unknown} not on this machine, skipped"; return 2
  fi
  # `pip list --format=freeze` gives name==version even for packages installed from local wheels; local version
  # labels (torch's +cpu) are dropped so the advisory database matches them.
  drun --entrypoint python "$image" -m pip list --format=freeze 2>/dev/null \
    | grep -E '^[A-Za-z0-9_.-]+==' | sed -E 's/\+[A-Za-z0-9.]+$//' >"$OUT/pip-freeze-$label.txt"
  for id in $(accepted_ids); do ignore="$ignore --ignore-vuln $id"; done
  if drun -v "$(host_path "$OUT"):/out" "$PYTHON_IMAGE" sh -c \
      "pip install -q --disable-pip-version-check '$PIP_AUDIT_SPEC' >/dev/null 2>&1 &&
       pip-audit --no-deps --disable-pip --progress-spinner off -f json -o /out/pip-audit-$label.json \
         -r /out/pip-freeze-$label.txt$ignore" >"$OUT/pip-audit-$label.log" 2>&1; then
    echo "  $label (pip-audit, $(wc -l <"$OUT/pip-freeze-$label.txt") packages in $image): no known vulnerability"; return 0
  fi
  local n
  n=$(jq '[.dependencies[]?.vulns[]?] | length' "$OUT/pip-audit-$label.json" 2>/dev/null || echo "?")
  echo "  $label (pip-audit): $n known vulnerabilities, see $OUT/pip-audit-$label.json"
  return 1
}

scan_deps() {
  note "deps: pip-audit (images), npm audit (web), osv-scanner (mobile), flutter pub outdated (report)"
  local failed=0 parts=() images backend ai_api rc
  images="$(image_list)"
  backend="$(grep -m1 backend <<<"$images" || true)"
  ai_api="$(grep -m1 ai-api <<<"$images" || true)"

  pip_audit_image backend "$backend"; rc=$?; [ $rc = 1 ] && failed=1; [ $rc = 0 ] && parts+=(backend)
  pip_audit_image ai "$ai_api"; rc=$?; [ $rc = 1 ] && failed=1; [ $rc = 0 ] && parts+=(ai)

  local web="$SRC_ROOT/iltiam-web/web"
  if [ -f "$web/package-lock.json" ]; then
    # Runtime dependencies gate (the nginx image ships only the built bundle, but they are in it); dev dependencies
    # are reported in the JSON for the owners.
    if command -v npm >/dev/null 2>&1; then
      (cd "$web" && npm audit --omit=dev --json >"$OLDPWD/$OUT/npm-audit-web.json" 2>/dev/null)
      (cd "$web" && npm audit --json >"$OLDPWD/$OUT/npm-audit-web-all.json" 2>/dev/null)
    else
      drun -v "$(host_path "$web"):/app" -w /app "$NODE_IMAGE" npm audit --omit=dev --json >"$OUT/npm-audit-web.json" 2>/dev/null
      drun -v "$(host_path "$web"):/app" -w /app "$NODE_IMAGE" npm audit --json >"$OUT/npm-audit-web-all.json" 2>/dev/null
    fi
    local hi all
    hi=$(jq '(.metadata.vulnerabilities.high // 0) + (.metadata.vulnerabilities.critical // 0)' "$OUT/npm-audit-web.json" 2>/dev/null || echo "?")
    all=$(jq '.metadata.vulnerabilities.total // 0' "$OUT/npm-audit-web-all.json" 2>/dev/null || echo "?")
    echo "  web (npm audit): $hi high or critical in runtime dependencies; $all of any level including dev tools"
    if [ "$hi" = 0 ]; then parts+=(web); else failed=1; fi
  else
    echo "  web: no $web/package-lock.json, skipped"
  fi

  local mobile="$SRC_ROOT/iltiam-mobile"
  if [ -f "$mobile/pubspec.lock" ]; then
    if drun -v "$(host_path "$mobile"):/src:ro" "$OSV_IMAGE" scan source --lockfile /src/pubspec.lock --format json \
        >"$OUT/osv-mobile.json" 2>"$OUT/osv-mobile.log"; then
      echo "  mobile (osv-scanner, pubspec.lock): no known vulnerability"; parts+=(mobile)
    else
      local n
      n=$(jq '[.results[]?.packages[]?.vulnerabilities[]?] | length' "$OUT/osv-mobile.json" 2>/dev/null || echo "?")
      echo "  mobile (osv-scanner): $n known vulnerabilities (or a scan error), see $OUT/osv-mobile.json"; failed=1
    fi
    if command -v flutter >/dev/null 2>&1; then
      (cd "$mobile" && flutter pub outdated --no-dev-dependencies >"$OLDPWD/$OUT/flutter-outdated.txt" 2>&1) \
        && echo "  mobile (flutter pub outdated): report in $OUT/flutter-outdated.txt"
    else
      echo "  mobile: flutter not installed, no outdated report"
    fi
  else
    echo "  mobile: no $mobile/pubspec.lock, skipped"
  fi

  if [ $failed = 0 ]; then record deps PASS "audited: ${parts[*]:-nothing}"
  else record deps FAIL "known vulnerabilities, see $OUT"; fi
}

# --- dast ----------------------------------------------------------------------------------------------------------
zap() {  # zap <name> <script and arguments...>; writes $OUT/zap-<name>.{html,json}
  local name="$1"; shift
  drun --network "$DEV_NETWORK" -v "$(host_path "$OUT"):/zap/wrk:rw" -u 0 "$ZAP_IMAGE" "$@" \
    -r "zap-$name.html" -J "zap-$name.json" -I >"$OUT/zap-$name.log" 2>&1
}

zap_count() {  # zap_count <name> <riskcode 3=High 2=Medium>
  jq --arg r "$2" '[.site[]?.alerts[]? | select(.riskcode == $r)] | length' "$OUT/zap-$1.json" 2>/dev/null || echo "?"
}

scan_dast() {
  note "dast: OWASP ZAP baseline against the local stack (iltiam-dev) only"
  if ! docker network inspect "$DEV_NETWORK" >/dev/null 2>&1 \
      || ! docker compose -p iltiam-dev ps --status running --services 2>/dev/null | grep -qx backend-web; then
    echo "  the local stack is not running: scripts/dev.sh up (docs/dev-environment.md)"
    record dast SKIPPED "local stack not running"; return
  fi
  # The web app (spider + passive rules), then the API from its own OpenAPI document in safe mode (-S: passive
  # only, no attack requests). Host names are the Compose services, which the backend's ALLOWED_HOSTS lists.
  zap web zap-baseline.py -t http://web:8080 -m 2
  zap api zap-api-scan.py -t http://backend-web:8000/api/schema/ -f openapi -S
  local name high med failed=0
  for name in web api; do
    if [ ! -s "$OUT/zap-$name.json" ]; then echo "  $name: ZAP produced no report, see $OUT/zap-$name.log"; failed=1; continue; fi
    high=$(zap_count "$name" 3); med=$(zap_count "$name" 2)
    echo "  $name: $high High, $med Medium alerts (report $OUT/zap-$name.html)"
    [ "$high" = 0 ] || failed=1
  done
  if [ $failed = 0 ]; then record dast PASS "no High alert (web, API)"; else record dast FAIL "High alerts or no report, see $OUT/zap-*.html"; fi
}

# --- main ----------------------------------------------------------------------------------------------------------
main() {
  local scans=() arg
  while [ $# -gt 0 ]; do
    case "$1" in
      --platform) [ $# -ge 2 ] || { echo "--platform needs a value" >&2; exit 2; }; PLATFORM="$2"; shift 2 ;;
      all) scans+=(secrets deps images dast); shift ;;
      secrets | deps | images | dast) scans+=("$1"); shift ;;
      -h | --help | help) awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0"; exit 0 ;;
      *) echo "unknown argument $1 (scripts/security-scan.sh help)" >&2; exit 2 ;;
    esac
  done
  [ ${#scans[@]} -gt 0 ] || scans=(secrets deps images dast)
  command -v jq >/dev/null 2>&1 || { echo "jq is not installed" >&2; exit 2; }
  docker info >/dev/null 2>&1 || { echo "the Docker daemon is not running" >&2; exit 2; }
  mkdir -p "$OUT"
  for arg in "${scans[@]}"; do
    case "$arg" in
      secrets) scan_secrets ;;
      deps) scan_deps ;;
      images) scan_images ;;
      dast) scan_dast ;;
    esac
  done

  printf '\n## Security scan %s\n\n| Scan | Result | Note |\n|---|---|---|\n' "$(date +%Y-%m-%d)"
  local r failed=0
  for r in "${RESULTS[@]}"; do
    IFS='|' read -r s res n <<<"$r"
    printf '| %s | %s | %s |\n' "$s" "$res" "$n"
    [ "$res" = FAIL ] && failed=1
  done
  printf '\nReports: %s (gitignored; never paste them in a public issue)\n' "$OUT"
  exit $failed
}

main "$@"
