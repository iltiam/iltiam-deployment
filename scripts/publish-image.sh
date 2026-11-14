#!/usr/bin/env bash
# Build and publish one service's multi-arch image to GHCR from a laptop: the replacement for the publish jobs of
# iltiam-ai-service, iltiam-backend and iltiam-web's image workflows (kept, disabled). LOCAL_CI_MIGRATION.md.
# NOT YET VERIFIED: no image has been published with it yet.
#
#   scripts/publish-image.sh <ai|backend|web> <path to that repo's clone> [--dry-run] [--version X.Y.Z]
#
# Only a commit on that repo's origin/main, with no local change, whose last `scripts/ci-local.sh --full` passed on
# exactly that commit (.git/ci-local/last-full.env): the smoke tests the workflows ran before pushing are in --full.
# Tags: sha-<7> always; with --version X.Y.Z (the commit must carry tag vX.Y.Z and match VERSION / pyproject's
# version) also X.Y.Z and X.Y. Never latest. linux/amd64 + linux/arm64 in one push, then both are checked.
# Deploying it is a separate, reviewed step: scripts/deploy-staging.sh --bump <service> <sha>.
#
# GHCR: GHCR_USER + GHCR_TOKEN (write:packages), else the gh CLI's login and token. `docker login` lasts for this
# script only (logged out on exit). Needs Docker with buildx and arm64 emulation (Docker Desktop has both).
set -euo pipefail

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

[ $# -ge 2 ] || die "usage: $0 <ai|backend|web> <clone> [--dry-run] [--version X.Y.Z]"
service="$1"
src="$2"
shift 2
dry=no
version=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=yes ;;
    --version) version="${2:-}"; shift ;;
    *) die "unknown option $1" ;;
  esac
  shift
done
[ -d "$src/.git" ] || die "$src is not a git clone"
src="$(cd "$src" && pwd)"

case "$service" in
  ai) repo=iltiam-ai-service; context=.; builds="api:iltiam-ai-api worker:iltiam-ai-worker" ;;
  backend) repo=iltiam-backend; context=.; builds="runtime:iltiam-backend" ;;
  web) repo=iltiam-web; context=web; builds=":iltiam-web" ;;
  *) die "service must be ai, backend or web" ;;
esac

step "source: $repo"
cd "$src"
git remote get-url origin | grep -q "iltiam/$repo" || die "$src is not a clone of iltiam/$repo"
[ -z "$(git status --porcelain --untracked-files=no)" ] || die "uncommitted changes in $src"
git fetch -q origin main --tags
sha="$(git rev-parse HEAD)"
git merge-base --is-ancestor "$sha" origin/main || die "${sha:0:7} is not on origin/main: publish only reviewed, merged code"
state="$(git rev-parse --git-path ci-local)/last-full.env"
[ -f "$state" ] || die "no scripts/ci-local.sh --full result in this clone: run it on ${sha:0:7} first"
grep -qx "verdict=PASS" "$state" || die "the last --full did not pass"
grep -qx "head=$sha" "$state" || die "the last --full was not on ${sha:0:7}: run it again"
grep -qx "dirty=no" "$state" || die "the last --full ran with uncommitted changes"
echo "    ok: ${sha:0:7} on origin/main, --full PASS on it ($(sed -n 's/^date=//p' "$state"))"

tags="sha-${sha:0:7}"
if [ -n "$version" ]; then
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "--version must be X.Y.Z"
  [ "$(git rev-parse -q --verify "refs/tags/v$version^{commit}" || true)" = "$sha" ] || die "tag v$version is not on ${sha:0:7}"
  case "$service" in
    ai) declared="$(sed -n 's/^version *= *"\(.*\)"/\1/p' pyproject.toml | head -n1)" ;;
    backend) declared="$(tr -d '[:space:]' <VERSION)" ;;
    web) declared="$version" ;; # the web workflow published sha-<7> only for tags
  esac
  [ "$declared" = "$version" ] || die "v$version does not match the declared version $declared"
  [ "$service" = web ] || tags="$version ${version%.*} $tags"
fi
echo "    tags: $tags"

command -v docker >/dev/null || die "docker is not installed"
docker info >/dev/null 2>&1 || die "the Docker daemon is not running"
docker buildx version >/dev/null || die "docker buildx is missing"

if [ "$dry" = yes ]; then
  echo
  for b in $builds; do
    echo "Dry run: would build target '${b%%:*}' of $context as ghcr.io/iltiam/${b#*:} (linux/amd64, linux/arm64), push: $tags"
  done
  exit 0
fi

if [ -z "${GHCR_USER:-}" ] || [ -z "${GHCR_TOKEN:-}" ]; then
  GHCR_USER="$(gh api user --jq .login)"
  GHCR_TOKEN="$(gh auth token)"
  echo "    WARNING: using the gh CLI's token (needs write:packages: gh auth refresh -s write:packages)"
fi
trap 'docker logout ghcr.io >/dev/null 2>&1 || true' EXIT
printf '%s' "$GHCR_TOKEN" | docker login ghcr.io --username "$GHCR_USER" --password-stdin >/dev/null
echo "    logged in to ghcr.io (until this script ends)"

for b in $builds; do
  target="${b%%:*}"
  image="ghcr.io/iltiam/${b#*:}"
  step "build and push $image"
  # shellcheck disable=SC2054 # the comma is buildx's platform list, one argument
  args=(--platform linux/amd64,linux/arm64 --push --provenance=mode=max --sbom=true
    --label "org.opencontainers.image.source=https://github.com/iltiam/$repo"
    --label "org.opencontainers.image.revision=$sha" --label "org.opencontainers.image.version=${version:-sha-${sha:0:7}}")
  [ -n "$target" ] && args+=(--target "$target")
  for t in $tags; do args+=(-t "$image:$t"); done
  MSYS_NO_PATHCONV=1 docker buildx build "${args[@]}" "$context"
  for t in $tags; do
    platforms="$(docker buildx imagetools inspect "$image:$t" --format '{{json .Manifest}}' |
      jq -r '.manifests[].platform | "\(.os)/\(.architecture)"' | sort -u)"
    if ! grep -qx linux/amd64 <<<"$platforms" || ! grep -qx linux/arm64 <<<"$platforms"; then
      die "$image:$t lacks an architecture"
    fi
    echo "    ok: $image:$t (linux/amd64, linux/arm64)"
  done
done
echo
echo "Published. To deploy it on staging: scripts/deploy-staging.sh --bump $service $sha"
