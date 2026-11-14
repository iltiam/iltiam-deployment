#!/usr/bin/env bash
# Deploy staging from a laptop: the replacement for the deploy workflow's two staging paths (Runbooks 5 and 9), run by a
# person, never automatically. LOCAL_CI_MIGRATION.md, "Manual deployment". NOT YET VERIFIED against the real VM.
#
#   1. Point a service at a new build (was: the repository_dispatch "auto" job):
#        scripts/deploy-staging.sh --bump <ai|backend|web> <40-char commit of that repo's main> [--dry-run]
#      Checks the image sha-<7> is published with linux/arm64, runs scripts/set-version.sh on a branch
#      deploy/staging-<service>-sha-<7>, commits env/staging.versions, pushes and opens the PR. main is protected:
#      the change is reviewed like any other. Nothing is deployed by this step.
#   2. Deploy main as it is (was: Actions -> deploy -> Run workflow, staging), after that PR is merged:
#        scripts/deploy-staging.sh [--check <ai|backend|web>] [--dry-run [--offline] [--ssh-check]]
#      Preflight, then (backend changed: a pg_dump first, scripts/pre-deploy-backup.sh) scripts/remote-deploy.sh,
#      then scripts/health-check.sh for --check. On a failure it rolls the VM back to the commit it ran before and
#      tells you to open the revert PR, so main matches the VM again.
#
# --dry-run: everything that changes nothing: this clone at origin/main, the versions file, the images published,
# the secrets present and the env files rendered (then deleted), the SSH files present. --offline skips what needs the
# network (images, fetch); without secrets it says what it could not check. --ssh-check also connects to the VM and
# runs `true` there (a read-only login; it still touches staging).
set -euo pipefail
# shellcheck source=lib/deploy-local.sh disable=SC1091
. "$(dirname "$0")/lib/deploy-local.sh"

DL_DRY_RUN=no
OFFLINE=no
SSH_CHECK=no
BUMP_SERVICE=""
BUMP_SHA=""
CHECK_SERVICE=""

usage() { sed -n '2,23p' "$0"; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DL_DRY_RUN=yes ;;
    --offline) OFFLINE=yes ;;
    --ssh-check) SSH_CHECK=yes ;;
    --bump) BUMP_SERVICE="${2:-}"; BUMP_SHA="${3:-}"; shift 2 ;;
    --check) CHECK_SERVICE="${2:-}"; shift ;;
    -h | --help) usage ;;
    *) dl_die "unknown option $1 (--help)" ;;
  esac
  shift
done
[ "$OFFLINE" = no ] || [ "$DL_DRY_RUN" = yes ] || dl_die "--offline is for --dry-run only"
[ -z "$CHECK_SERVICE" ] || [[ "$CHECK_SERVICE" =~ ^(ai|backend|web)$ ]] || dl_die "--check takes ai, backend or web"

# --- 1. bump -------------------------------------------------------------------------------------------------------
if [ -n "$BUMP_SERVICE" ]; then
  [[ "$BUMP_SERVICE" =~ ^(ai|backend|web)$ ]] || dl_die "--bump takes ai, backend or web"
  [[ "$BUMP_SHA" =~ ^[0-9a-f]{40}$ ]] || dl_die "--bump needs the full 40-character commit hash"
  tag="sha-${BUMP_SHA:0:7}"
  branch="deploy/staging-$BUMP_SERVICE-$tag"
  dl_step "bump $BUMP_SERVICE to $tag$([ "$DL_DRY_RUN" = yes ] && echo ' (dry run)')"
  dl_tools
  dl_repo_at_main "$OFFLINE"
  case "$BUMP_SERVICE" in
    ai) images="iltiam-ai-api iltiam-ai-worker" ;;
    backend) images="iltiam-backend" ;;
    web) images="iltiam-web" ;;
  esac
  if [ "$OFFLINE" = yes ]; then
    dl_warn "offline: not checked that $tag is published"
  else
    dl_ghcr_credentials
    for image in $images; do dl_image_published "ghcr.io/iltiam/$image:$tag" || dl_die "publish it first (scripts/publish-image.sh)"; done
  fi
  # set-version.sh edits the file next to it, so a dry run uses a copy of the repository.
  dl_tmp
  mkdir -p "$DL_TMP/repo"
  cp -r "$DL_REPO/scripts" "$DL_REPO/env" "$DL_TMP/repo/"
  bash "$DL_TMP/repo/scripts/set-version.sh" staging "$BUMP_SERVICE" "$BUMP_SHA" | tee "$DL_TMP/version.out"
  grep -qx 'changed=true' "$DL_TMP/version.out" || { echo "env/staging.versions already names $tag: nothing to bump"; exit 0; }
  if [ "$DL_DRY_RUN" = yes ]; then
    diff -u "$DL_REPO/env/staging.versions" "$DL_TMP/repo/env/staging.versions" || true
    echo
    echo "Dry run: would create $branch, commit env/staging.versions, push it and open a PR. Nothing changed."
    dl_summary
    exit 0
  fi
  command -v gh >/dev/null 2>&1 || dl_die "gh is needed to open the PR"
  git switch -c "$branch" origin/main
  cp "$DL_TMP/repo/env/staging.versions" env/staging.versions
  bash scripts/deploy.sh --check-versions staging >/dev/null
  case "$BUMP_SERVICE" in ai) repo=iltiam-ai-service ;; backend) repo=iltiam-backend ;; web) repo=iltiam-web ;; esac
  git add env/staging.versions
  git commit -q -m "chore(staging): deploy $BUMP_SERVICE $tag" -m "iltiam/$repo@$BUMP_SHA, by scripts/deploy-staging.sh --bump."
  git push -q -u origin "$branch"
  gh pr create --base main --head "$branch" --title "chore(staging): deploy $BUMP_SERVICE $tag" \
    --body "Points env/staging.versions at \`$tag\` (iltiam/$repo@$BUMP_SHA). After merge: \`git switch main && git pull && scripts/deploy-staging.sh --check $BUMP_SERVICE\`."
  echo "Merge the PR after review, then deploy: scripts/deploy-staging.sh --check $BUMP_SERVICE"
  exit 0
fi

# --- 2. deploy -----------------------------------------------------------------------------------------------------
dl_step "preflight: staging$([ "$DL_DRY_RUN" = yes ] && echo ' (dry run, nothing changes)')"
dl_tools
dl_repo_at_main "$OFFLINE"
dl_versions staging
if [ "$OFFLINE" = yes ]; then
  dl_warn "offline: images not checked against GHCR"
else
  dl_ghcr_credentials
  dl_check_images staging
fi
have_secrets=yes
dl_secrets staging "$([ "$DL_DRY_RUN" = yes ] && echo no || echo yes)" || have_secrets=no
if [ $have_secrets = yes ]; then
  dl_render staging
  dl_ssh_files staging
else
  dl_warn "no staging secrets here: env rendering, DEPLOY_HOST and SSH files NOT checked"
fi
if [ "$SSH_CHECK" = yes ]; then
  [ $have_secrets = yes ] || dl_die "--ssh-check needs the secrets (DEPLOY_HOST)"
  dl_ssh true </dev/null || dl_die "SSH as deploy failed (Runbook 5, section 13)"
  dl_ok "SSH login as deploy works (read-only)"
fi
backup=no
if [ "$CHECK_SERVICE" = backend ]; then backup=yes; fi

if [ "$DL_DRY_RUN" = yes ]; then
  echo
  echo "Dry run complete. A real run would: record the VM's current commit for a rollback;"
  [ $backup = yes ] && echo "  back up the staging backend database (scripts/pre-deploy-backup.sh);"
  echo "  deploy ${DEPLOY_SHA:0:7} with scripts/remote-deploy.sh staging;"
  [ -n "$CHECK_SERVICE" ] && echo "  run scripts/health-check.sh staging $CHECK_SERVICE;"
  echo "  on a failure, redeploy the previous commit and ask for a revert PR."
  dl_summary
  exit 0
fi

dl_step "rollback point"
previous="$(dl_vm_commit)" || dl_die "could not read the VM's current commit"
[[ "$previous" =~ ^[0-9a-f]{40}$ ]] || dl_die "the VM's clone did not report a commit"
dl_ok "the VM runs ${previous:0:7}; deploying ${DEPLOY_SHA:0:7}"
if [ "$previous" = "$DEPLOY_SHA" ] && [ -n "$CHECK_SERVICE" ]; then
  dl_step "nothing changed: health check only"
  bash scripts/remote-deploy.sh --check staging "$CHECK_SERVICE"
  exit $?
fi

if [ $backup = yes ]; then
  dl_step "backend database backup"
  backend_tag="$(sed -n 's/\r$//; s/^BACKEND_IMAGE=.*:\(sha-[0-9a-f]\{7\}\)$/\1/p' env/staging.versions)"
  [[ "$backend_tag" =~ ^sha-[0-9a-f]{7}$ ]] || dl_die "BACKEND_IMAGE is not a sha-<7> tag; back up by hand (Runbook 9, section 6)"
  bash scripts/remote-deploy.sh --backup staging "backend-$backend_tag"
fi

dl_step "deploy ${DEPLOY_SHA:0:7}"
export DEPLOY_CHECK_SERVICE="$CHECK_SERVICE"
if bash scripts/remote-deploy.sh staging "$DL_RENDERED"; then
  echo
  echo "Staging: deployed ${DEPLOY_SHA:0:7}$([ -n "$CHECK_SERVICE" ] && echo ", $CHECK_SERVICE healthy")."
  dl_summary
  exit 0
fi

dl_step "FAILED: rolling the VM back to ${previous:0:7}"
export DEPLOY_SHA="$previous"
if bash scripts/remote-deploy.sh staging "$DL_RENDERED"; then
  echo "Rolled back to ${previous:0:7}. main still names the failed tags: open a revert PR of the bump now (Runbook 9, section 6)."
else
  echo "The rollback failed too: follow Runbook 9, section 6. The backup (if any) is in /srv/iltiam/backups/pre-deploy/."
fi
exit 1
