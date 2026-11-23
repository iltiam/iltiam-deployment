#!/usr/bin/env bash
# Production releases on paper first (issue #19, docs/runbooks/10-production-release.md). Nothing here deploys,
# connects to the VM or pushes: it prepares the files a reviewed pull request changes. The deploy itself is the
# `deploy` workflow with environment production, which waits for the production Environment's reviewer.
#
#   scripts/release.sh promote <ai|backend|web|all>
#                                          copy what staging runs into env/production.versions: the tags on
#                                          origin/auto/staging while automatic deploys keep them there, else main's
#                                          env/staging.versions
#   scripts/release.sh prepare <X.Y.Z>     write releases/vX.Y.Z.md, the release manifest, from env/production.versions
#   scripts/release.sh check <X.Y.Z>       env/production.versions matches releases/vX.Y.Z.md exactly (before a deploy)
#   scripts/release.sh rollback [<X.Y.Z>]  put env/production.versions back to a released manifest (default: the one
#                                          before the newest), for a rollback pull request
#   scripts/release.sh list                the released manifests, newest first
#
# A manifest records each image's tag and whether staging ran the same tag when the release was prepared, and names
# the release it replaces (the rollback target). The git tag prod-vX.Y.Z is set by hand on main after the deploy
# succeeded (runbook, section 4).
set -euo pipefail
cd "$(dirname "$0")/.." || exit 2

VERSIONS=env/production.versions
STAGING=env/staging.versions
DIR=releases
IMAGES=(AI_API_IMAGE AI_WORKER_IMAGE BACKEND_IMAGE WEB_IMAGE)
STAGING_TMP=""

die() { printf 'release.sh: %s\n' "$*" >&2; exit 1; }
value() { sed -n "s/^$1=//p" "$2" | tr -d '\r' | tail -n 1; }
semver() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "a release is X.Y.Z (got '$1')"; }

cleanup() { [ -z "$STAGING_TMP" ] || rm -f "$STAGING_TMP"; }
trap cleanup EXIT

# What staging runs: origin/auto/staging's file while the automatic deploys keep it there (AGENTS.md), else main's.
# Sets STAGING_SRC to a file path.
load_staging() {
  [ -z "$STAGING_TMP" ] || return 0
  STAGING_TMP="$(mktemp)"
  git fetch -q origin auto/staging 2>/dev/null || true
  if git show "origin/auto/staging:$STAGING" >"$STAGING_TMP" 2>/dev/null; then
    echo "staging: origin/auto/staging" >&2
  else
    cp "$STAGING" "$STAGING_TMP"
    echo "staging: $STAGING" >&2
  fi
}

# set_line <name> <value>: replace that NAME= line of env/production.versions in place, keeping the comments.
set_line() {
  grep -q "^$1=" "$VERSIONS" || die "$1 is not in $VERSIONS"
  awk -v n="$1" -v l="$1=$2" 'BEGIN { FS = "=" } $1 == n { print l; next } { print }' "$VERSIONS" >"$VERSIONS.tmp"
  mv "$VERSIONS.tmp" "$VERSIONS"
}

# The manifests' versions, newest first.
releases() {
  [ -d "$DIR" ] || return 0
  local f
  for f in "$DIR"/v*.md; do
    [ -e "$f" ] || continue
    f="${f##*/v}"; echo "${f%.md}"
  done | sort -t. -k1,1nr -k2,2nr -k3,3nr
}

# The NAME=value lines of a manifest's fenced block.
manifest_values() {
  # shellcheck disable=SC2016  # the backticks are the markdown fence, not a command
  sed -n '/^```versions$/,/^```$/p' "$DIR/v$1.md" | sed '1d;$d'
}

cmd_promote() {
  local names=() name tag
  case "$1" in
    ai) names=(AI_API_IMAGE AI_WORKER_IMAGE) ;;
    backend) names=(BACKEND_IMAGE) ;;
    web) names=(WEB_IMAGE) ;;
    all) names=("${IMAGES[@]}") ;;
    *) die "promote takes ai, backend, web or all" ;;
  esac
  load_staging
  for name in "${names[@]}"; do
    tag="$(value "$name" "$STAGING_TMP")"
    [ -n "$tag" ] || die "$name is not in staging's versions"
    set_line "$name" "$tag"
    echo "  $name=${tag##*/}"
  done
  echo "Copied into $VERSIONS. COMPOSE_PROFILES is yours to set there (staging has '$(value COMPOSE_PROFILES "$STAGING_TMP")')."
}

cmd_prepare() {
  local version="$1" file newest profiles name tag staging_tag same
  semver "$version"
  file="$DIR/v$version.md"
  [ ! -e "$file" ] || die "$file exists: a release number is used once"
  newest="$(releases | head -n 1)"
  if [ -n "$newest" ]; then
    if [ "$newest" = "$version" ] \
      || [ "$(printf '%s\n%s\n' "$newest" "$version" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)" != "$version" ]; then
      die "v$version is not newer than the last release v$newest"
    fi
  fi
  bash scripts/deploy.sh --check-versions production >/dev/null || die "$VERSIONS does not pass scripts/deploy.sh --check-versions"
  load_staging
  profiles="$(value COMPOSE_PROFILES "$VERSIONS")"
  mkdir -p "$DIR"
  {
    echo "# Production release v$version"
    echo
    echo "- **Prepared:** $(date -u +%Y-%m-%d), from \`$VERSIONS\` on top of $(git rev-parse --short HEAD)."
    if [ -n "$newest" ]; then
      echo "- **Replaces:** v$newest, the rollback target (\`scripts/release.sh rollback $newest\`)."
    else
      echo "- **Replaces:** nothing (the first release)."
    fi
    echo "- **Profiles:** \`${profiles:-none (the AI service only)}\`."
    echo
    echo "| Image | Tag | Same tag on staging when prepared |"
    echo "|---|---|---|"
    for name in "${IMAGES[@]}"; do
      tag="$(value "$name" "$VERSIONS")"
      staging_tag="$(value "$name" "$STAGING_TMP")"
      if [ "$tag" = "$staging_tag" ]; then same=yes; else same="**no** (staging: \`${staging_tag##*/}\`)"; fi
      echo "| \`$name\` | \`${tag##*/}\` | $same |"
    done
    echo
    echo "The lines \`scripts/release.sh check $version\` compares with \`$VERSIONS\`:"
    echo
    echo '```versions'
    grep -E '^(COMPOSE_PROFILES|AI_API_IMAGE|AI_WORKER_IMAGE|BACKEND_IMAGE|WEB_IMAGE)=' "$VERSIONS" | tr -d '\r'
    echo '```'
    echo
    echo "## Release checklist (Runbook 10, section 3)"
    echo
    echo "- [ ] Every image's commit passed its repository's \`scripts/ci-local.sh --full\`"
    echo "- [ ] Every tag ran on staging for at least one day without a new error (the table above says yes)"
    echo "- [ ] \`scripts/security-scan.sh images\`: no CRITICAL with a fix"
    echo "- [ ] Database migrations in this release: none, or listed here with whether an older backend still works"
    echo "- [ ] A production database backup taken on the day (section 4, step 2): size ..."
    echo "- [ ] Outside clinic hours; the watcher for 30 minutes after: ..."
    echo "- [ ] Approved in the pull request by someone other than its author"
  } >"$file"
  echo "Wrote $file. Next: commit it with $VERSIONS on a branch and open the release PR (Runbook 10, section 4)."
}

cmd_check() {
  local version="$1" line name want have bad=0
  semver "$version"
  [ -f "$DIR/v$version.md" ] || die "no $DIR/v$version.md"
  while IFS= read -r line; do
    name="${line%%=*}"; want="${line#*=}"; have="$(value "$name" "$VERSIONS")"
    if [ "$want" = "$have" ]; then echo "  ok    $name"; else echo "  DIFF  $name: manifest '${want##*/}', $VERSIONS '${have##*/}'"; bad=1; fi
  done < <(manifest_values "$version")
  [ $bad = 0 ] || die "$VERSIONS does not match v$version"
  echo "$VERSIONS matches v$version."
}

cmd_rollback() {
  local target="${1:-}" line
  [ -n "$target" ] || target="$(releases | sed -n 2p)"
  [ -n "$target" ] || die "no earlier release to roll back to"
  semver "$target"
  [ -f "$DIR/v$target.md" ] || die "no $DIR/v$target.md"
  while IFS= read -r line; do
    set_line "${line%%=*}" "${line#*=}"
  done < <(manifest_values "$target")
  echo "$VERSIONS now matches v$target. Next: the rollback PR (Runbook 10, section 5)."
}

case "${1:-help}" in
  promote) [ $# -eq 2 ] || die "promote <ai|backend|web|all>"; cmd_promote "$2" ;;
  prepare) [ $# -eq 2 ] || die "prepare <X.Y.Z>"; cmd_prepare "$2" ;;
  check) [ $# -eq 2 ] || die "check <X.Y.Z>"; cmd_check "$2" ;;
  rollback) cmd_rollback "${2:-}" ;;
  list) releases | sed 's/^/v/' ;;
  help | -h | --help) awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0" ;;
  *) die "unknown command $1 (scripts/release.sh help)" ;;
esac
