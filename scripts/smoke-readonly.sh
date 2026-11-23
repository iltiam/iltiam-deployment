#!/usr/bin/env bash
# Read-only smoke after a release or rollback (issue #19, docs/runbooks/10-production-release.md, section 4).
# A dozen GET requests: it signs nobody in, writes nothing, and is safe against production.
#
#   scripts/smoke-readonly.sh production          https://api.iltiamcare.com and https://app.iltiamcare.com
#   scripts/smoke-readonly.sh staging             https://staging-api... and https://staging-app...
#   scripts/smoke-readonly.sh local               the local stack (scripts/dev.sh up): http://localhost:8000 and :8080
#   scripts/smoke-readonly.sh <api origin> <app origin>
#
# Checks: /api/health/ 200 "ok"; /api/ready/ 200 "ready" (database, Redis, storage, AI service); the web app 200 with
# a Content-Security-Policy; /config.js points at this API; HSTS on both (https only); /api/docs/ is 404 in
# production (never served there); /admin/ is not open (Cloudflare Access or a sign-in page, never 200 on the API's
# own admin index). Prints status codes and names only, never a body. Exit 1 if any check fails.
set -uo pipefail

case "${1:-}" in
  production) API=https://api.iltiamcare.com; APP=https://app.iltiamcare.com; ENVIRONMENT=production ;;
  staging) API=https://staging-api.iltiamcare.com; APP=https://staging-app.iltiamcare.com; ENVIRONMENT=staging ;;
  local) API=http://localhost:8000; APP=http://localhost:8080; ENVIRONMENT=local ;;
  http*://*) API="${1%/}"; APP="${2:?give the app origin too}"; APP="${APP%/}"; ENVIRONMENT=custom ;;
  *) awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0"; exit 2 ;;
esac
command -v curl >/dev/null 2>&1 || { echo "curl is not installed" >&2; exit 2; }

fails=0
pass() { printf '  PASS  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
code() { curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$@"; }
header() { curl -s -D - -o /dev/null --max-time 15 "$1" | tr -d '\r' | grep -i "^$2:" | head -n 1; }

echo "Read-only smoke: $ENVIRONMENT ($API, $APP)"

body="$(curl -s --max-time 15 "$API/api/health/" || true)"
c="$(code "$API/api/health/")"
if [ "$c" = 200 ] && grep -q '"ok"' <<<"$body"; then pass "API health 200 ok"; else fail "API health (got $c)"; fi

body="$(curl -s --max-time 15 "$API/api/ready/" || true)"
c="$(code "$API/api/ready/")"
if [ "$c" = 200 ] && grep -q '"ready"' <<<"$body"; then pass "API ready 200 (database, Redis, storage, AI)"; else fail "API ready (got $c)"; fi

c="$(code "$APP/")"
if [ "$c" = 200 ]; then pass "web app 200"; else fail "web app (got $c)"; fi
if [ -n "$(header "$APP/" content-security-policy)" ]; then pass "web app sends a Content-Security-Policy"; else fail "web app without a Content-Security-Policy"; fi

body="$(curl -s --max-time 15 "$APP/config.js" || true)"
if grep -q "\"$API\"" <<<"$body"; then pass "web /config.js points at $API"; else fail "web /config.js does not point at $API"; fi

if [[ "$API" == https://* ]]; then
  if [ -n "$(header "$API/api/health/" strict-transport-security)" ]; then pass "API sends HSTS"; else fail "API without HSTS"; fi
  if [ -n "$(header "$APP/" strict-transport-security)" ]; then pass "web app sends HSTS"; else fail "web app without HSTS"; fi
fi

if [ "$ENVIRONMENT" = production ]; then
  c="$(code "$API/api/docs/")"
  if [ "$c" = 404 ]; then pass "API docs not served in production (404)"; else fail "API docs in production (got $c, want 404)"; fi
fi

if [ "$ENVIRONMENT" = production ] || [ "$ENVIRONMENT" = staging ]; then
  c="$(code "$API/admin/")"
  if [ "$c" != 200 ]; then pass "Django admin not open ($c)"; else fail "Django admin answers 200 without Cloudflare Access"; fi
fi

if [ "$fails" = 0 ]; then echo "Smoke: all checks passed."; else echo "Smoke: $fails check(s) failed."; exit 1; fi
