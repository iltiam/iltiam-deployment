#!/usr/bin/env bash
# Merge a PR only when it is validated (AGENTS.md, rule 6). Same file in every ILTIAM repo.
#
#   scripts/merge-pr.sh <PR number> [--squash | --merge | --rebase]     (default --squash)
#
# Refuses unless: the PR is open, not a draft, targets main and is approved; the last `scripts/ci-local.sh --full`
# in this clone (.git/ci-local/last-full.env) passed, with no uncommitted changes, on exactly the PR's head commit;
# that head contains main; and the main it was tested against is main now. GitHub then merges only if the head is
# still that commit (--match-head-commit).
set -euo pipefail

die() { printf 'REFUSED: %s\n' "$*" >&2; exit 1; }

pr="${1:-}"
method="${2:---squash}"
[[ "$pr" =~ ^[0-9]+$ ]] || { echo "usage: $0 <PR number> [--squash|--merge|--rebase]" >&2; exit 2; }
case "$method" in --squash | --merge | --rebase) ;; *) echo "unknown merge method $method" >&2; exit 2 ;; esac
command -v gh >/dev/null || die "gh is not installed"
cd "$(git rev-parse --show-toplevel)"

state="$(git rev-parse --git-path ci-local)/last-full.env"
[ -f "$state" ] || die "no scripts/ci-local.sh --full result in this clone"
val() { sed -n "s/^$1=//p" "$state"; }

info="$(gh pr view "$pr" --json state,isDraft,baseRefName,headRefOid,reviewDecision,url)"
field() { printf '%s' "$info" | jq -r ".$1"; }
[ "$(field state)" = OPEN ] || die "PR #$pr is $(field state)"
[ "$(field isDraft)" = false ] || die "PR #$pr is a draft"
[ "$(field baseRefName)" = main ] || die "PR #$pr targets $(field baseRefName), not main"
[ "$(field reviewDecision)" = APPROVED ] || die "PR #$pr is not approved (reviewDecision: $(field reviewDecision))"

head="$(field headRefOid)"
main_now="$(gh api "repos/{owner}/{repo}/commits/main" --jq .sha)"
[ "$(val verdict)" = PASS ] || die "the last --full did not pass ($(val verdict))"
[ "$(val dirty)" = no ] || die "the last --full ran with uncommitted changes"
[ "$(val head)" = "$head" ] || die "the last --full tested $(val head | cut -c1-7), the PR head is ${head:0:7}: check out the PR head and run --full"
[ "$(val contains_main)" = yes ] || die "the tested commit does not contain main: merge main into the branch and run --full again"
[ "$(val main)" = "$main_now" ] || die "main moved (tested against $(val main | cut -c1-7), main is now ${main_now:0:7}): update the branch and run --full again"

echo "OK: --full PASS on ${head:0:7} against main ${main_now:0:7} ($(val date)). Merging $(field url) $method."
gh pr merge "$pr" "$method" --match-head-commit "$head"
