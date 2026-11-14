#!/usr/bin/env bash
# Deploy production from a laptop: the replacement for Actions -> deploy -> Run workflow with environment production
# (Runbook 5). Run by a person only, after typing a confirmation. NOT YET VERIFIED against the real VM.
#
#   scripts/deploy-prod.sh --dry-run [--offline] [--ssh-check]   preflight only, nothing changes
#   scripts/deploy-prod.sh                                         preflight, confirmation, deploy
#
# Production's tags change only through a reviewed PR to env/production.versions (main is protected). This script
# deploys main as it is: this clone must be at origin/main with no local change. As the workflow did, it takes no
# database backup (scripts/pre-deploy-backup.sh refuses production): take one first by hand (Runbook 5).
# scripts/health-check.sh is staging-only; scripts/deploy.sh itself waits for every service to be healthy.
# On a failure it offers (with a second confirmation) to redeploy the commit the VM ran before.
set -euo pipefail
# shellcheck source=lib/deploy-local.sh disable=SC1091
. "$(dirname "$0")/lib/deploy-local.sh"

DL_DRY_RUN=no
OFFLINE=no
SSH_CHECK=no
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DL_DRY_RUN=yes ;;
    --offline) OFFLINE=yes ;;
    --ssh-check) SSH_CHECK=yes ;;
    -h | --help) sed -n '2,13p' "$0"; exit 2 ;;
    *) dl_die "unknown option $1 (--help)" ;;
  esac
  shift
done
[ "$OFFLINE" = no ] || [ "$DL_DRY_RUN" = yes ] || dl_die "--offline is for --dry-run only"

dl_step "preflight: production$([ "$DL_DRY_RUN" = yes ] && echo ' (dry run, nothing changes)')"
dl_tools
dl_repo_at_main "$OFFLINE"
dl_versions production
if [ "$OFFLINE" = yes ]; then
  dl_warn "offline: images not checked against GHCR"
else
  dl_ghcr_credentials
  dl_check_images production
fi
have_secrets=yes
dl_secrets production "$([ "$DL_DRY_RUN" = yes ] && echo no || echo yes)" || have_secrets=no
if [ $have_secrets = yes ]; then
  dl_render production
  dl_ssh_files production
else
  dl_warn "no production secrets here: env rendering, DEPLOY_HOST and SSH files NOT checked"
fi
if [ "$SSH_CHECK" = yes ]; then
  [ $have_secrets = yes ] || dl_die "--ssh-check needs the secrets (DEPLOY_HOST)"
  dl_ssh true </dev/null || dl_die "SSH as deploy failed (Runbook 5, section 13)"
  dl_ok "SSH login as deploy works (read-only)"
fi

if [ "$DL_DRY_RUN" = yes ]; then
  echo
  echo "Dry run complete. A real run would ask you to type 'deploy production ${DEPLOY_SHA:0:7}', then record the VM's"
  echo "current commit and run scripts/remote-deploy.sh production at ${DEPLOY_SHA:0:7}."
  dl_summary
  exit 0
fi

[ -t 0 ] || dl_die "production needs a person at a terminal to type the confirmation"
echo
echo "Production will run env/production.versions at ${DEPLOY_SHA:0:7}:"
dl_images production | sed 's/^/    /'
expected="deploy production ${DEPLOY_SHA:0:7}"
printf "Type '%s' to continue: " "$expected"
read -r answer
[ "$answer" = "$expected" ] || dl_die "confirmation did not match; nothing was changed"

dl_step "rollback point"
previous="$(dl_vm_commit)" || dl_die "could not read the VM's current commit"
[[ "$previous" =~ ^[0-9a-f]{40}$ ]] || dl_die "the VM's clone did not report a commit"
dl_ok "the VM runs ${previous:0:7}"

dl_step "deploy ${DEPLOY_SHA:0:7}"
if bash scripts/remote-deploy.sh production "$DL_RENDERED"; then
  echo
  echo "Production: deployed ${DEPLOY_SHA:0:7}. Check the public probes (Runbook 5, section 7)."
  dl_summary
  exit 0
fi

echo
echo "The production deploy FAILED."
printf "Type 'roll back production %s' to redeploy the previous commit, anything else to stop: " "${previous:0:7}"
read -r answer
if [ "$answer" = "roll back production ${previous:0:7}" ]; then
  export DEPLOY_SHA="$previous"
  bash scripts/remote-deploy.sh production "$DL_RENDERED" && echo "Rolled back to ${previous:0:7}; open a revert PR for env/production.versions."
fi
exit 1
