# AGENTS.md: how changes are validated in iltiam-deployment

This applies to every contributor, human or AI agent (Claude Code, Cursor, Codex, ...). GitHub Actions is turned
off for this organisation: **local CI replaces it**, and nothing checks your work unless you run it. Background and
setup: `iltiam-deployment/LOCAL_CI_MIGRATION.md`.

## The commands

```bash
scripts/ci-local.sh --fast    # before every push and before opening a PR (pre-push hook runs it)
scripts/ci-local.sh --full    # on the exact merge result, right before merging
scripts/install-hooks.sh      # once per clone: the pre-push hook (scripts/install-hooks.sh --uninstall removes it)
```

Deployment: this repository is public; checks print names only. Deploys are manual and never automatic:
`scripts/deploy-staging.sh`, `scripts/deploy-prod.sh` and `scripts/publish-image.sh`, each with `--dry-run`.
PowerShell: `.\scripts\ci-local.ps1 --fast`.

Each run ends with a table: every check is PASS, FAIL, BLOCKED (required but could not run here) or
SKIPPED-OPTIONAL. The script exits non-zero when any **required** check is FAIL or BLOCKED.

## Policy

1. Run `scripts/ci-local.sh --fast` before every push and before opening a PR.
2. Right before merging: update the branch with the latest `main` (merge or rebase, then push), and run
   `scripts/ci-local.sh --full` on that exact commit. If `main` moved since your last `--full`, run it again: an
   older PASS does not count.
3. A failure is fixed, then the run is repeated. Never skip, weaken, delete or mark-as-expected a test, assertion or
   check to get a PASS, and never commit the files a check rewrote without reading the diff.
4. Paste into the PR (the template has the section): the tested commit SHA, the `main` SHA it was tested against,
   OS and tool versions, the commands, and the summary table, exactly as printed.
5. A required check that cannot run on your machine is BLOCKED. The PR is not validated until someone runs it where
   it can (the table says why it was blocked and what it needs).
6. Never merge a PR that is not validated. `scripts/merge-pr.sh <PR>` merges only when the last `--full` passed on
   the PR's current head and that head contains the current `main`.

## What this does not give you

The pre-push hook is local and can be bypassed (`git push --no-verify`); it is a safety net, not enforcement. A
local run uses your machine's tools and state, not a clean runner: the pinned versions are checked, but anything
else on your machine can still differ. Reviewers: check that the pasted SHAs match the PR head and `main`.

## For AI agents

- Run the commands above yourself; never claim a PASS you did not see in the summary table, and paste the table.
- Do not use `--no-verify`, do not edit `scripts/ci-local.sh` or `scripts/lib/ci-common.sh` to make a run pass, and
  do not merge PRs unless a person asked you to, and then only with `scripts/merge-pr.sh`.
- Deployments are manual (`iltiam-deployment/scripts/deploy-staging.sh`, `deploy-prod.sh`): never run one without
  a person's explicit request; `--dry-run` is always safe.
