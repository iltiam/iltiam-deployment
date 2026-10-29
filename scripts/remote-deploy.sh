#!/usr/bin/env bash
# From the deploy workflow's runner to iltiam-1 over SSH (Runbook 5): check out the commit, copy the rendered env
# files, log in to GHCR, run scripts/deploy.sh, log out.
#
# Usage, in the deploy workflow only:
#   bash scripts/remote-deploy.sh <staging|production> <directory written by scripts/render-deploy-env.sh>
#
# From the environment (never arguments):
#   DEPLOY_HOST  the VM's address (an Environment secret: this repository is public)
#   DEPLOY_SHA   the commit of this repository to deploy (github.sha)
#   GHCR_USER    github.actor;  GHCR_TOKEN  the job's own GITHUB_TOKEN (packages: read), dead when the job ends
# The workflow wrote the environment's SSH key to ~/.ssh/iltiam_deploy and the VM's host key to ~/.ssh/known_hosts.
#
# Every file and the token travel on SSH's stdin, so they never appear in a command line or in this public log.

set -euo pipefail

REPO=/srv/iltiam/repo

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 2 && ("$1" == staging || "$1" == production) ]] \
  || die "usage: $0 <staging|production> <rendered directory>"
env_name="$1"
rendered="$2"
env_dir="/srv/iltiam/env/$env_name"
[[ -d "$rendered" ]] || die "$rendered not found"
[[ -n "${DEPLOY_HOST:-}" ]] || die "DEPLOY_HOST is not set (Environment secret, Runbook 5, section 5)"
[[ "${DEPLOY_SHA:-}" =~ ^[0-9a-f]{40}$ ]] || die "DEPLOY_SHA must be a full commit hash"
[[ "${GHCR_USER:-}" =~ ^[A-Za-z0-9][A-Za-z0-9-]*(\[bot\])?$ ]] || die "GHCR_USER is not a GitHub user name"
[[ -n "${GHCR_TOKEN:-}" ]] || die "GHCR_TOKEN is not set"

ssh_opts=(
  -i "$HOME/.ssh/iltiam_deploy" -o IdentitiesOnly=yes -o BatchMode=yes
  -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$HOME/.ssh/known_hosts" -o ConnectTimeout=20
)
# The remote commands are built here on purpose, from checked names and paths only; never from a secret.
# shellcheck disable=SC2029
remote() { ssh "${ssh_opts[@]}" "deploy@$DEPLOY_HOST" "$@"; }

echo "==> connect"
remote true || die "SSH as deploy failed: key, known_hosts or host (Runbook 5, section 13)"

echo "==> repository at ${DEPLOY_SHA:0:7}"
remote "test -d $REPO/.git" || die "$REPO is not a clone of this repository (Runbook 5, section 4.3)"
remote "git -C $REPO fetch --quiet origin && git -C $REPO checkout --quiet --detach $DEPLOY_SHA"

echo "==> env files"
remote "test -d $env_dir && test \"\$(stat -c %a $env_dir)\" = 700" \
  || die "$env_dir must exist with mode 700 (Runbook 5, section 4.2)"
for file in "$rendered"/*; do
  name="$(basename "$file")"
  mode=600
  [[ "$name" == fcm-service-account.json ]] && mode=644
  remote "umask 077 && cat > $env_dir/.$name.tmp && chmod $mode $env_dir/.$name.tmp && mv -f $env_dir/.$name.tmp $env_dir/$name" \
    <"$file"
  printf '    %s (%s)\n' "$name" "$mode"
done

echo "==> GHCR"
# The login lasts only for this deploy: logged out again on any exit.
trap 'remote "docker logout ghcr.io" >/dev/null 2>&1 || true' EXIT
printf '%s' "$GHCR_TOKEN" | remote "docker login ghcr.io --username $GHCR_USER --password-stdin" >/dev/null
echo "    logged in"

remote "bash $REPO/scripts/deploy.sh $env_name"
