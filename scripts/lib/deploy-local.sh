# shellcheck shell=bash
# deploy-local.sh: shared by scripts/deploy-staging.sh and scripts/deploy-prod.sh, the laptop replacement for the
# deploy workflow (.github/workflows/deploy.yml, kept and disabled). LOCAL_CI_MIGRATION.md, "Manual deployment".
#
# Nothing here deploys after a push or a merge: a person runs the script, and production asks for a typed confirmation.
# THIS REPOSITORY IS PUBLIC and the scripts may be run with a screen shared: they print names, tags and states only,
# never a value. Never `set -x`.
#
# Where the secrets come from (never from this repository):
#   SECRETS_JSON / VARS_JSON   the environment's secrets and variables as JSON objects, as the workflow passed them
#                              (same names as the GitHub Environment: DEPLOY_HOST, the env templates' names, ...)
#   else $ILTIAM_DEPLOY_DIR/<env>/secrets.json and vars.json   (default ILTIAM_DEPLOY_DIR: ~/.iltiam/deploy)
#   SSH: DEPLOY_SSH_KEY_FILE and DEPLOY_KNOWN_HOSTS_FILE, else $ILTIAM_DEPLOY_DIR/<env>/ssh_key and known_hosts
#   GHCR (the VM pulls the private images with it, logged out after the deploy): GHCR_USER + GHCR_TOKEN, a token with
#   read:packages only; else the signed-in gh CLI's login and token (broader: prefer a dedicated token).

DL_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DL_TMP=""
DL_WARNINGS=()

dl_die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}
dl_step() { printf '\n==> %s\n' "$*"; }
dl_ok() { printf '    ok: %s\n' "$*"; }
dl_warn() {
  printf '    WARNING: %s\n' "$*"
  DL_WARNINGS+=("$*")
}

dl_cleanup() {
  [ -n "$DL_TMP" ] && [ -d "$DL_TMP" ] && rm -rf "$DL_TMP"
}

dl_tmp() {
  if [ -z "$DL_TMP" ]; then
    DL_TMP="$(mktemp -d "${TMPDIR:-/tmp}/iltiam-deploy-XXXXXX")"
    chmod 700 "$DL_TMP"
    trap dl_cleanup EXIT
  fi
}

# dl_repo_at_main <offline>: this clone is clean and at origin/main; sets DEPLOY_SHA.
dl_repo_at_main() {
  local offline="$1"
  cd "$DL_REPO" || dl_die "cannot enter $DL_REPO"
  if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    if [ "${DL_DRY_RUN:-no}" = yes ]; then
      dl_warn "uncommitted changes in this clone: a real deploy refuses this"
    else
      dl_die "uncommitted changes in $DL_REPO: deploy only committed, reviewed files"
    fi
  fi
  if [ "$offline" = yes ]; then
    dl_warn "offline: origin/main not fetched; using the local origin/main"
  else
    git fetch -q origin main || dl_die "git fetch origin main failed"
  fi
  DEPLOY_SHA="$(git rev-parse HEAD)"
  local main
  main="$(git rev-parse origin/main)"
  if [ "$DEPLOY_SHA" != "$main" ]; then
    if [ "${DL_DRY_RUN:-no}" = yes ]; then
      dl_warn "HEAD ${DEPLOY_SHA:0:7} is not origin/main ${main:0:7}: a real deploy refuses this"
    else
      dl_die "HEAD ${DEPLOY_SHA:0:7} is not origin/main ${main:0:7}: check out main and pull (the VM checks out this exact commit)"
    fi
  fi
  export DEPLOY_SHA
  dl_ok "deployment repository at ${DEPLOY_SHA:0:7}"
}

dl_tools() {
  local t
  for t in git jq ssh openssl curl; do
    command -v "$t" >/dev/null 2>&1 || dl_die "$t is not installed"
  done
  dl_ok "git, jq, ssh, openssl, curl"
}

dl_versions() {
  bash "$DL_REPO/scripts/deploy.sh" --check-versions "$1" >/dev/null || dl_die "env/$1.versions is not valid"
  dl_ok "env/$1.versions is well formed"
}

# The images env/<env>.versions names for the services that run (COMPOSE_PROFILES decides backend and web).
dl_images() {
  local file="$DL_REPO/env/$1.versions" profiles
  profiles="$(sed -n 's/\r$//; s/^COMPOSE_PROFILES=//p' "$file")"
  sed -n 's/\r$//; s/^\(AI_API_IMAGE\|AI_WORKER_IMAGE\)=//p' "$file"
  case ",$profiles," in *,backend,*) sed -n 's/\r$//; s/^BACKEND_IMAGE=//p' "$file" ;; esac
  case ",$profiles," in *,web,*) sed -n 's/\r$//; s/^WEB_IMAGE=//p' "$file" ;; esac
}

dl_ghcr_credentials() {
  if [ -z "${GHCR_USER:-}" ] || [ -z "${GHCR_TOKEN:-}" ]; then
    command -v gh >/dev/null 2>&1 || dl_die "set GHCR_USER and GHCR_TOKEN (read:packages), or sign in with gh"
    GHCR_USER="$(gh api user --jq .login 2>/dev/null)" || dl_die "gh is not signed in"
    GHCR_TOKEN="$(gh auth token 2>/dev/null)" || dl_die "gh has no token"
    dl_warn "using the gh CLI's token for GHCR (broader than read:packages; prefer GHCR_USER + GHCR_TOKEN)"
  fi
  export GHCR_USER GHCR_TOKEN
}

# dl_image_published <ghcr.io/iltiam/name:tag>: the tag exists and has linux/arm64 (the VM). The registry API with a
# short-lived pull token: no `docker login`, nothing stored.
dl_image_published() {
  local ref="$1" name tag token manifest
  name="${ref#ghcr.io/}"
  tag="${name##*:}"
  name="${name%:*}"
  token="$(curl -fsS -u "$GHCR_USER:$GHCR_TOKEN" "https://ghcr.io/token?scope=repository:$name:pull&service=ghcr.io" | jq -r .token)" ||
    return 1
  manifest="$(curl -fsS -H "Authorization: Bearer $token" \
    -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json' \
    "https://ghcr.io/v2/$name/manifests/$tag")" || { echo "    $ref: not published (or no read access)"; return 1; }
  printf '%s' "$manifest" | jq -e '[.manifests[]?.platform.architecture] | index("arm64")' >/dev/null ||
    { echo "    $ref: no linux/arm64"; return 1; }
  dl_ok "$ref published, linux/arm64"
}

dl_check_images() {
  local env="$1" ref failed=0
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    dl_image_published "$ref" || failed=1
  done < <(dl_images "$env")
  [ $failed -eq 0 ] || dl_die "an image env/$env.versions names is not deployable"
}

# dl_secrets <env> <required yes|no>: SECRETS_JSON and VARS_JSON in the environment, from the files when unset.
# Returns 1 when they are missing and not required (an offline dry-run).
dl_secrets() {
  local env="$1" required="$2" dir="${ILTIAM_DEPLOY_DIR:-$HOME/.iltiam/deploy}/$1"
  if [ -z "${SECRETS_JSON:-}" ] && [ -f "$dir/secrets.json" ]; then SECRETS_JSON="$(cat "$dir/secrets.json")"; fi
  if [ -z "${VARS_JSON:-}" ] && [ -f "$dir/vars.json" ]; then VARS_JSON="$(cat "$dir/vars.json")"; fi
  if [ -z "${SECRETS_JSON:-}" ] || [ -z "${VARS_JSON:-}" ]; then
    [ "$required" = yes ] && dl_die "no secrets for $env: set SECRETS_JSON and VARS_JSON, or create $dir/secrets.json and vars.json"
    return 1
  fi
  printf '%s' "$SECRETS_JSON" | jq -e 'type == "object"' >/dev/null || dl_die "SECRETS_JSON is not a JSON object"
  printf '%s' "$VARS_JSON" | jq -e 'type == "object"' >/dev/null || dl_die "VARS_JSON is not a JSON object"
  DEPLOY_HOST="$(printf '%s' "$SECRETS_JSON" | jq -r '.DEPLOY_HOST // empty')"
  [ -n "$DEPLOY_HOST" ] || dl_die "DEPLOY_HOST is missing from the $env secrets"
  export SECRETS_JSON VARS_JSON DEPLOY_HOST
  dl_ok "secrets and variables for $env loaded (names only are ever printed)"
}

# dl_ssh_files <env>: the environment's key and the VM's host key, as files remote-deploy.sh reads.
dl_ssh_files() {
  local dir="${ILTIAM_DEPLOY_DIR:-$HOME/.iltiam/deploy}/$1"
  DEPLOY_SSH_KEY_FILE="${DEPLOY_SSH_KEY_FILE:-$dir/ssh_key}"
  DEPLOY_KNOWN_HOSTS_FILE="${DEPLOY_KNOWN_HOSTS_FILE:-$dir/known_hosts}"
  [ -f "$DEPLOY_SSH_KEY_FILE" ] || dl_die "no SSH key at DEPLOY_SSH_KEY_FILE (default $dir/ssh_key)"
  [ -s "$DEPLOY_KNOWN_HOSTS_FILE" ] || dl_die "no known_hosts at DEPLOY_KNOWN_HOSTS_FILE (default $dir/known_hosts)"
  export DEPLOY_SSH_KEY_FILE DEPLOY_KNOWN_HOSTS_FILE
  dl_ok "SSH key and known_hosts files present"
}

dl_ssh() {
  # shellcheck disable=SC2029
  ssh -i "$DEPLOY_SSH_KEY_FILE" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes \
    -o UserKnownHostsFile="$DEPLOY_KNOWN_HOSTS_FILE" -o ConnectTimeout=20 "deploy@$DEPLOY_HOST" "$@"
}

# dl_render <env>: the env files into a private temporary directory (deleted on exit); sets DL_RENDERED.
dl_render() {
  dl_tmp
  DL_RENDERED="$DL_TMP/rendered"
  bash "$DL_REPO/scripts/render-deploy-env.sh" "$1" "$DL_RENDERED" || dl_die "rendering the $1 env files failed"
  dl_ok "env files rendered to a private temporary directory (removed on exit)"
}

# The commit the VM's clone has checked out: what a rollback goes back to.
dl_vm_commit() {
  dl_ssh "git -C /srv/iltiam/repo rev-parse HEAD" </dev/null
}

dl_summary() {
  local w
  if [ ${#DL_WARNINGS[@]} -gt 0 ]; then
    echo
    echo "Warnings:"
    for w in "${DL_WARNINGS[@]}"; do echo "  - $w"; done
  fi
}
