#!/usr/bin/env bash
# `docker compose` for one environment's project on iltiam-1, with the right project name, env files and paths
# (Runbook 5, docs/runbooks/05-compose-stack.md). Use it for everything day to day; scripts/deploy.sh uses it too.
#
# Usage, on the VM as deploy, from anywhere:
#   /srv/iltiam/repo/scripts/compose.sh <staging|production> <docker compose command and arguments>
#   .../compose.sh staging ps
#   .../compose.sh staging logs --tail 100 backend-web
#   .../compose.sh production restart ai-worker
#
# It runs: docker compose -p iltiam-staging|iltiam-prod -f compose.yml [-f compose.fcm.yml]
#          --env-file /srv/iltiam/env/<env>/infra.env --env-file env/<env>.versions <your arguments>
# with ENV_DIR, DATA_DIR and COMPOSE_PROFILES set. compose.fcm.yml is added only when the environment's
# fcm-service-account.json exists.
#
# `config` prints every secret Compose interpolates, and this repository's logs are public. So on the VM, `config` is
# refused unless it only prints names (--quiet, --services, --images, --profiles, --networks, --volumes).
# ILTIAM_ROOT (default /srv/iltiam) lets scripts/check-compose.sh run this against dummy files; outside /srv/iltiam
# `config` is unrestricted, because only dummies live there.

set -euo pipefail

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

# Docker Compose on Windows is a Windows program: hand it C:/... paths (only for the checks in Git Bash).
native() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

[[ $# -ge 2 ]] || die "usage: $0 <staging|production> <docker compose command and arguments>"
env_name="$1"
shift
case "$env_name" in
  staging) project=iltiam-staging ;;
  production) project=iltiam-prod ;;
  *) die "environment must be staging or production, got '$env_name'" ;;
esac

repo="$(cd "$(dirname "$0")/.." && pwd)"
root="${ILTIAM_ROOT:-/srv/iltiam}"
env_dir="$root/env/$env_name"
infra="$env_dir/infra.env"
versions="$repo/env/$env_name.versions"

if [[ "$1" == config && "$root" == /srv/iltiam ]]; then
  for arg in "${@:2}"; do
    case "$arg" in
      -q | --quiet | --services | --images | --profiles | --networks | --volumes) ;;
      *) die "'config $arg' would print secrets into this terminal. Use 'config --quiet' (Runbook 5, section 13)" ;;
    esac
  done
  [[ $# -ge 2 ]] || die "'config' alone would print every secret. Use 'config --quiet' (Runbook 5, section 13)"
fi

[[ -f "$versions" ]] || die "$versions not found"
[[ -r "$infra" ]] || die "$infra not found or not readable: deploy $env_name first (Runbook 5, section 6)"

files=(-f "$(native "$repo/compose.yml")")
if [[ -e "$env_dir/fcm-service-account.json" ]]; then
  files+=(-f "$(native "$repo/compose.fcm.yml")")
fi

# Read here and exported, so the profiles never depend on whether this Compose version reads them from --env-file.
COMPOSE_PROFILES="$(sed -n 's/^COMPOSE_PROFILES=//p' "$versions" | tr -d '\r' | tail -n 1)"
ENV_DIR="$(native "$env_dir")"
DATA_DIR="$(native "$root/$env_name")"
export COMPOSE_PROFILES ENV_DIR DATA_DIR

exec docker compose -p "$project" "${files[@]}" \
  --env-file "$(native "$infra")" --env-file "$(native "$versions")" "$@"
