#!/usr/bin/env bash
# Copy the AI drift monitoring files from a commit of iltiam-ai-service (Runbook 7, section 17.4; issue #10).
#
# Usage, on a laptop:  scripts/sync-ai-monitoring.sh <path to a clone of iltiam-ai-service> <commit>
#   Take the commit of the AI image staging runs (env/staging.versions, or origin/auto/staging's), so the rules match
#   the metrics that image writes. Then: scripts/check-monitoring.sh (promtool tests), commit, PR.
#
# The files are copied as they are and never edited here; monitoring/AI_SOURCE records the commit.

set -euo pipefail

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 2 ]] || die "usage: $0 <iltiam-ai-service clone> <commit>"
ai="$1"
commit="$(git -C "$ai" rev-parse --verify "$2^{commit}")" || die "$2 is not a commit of $ai"
cd "$(dirname "$0")/.."

files="$(sed -n 's/^files=//p' monitoring/AI_SOURCE)"
[[ -n "$files" ]] || die "monitoring/AI_SOURCE lists no files"
for f in $files; do
  git -C "$ai" show "$commit:$f" >"$f.tmp" || { rm -f "$f.tmp"; die "$f is not in $commit"; }
  mv -f "$f.tmp" "$f"
  printf '    copied %s\n' "$f"
done
sed -i "s/^commit=.*/commit=$commit/" monitoring/AI_SOURCE
printf 'monitoring/AI_SOURCE: commit=%s. Now: bash scripts/check-monitoring.sh, then a PR.\n' "$commit"
