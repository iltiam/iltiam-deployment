#!/usr/bin/env bash
# After an automatic staging deploy (Runbook 9, docs/runbooks/09-cd-staging.md, issue #16): does one service run the
# build env/<env>.versions names, healthy and without restarting, and do its probes answer?
#
# Usage, on iltiam-1 as deploy, from the clone at the commit just deployed:
#   scripts/health-check.sh staging <ai|backend|web>
# scripts/remote-deploy.sh runs it after scripts/deploy.sh (automatic deploys) or alone (--check).
#
#   1. Every container of the service: the image env/<env>.versions names; running; healthy (ai-beat has no health
#      check: running is enough); its org.opencontainers.image.revision label starts with the tag's 7 characters.
#   2. Wait SOAK_S seconds, then again: still running and healthy, same start time, no restart.
#   3. The probes (Runbook 5, sections 7.3, 7.4 and 7.6). The public addresses are asked from the VM: the request
#      still goes out through Cloudflare and back through the tunnel, and no runner address can be blocked.
#        ai       ai-api /ready "ready"; backend-web reaches http://ai-api:8000/ready; /api/ready/ has ai ok
#        backend  https://staging-api…/api/health/ 200 "ok"; /api/ready/ 200 "ready" (db, redis, storage, ai)
#        web      https://staging-app…/ 200; /config.js 200 and points at https://staging-api…
#
# Every check runs; exit 0 only when all of them pass. Prints names, tags, states, HTTP codes and
# the names of failing readiness checks only: no response body, no log line, no value. The workflow's log is public.
# The logs themselves are read on the VM (Runbook 5, section 9.1).

set -euo pipefail

SOAK_S=60
ROOT=/srv/iltiam

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 2 ]] || die "usage: $0 staging <ai|backend|web>"
env_name="$1"
service="$2"
case "$env_name" in
  staging)
    api=https://staging-api.iltiamcare.com
    app=https://staging-app.iltiamcare.com
    ;;
  *) die "only staging has a health check here, got '$env_name'" ;;
esac

repo="$(cd "$(dirname "$0")/.." && pwd)"
versions="$repo/env/$env_name.versions"
[[ -f "$versions" ]] || die "$versions not found"
compose() { bash "$repo/scripts/compose.sh" "$env_name" "$@"; }
pin() { sed -n "s/^$1=//p" "$versions" | tr -d '\r' | tail -n 1; }
profiles="$(pin COMPOSE_PROFILES)"

# container=versions key
case "$service" in
  ai) containers=(ai-api=AI_API_IMAGE ai-worker=AI_WORKER_IMAGE ai-beat=AI_WORKER_IMAGE) ;;
  backend) containers=(backend-web=BACKEND_IMAGE backend-worker=BACKEND_IMAGE backend-beat=BACKEND_IMAGE) ;;
  web) containers=(web=WEB_IMAGE) ;;
  *) die "service must be ai, backend or web, got '$service'" ;;
esac
if [[ "$service" != ai && ",$profiles," != *",$service,"* ]]; then
  die "the $service profile is off in env/$env_name.versions: nothing to check"
fi
backend_on=false
[[ ",$profiles," == *",backend,"* ]] && backend_on=true

failures=0
ok() { printf '    ok: %s\n' "$*"; }
bad() {
  printf '    FAIL: %s\n' "$*"
  failures=$((failures + 1))
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- 1 and 2. Containers ----------------------------------------------------------------------------------------

declare -A started=() restarts=()

# $1 container, $2 versions key, $3 first|again
check_container() {
  local name="$1" key="$2" pass="$3" before="$failures" ids id expected image status health count start rev tag
  expected="$(pin "$key")"
  ids="$(compose ps -q "$name" || true)"
  if [[ -z "$ids" || "$(wc -l <<<"$ids")" -ne 1 ]]; then
    bad "$name: expected one container, found $(grep -c . <<<"$ids" || true)"
    return
  fi
  id="$ids"
  IFS='|' read -r image status health count start rev < <(docker inspect --format \
    '{{.Config.Image}}|{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}|{{.RestartCount}}|{{.State.StartedAt}}|{{index .Config.Labels "org.opencontainers.image.revision"}}' \
    "$id" || true) || {
    bad "$name: docker inspect failed"
    return
  }
  if [[ "$pass" == first ]]; then
    [[ "$image" == "$expected" ]] || bad "$name: runs $image, env/$env_name.versions says $expected"
    tag="${expected##*:}"
    if [[ "$tag" == sha-* ]]; then
      [[ "$rev" == "${tag#sha-}"* ]] || bad "$name: revision label '${rev:0:12}' is not the build of $tag"
    fi
    started[$name]="$start"
    restarts[$name]="$count"
  else
    [[ "$start" == "${started[$name]:-}" && "$count" == "${restarts[$name]:-}" ]] \
      || bad "$name: restarted during the last $SOAK_S s (restarts: ${restarts[$name]:-?} -> $count)"
  fi
  [[ "$status" == running ]] || bad "$name: $status"
  if [[ "$health" != healthy && "$health" != none ]]; then
    bad "$name: $health"
  fi
  if ((failures == before)); then ok "$name: ${image##*/}, $status, health $health"; fi
}

echo "==> $service containers ($env_name)"
for entry in "${containers[@]}"; do check_container "${entry%%=*}" "${entry#*=}" first; done
echo "==> again after $SOAK_S s"
sleep "$SOAK_S"
for entry in "${containers[@]}"; do check_container "${entry%%=*}" "${entry#*=}" again; done

# --- 3. Probes --------------------------------------------------------------------------------------------------

# $1 URL, $2 file for the body. Prints the HTTP code (000: no answer). Retries a few times: the tunnel can take a
# moment to reach a container that has just started.
http() {
  curl -sS -o "$2" -w '%{http_code}' --max-time 20 --retry 3 --retry-delay 5 "$1" 2>/dev/null || true
}

# $1 file with a JSON body. Prints `status` and the names in `failing` (names only).
json_status() {
  python3 - "$1" <<'EOF' 2>/dev/null || echo "unreadable"
import json, sys
body = json.load(open(sys.argv[1]))
print(body.get("status"), ",".join(body.get("failing") or []) or "-")
EOF
}

api_ready() {
  local code status failing
  code="$(http "$api/api/ready/" "$work/ready.json")"
  read -r status failing <<<"$(json_status "$work/ready.json")"
  if [[ "$code" == 200 && "$status" == ready ]]; then
    ok "$api/api/ready/: 200 ready"
  else
    bad "$api/api/ready/: $code ${status:-} (failing: ${failing:-?})"
  fi
}

# In-container probe of a /ready that answers {"status": "ready"}. Succeeds or fails by its exit code; on failure it
# prints only the error class or the status word, never the body.
in_container() {
  local name="$1" url="$2"
  compose exec -T "$name" python -c "
import json, sys, urllib.request as u
try:
    body = json.load(u.urlopen('$url', timeout=5))
except Exception as e:
    sys.exit(type(e).__name__)
sys.exit(0 if body.get('status') == 'ready' else 'status ' + str(body.get('status')))
" 2>&1 | tail -n 1
}

echo "==> $service probes"
case "$service" in
  ai)
    if out="$(in_container ai-api http://127.0.0.1:8000/ready)"; then
      ok "ai-api /ready: ready"
    else
      bad "ai-api /ready: ${out:-failed}"
    fi
    if [[ "$backend_on" == true ]]; then
      if out="$(in_container backend-web http://ai-api:8000/ready)"; then
        ok "backend-web -> ai-api:8000/ready: ready"
      else
        bad "backend-web -> ai-api:8000/ready: ${out:-failed}"
      fi
      api_ready
    fi
    ;;
  backend)
    code="$(http "$api/api/health/" "$work/health.json")"
    read -r status _ <<<"$(json_status "$work/health.json")"
    if [[ "$code" == 200 && "$status" == ok ]]; then
      ok "$api/api/health/: 200 ok"
    else
      bad "$api/api/health/: $code ${status:-}"
    fi
    api_ready
    ;;
  web)
    code="$(http "$app/" "$work/index.html")"
    if [[ "$code" == 200 ]]; then ok "$app/: 200"; else bad "$app/: $code"; fi
    code="$(http "$app/config.js" "$work/config.js")"
    if [[ "$code" == 200 ]] && grep -qF "$api" "$work/config.js"; then
      ok "$app/config.js: 200, points at $api"
    else
      bad "$app/config.js: $code, or it doesn't point at $api"
    fi
    ;;
esac

# Containers in a bad state: a hint, not their logs (public log).
if ((failures > 0)); then
  printf '\n%s check(s) failed. On the VM: %s/repo/scripts/compose.sh %s logs --tail 100 <service>\n' \
    "$failures" "$ROOT" "$env_name"
  exit 1
fi
echo "==> $service healthy on $env_name"
