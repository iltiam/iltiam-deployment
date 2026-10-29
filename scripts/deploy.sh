#!/usr/bin/env bash
# Deploy one environment's Compose project on iltiam-1 (Runbook 5, docs/runbooks/05-compose-stack.md, issue #2).
#
# Usage:
#   scripts/deploy.sh <staging|production>                   on the VM as deploy. The deploy workflow runs it over
#                                                            SSH, after writing the env files and logging in to GHCR.
#   scripts/deploy.sh --check-versions <staging|production>  only check env/<env>.versions; any machine (CI)
#
# In order. Running it again with the same tags changes nothing: no running container is recreated.
#   1. Guards: arm64, not root, /srv/iltiam is the mounted data volume, the env files are there (600 in a 700
#      directory), env/<env>.versions is well formed and names no unpublished image for a service that will run.
#      One deploy at a time on the VM, whatever the environment (flock).
#   2. The Docker Compose version, printed; 2.20 or newer.
#   3. Pull the images of the services this environment runs.
#   4. postgres and redis, healthy.
#   5. The one-shots, each with `docker compose run --rm` and its exit code checked: weights-init, then
#      backend-migrate (backend profile only). They run apart from `up --wait` on purpose: some Compose versions
#      count a one-shot that exited 0 as a failure of `up --wait`, others wait for it. Run first, both behave alike.
#   6. The long-running services, `up -d --wait --no-deps`, in dependency order: ai-api and backend-web, then the
#      rest.
#   7. What runs now: service, image, state, digest.
#
# Prints names, tags and states only, never a value: the workflow's log is public. Never `set -x` here.

set -euo pipefail

ROOT=/srv/iltiam
MIN_COMPOSE=2.20
WAIT_TIMEOUT=600

log() { printf '\n==> %s\n' "$*"; }
ok() { printf '    ok: %s\n' "$*"; }

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  die "usage: $0 <staging|production>  |  $0 --check-versions <staging|production>"
}

repo="$(cd "$(dirname "$0")/.." && pwd)"

# --- versions file ---------------------------------------------------------------------------------------------

KNOWN_KEYS=(COMPOSE_PROFILES AI_API_IMAGE AI_WORKER_IMAGE BACKEND_IMAGE)
KNOWN_PROFILES=(backend)
# registry/path:tag; the tag as Docker allows it.
IMAGE_RE='^[a-z0-9.-]+(:[0-9]+)?(/[a-z0-9._-]+)+:([A-Za-z0-9_][A-Za-z0-9_.-]{0,127})$'
declare -A V=()

# Read env/<env>.versions into V; refuse anything malformed. $2 = strict: also refuse `to-confirm` for a running
# service (a deploy). Not strict (CI) accepts it, so the files can name images that aren't published yet.
check_versions() {
  local strict="$2" file="$repo/env/$1.versions" line key value lineno=0 name tag profile profiles
  [[ -f "$file" ]] || die "$file not found"
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ "$line" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]] || die "$file:$lineno: expected NAME=value or a comment line"
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    [[ " ${KNOWN_KEYS[*]} " == *" $key "* ]] || die "$file:$lineno: unknown name $key"
    [[ -z "${V[$key]+set}" ]] || die "$file:$lineno: $key appears twice"
    [[ "$value" != *[[:space:]\#\"\']* ]] || die "$file:$lineno: $key: no spaces, quotes or comments after the value"
    V[$key]="$value"
  done <"$file"

  for key in "${KNOWN_KEYS[@]}"; do
    [[ -n "${V[$key]+set}" ]] || die "$file: $key is missing"
  done
  IFS=, read -ra profiles <<<"${V[COMPOSE_PROFILES]}"
  for profile in "${profiles[@]}"; do
    [[ " ${KNOWN_PROFILES[*]} " == *" $profile "* ]] || die "$file: unknown profile '$profile' in COMPOSE_PROFILES"
  done

  for name in AI_API_IMAGE AI_WORKER_IMAGE BACKEND_IMAGE; do
    [[ "${V[$name]}" =~ $IMAGE_RE ]] || die "$file: $name must be registry/name:tag, got '${V[$name]}'"
    tag="${BASH_REMATCH[3]}"
    [[ "$tag" != latest ]] || die "$file: $name: never 'latest'; pin sha-<7> or X.Y.Z"
    if [[ "$strict" == strict && "$tag" == to-confirm ]]; then
      if [[ "$name" != BACKEND_IMAGE ]] || backend_on; then
        die "$file: $name is still 'to-confirm': put the published tag in, merge, then deploy"
      fi
    fi
  done
  # One build: weights-init uses the worker image's model registry, the api must check the same files.
  [[ "${V[AI_API_IMAGE]##*:}" == "${V[AI_WORKER_IMAGE]##*:}" ]] \
    || die "$file: AI_API_IMAGE and AI_WORKER_IMAGE must have the same tag"
}

backend_on() {
  [[ ",${V[COMPOSE_PROFILES]}," == *",backend,"* ]]
}

# --- arguments --------------------------------------------------------------------------------------------------

if [[ "${1:-}" == --check-versions ]]; then
  [[ $# -eq 2 && ("$2" == staging || "$2" == production) ]] || usage
  check_versions "$2" lenient
  ok "env/$2.versions: well formed; profiles '${V[COMPOSE_PROFILES]}'"
  exit 0
fi
[[ $# -eq 1 && ("$1" == staging || "$1" == production) ]] || usage
env_name="$1"
env_dir="$ROOT/env/$env_name"
compose() { bash "$repo/scripts/compose.sh" "$env_name" "$@"; }

# --- 1. Guards --------------------------------------------------------------------------------------------------

log "guards ($env_name)"
[[ "$(uname -m)" == aarch64 ]] || die "expected the arm64 VM iltiam-1, this is $(uname -m)"
[[ "$(id -u)" -ne 0 ]] || die "run as deploy, not root"
# /srv/iltiam is mounted with nofail. Without it, Docker would create empty data directories on the boot disk and
# Postgres would start a new, empty database there.
mountpoint -q "$ROOT" || die "$ROOT is not mounted: the data volume is missing (Runbook 1, section 10; Runbook 5, section 13)"
ok "$ROOT is a mounted volume"

check_versions "$env_name" strict
ok "env/$env_name.versions: profiles '${V[COMPOSE_PROFILES]}'"

[[ -d "$env_dir" ]] || die "$env_dir not found (Runbook 5, section 4)"
[[ "$(stat -c '%a %U' "$env_dir")" == "700 $(id -un)" ]] || die "$env_dir must be mode 700, owned by $(id -un)"
needed=(infra.env ai.env)
if backend_on; then needed+=(backend.env); fi
for file in "${needed[@]}"; do
  [[ -f "$env_dir/$file" ]] || die "$env_dir/$file is missing: run the deploy workflow, which writes it"
  [[ "$(stat -c '%a' "$env_dir/$file")" == 600 ]] || die "$env_dir/$file must be mode 600"
done
if ! backend_on && [[ ! -e "$env_dir/backend.env" ]]; then
  # The backend's services are off, but compose.yml still names their env file; some Compose versions want it to
  # exist even then. An empty one is enough, and the next deploy with the backend on overwrites it.
  (umask 077 && : >"$env_dir/backend.env")
fi
if [[ -e "$env_dir/fcm-service-account.json" ]]; then
  [[ "$(stat -c '%a' "$env_dir/fcm-service-account.json")" == 644 ]] \
    || die "$env_dir/fcm-service-account.json must be mode 644 (docs/secrets.md, section 1)"
fi
ok "env files: ${needed[*]}"

[[ -d "$ROOT/weights" ]] || die "$ROOT/weights not found (Runbook 5, section 4)"

# One deploy at a time on the VM: two weights-init runs on the same directory would download twice.
exec 9>"$ROOT/env/.deploy.lock"
flock -n 9 || die "another deploy is running on this VM; wait for it to finish"
ok "deploy lock taken"

# --- 2. Compose version -----------------------------------------------------------------------------------------

log "docker compose version"
version="$(docker compose version --short)"
version="${version#v}"
printf '    docker %s, compose %s\n' "$(docker version --format '{{.Server.Version}}')" "$version"
lowest="$(printf '%s\n%s\n' "$MIN_COMPOSE" "$version" | sort -V | head -n 1)"
[[ "$lowest" == "$MIN_COMPOSE" ]] || die "Docker Compose $MIN_COMPOSE or newer is needed, this is $version"

# Validates the files and the interpolated values without printing them.
compose config --quiet
ok "compose files valid"

# --- 3. Images --------------------------------------------------------------------------------------------------

log "pull"
compose pull --quiet
ok "images present"

# --- 4. Data services -------------------------------------------------------------------------------------------

log "postgres and redis"
compose up -d --wait --wait-timeout "$WAIT_TIMEOUT" --no-deps postgres redis

# --- 5. One-shots -----------------------------------------------------------------------------------------------

log "weights-init"
compose run --rm --no-deps -T weights-init || die "weights-init failed; the AI service was left as it was"
if backend_on; then
  log "backend-migrate"
  compose run --rm --no-deps -T backend-migrate || die "backend migrations failed; the backend was left as it was"
fi

# --- 6. Long-running services -----------------------------------------------------------------------------------

first=(ai-api)
rest=(ai-worker ai-beat cloudflared)
if backend_on; then
  first+=(backend-web)
  rest+=(backend-worker backend-beat)
fi
log "start: ${first[*]}"
compose up -d --wait --wait-timeout "$WAIT_TIMEOUT" --no-deps "${first[@]}"
log "start: ${rest[*]}"
compose up -d --wait --wait-timeout "$WAIT_TIMEOUT" --no-deps --remove-orphans "${rest[@]}"

# --- 7. What runs -----------------------------------------------------------------------------------------------

log "running in this project"
compose ps --format 'table {{.Service}}\t{{.Image}}\t{{.Status}}'
echo
for image in $(compose ps --format '{{.Image}}' | sort -u); do
  printf '    %s\n' "$(docker image inspect --format '{{join .RepoDigests " "}}' "$image")"
done
log "deployed $env_name"
