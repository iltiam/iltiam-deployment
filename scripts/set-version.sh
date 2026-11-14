#!/usr/bin/env bash
# Point one service of env/staging.versions at another build (Runbook 9, docs/runbooks/09-cd-staging.md, issue #16).
# Run on a laptop to prepare the reviewed PR that changes env/staging.versions (or by scripts/deploy-staging.sh --bump);
# the deploy workflow, run by hand, then deploys main. Never on the VM: the VM never edits its clone (Runbook 5, section 4.3).
#
# Usage: scripts/set-version.sh staging <ai|backend|web> <40-character commit hash of that repository's main>
#
#   ai       AI_API_IMAGE and AI_WORKER_IMAGE (one build: scripts/deploy.sh wants the same tag on both)
#   backend  BACKEND_IMAGE
#   web      WEB_IMAGE
#
# Only the tag changes, to sha-<7>; the image name must already be the expected one. The comment lines right above
# the service's first line are replaced by one line naming the commit. The other services' lines stay as they are.
# Staging only: production is released by hand (Runbook 10).
#
# Prints three NAME=value lines, which the workflow appends to $GITHUB_OUTPUT as they are:
#   previous=<the tag before>   tag=sha-<7>   changed=true|false
# With changed=false the file is left untouched.

set -euo pipefail

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 3 ]] || die "usage: $0 staging <ai|backend|web> <40-character commit hash>"
env_name="$1"
service="$2"
sha="$3"
[[ "$env_name" == staging ]] || die "only staging (production is released by hand), got '$env_name'"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "the commit must be a full 40-character hash"

case "$service" in
  ai)
    keys=(AI_API_IMAGE AI_WORKER_IMAGE)
    images=(ghcr.io/iltiam/iltiam-ai-api ghcr.io/iltiam/iltiam-ai-worker)
    source_repo=iltiam-ai-service
    ;;
  backend)
    keys=(BACKEND_IMAGE)
    images=(ghcr.io/iltiam/iltiam-backend)
    source_repo=iltiam-backend
    ;;
  web)
    keys=(WEB_IMAGE)
    images=(ghcr.io/iltiam/iltiam-web)
    source_repo=iltiam-web
    ;;
  *) die "service must be ai, backend or web, got '$service'" ;;
esac

repo="$(cd "$(dirname "$0")/.." && pwd)"
file="$repo/env/$env_name.versions"
[[ -f "$file" ]] || die "$file not found"
tag="sha-${sha:0:7}"

mapfile -t lines <"$file"
declare -a at=()
previous=""
unchanged=true
for i in "${!lines[@]}"; do
  line="${lines[$i]%$'\r'}"
  for k in "${!keys[@]}"; do
    [[ "$line" == "${keys[$k]}="* ]] || continue
    [[ -z "${at[$k]:-}" ]] || die "$file: ${keys[$k]} appears twice"
    value="${line#*=}"
    [[ "${value%:*}" == "${images[$k]}" ]] || die "$file: ${keys[$k]} names '${value%:*}', expected ${images[$k]}"
    at[k]=$i
    [[ -n "$previous" ]] || previous="${value##*:}"
    [[ "${value##*:}" == "$tag" ]] || unchanged=false
  done
done
for k in "${!keys[@]}"; do
  [[ -n "${at[$k]:-}" ]] || die "$file: ${keys[$k]} is missing"
done

if [[ "$unchanged" == true ]]; then
  printf 'previous=%s\ntag=%s\nchanged=false\n' "$previous" "$tag"
  exit 0
fi

# The comment block directly above the service's first line: from `first` up to that line.
first="${at[0]}"
while ((first > 0)) && [[ "${lines[$((first - 1))]}" == \#* ]]; do
  first=$((first - 1))
done

tmp="$(mktemp "$file.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
{
  for i in "${!lines[@]}"; do
    if ((i >= first && i < at[0])); then
      continue
    fi
    if ((i == at[0])); then
      printf '# %s: %s main, commit %s; set on %s for the deploy workflow (run by hand).\n' \
        "$tag" "$source_repo" "$sha" "$(date -u +%Y-%m-%d)"
    fi
    replaced=false
    for k in "${!keys[@]}"; do
      if ((i == at[k])); then
        printf '%s=%s:%s\n' "${keys[$k]}" "${images[$k]}" "$tag"
        replaced=true
      fi
    done
    [[ "$replaced" == true ]] || printf '%s\n' "${lines[$i]%$'\r'}"
  done
} >"$tmp"
chmod 644 "$tmp"
mv -f "$tmp" "$file"
trap - EXIT

printf 'previous=%s\ntag=%s\nchanged=true\n' "$previous" "$tag"
