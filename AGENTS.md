# AGENTS.md: how changes are validated in iltiam-deployment

This applies to every contributor, human or AI agent (Claude Code, Cursor, Codex, ...). CI is local in every ILTIAM
repository: **`scripts/ci-local.sh` is the check that counts**, and nothing checks your work unless you run it. This
repository is public, so GitHub Actions is used here for free, and only for: `env-check` and `docs` (on PRs and
`main`, alongside the local checks) and `deploy` (started by hand, see "Deploying staging"). Background and setup:
`LOCAL_CI_MIGRATION.md` (section 0 is the setup in force).

## The commands

```bash
scripts/ci-local.sh --fast    # before every push and before opening a PR (pre-push hook runs it)
scripts/ci-local.sh --full    # on the exact merge result, right before merging
scripts/install-hooks.sh      # once per clone: the pre-push hook (scripts/install-hooks.sh --uninstall removes it)
```

This repository is public: checks and the deploy log print names only, never a value. PowerShell:
`.\scripts\ci-local.ps1 --fast`.

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

## Deploying staging

Deploys run only on GitHub Actions, through this repository's `deploy` workflow (`workflow_dispatch` only), started
by hand, with the secrets of the GitHub `staging` Environment. No laptop holds those secrets: `scripts/deploy-staging.sh`
and `scripts/deploy-prod.sh` are never run against a server. Commands, checks and rollback: `LOCAL_CI_MIGRATION.md`,
section 0.

1. **Publish the image** of a commit on the app repository's `main` whose `scripts/ci-local.sh --full` passed,
   dry-run first: `scripts/publish-image.sh <ai|backend|web> ../iltiam-<repo> [--dry-run]` (needs
   `gh auth refresh -s write:packages`).
2. **Bump PR**: on a branch, `scripts/set-version.sh staging <ai|backend|web> <40-character commit>`, commit,
   `scripts/ci-local.sh --full`, open the PR with the table (or `scripts/deploy-staging.sh --bump`, which does the
   same and never touches a server).
3. **Approve and merge**: a teammate approves the PR (`main` needs one approval), then it is merged.
4. **Run the deploy**: `gh workflow run deploy -R iltiam/iltiam-deployment --ref main -f environment=staging`.
5. **Approve the held run** on the Actions page: GitHub holds every run ("This workflow file may be malicious ...")
   until someone with write access reviews `deploy.yml` and approves it. Approve one run only, watch it with
   `gh run watch <run id> -R iltiam/iltiam-deployment --exit-status`, then check
   `https://staging-api.iltiamcare.com/api/ready/` and sign in on `https://staging-app.iltiamcare.com`.

Rollback: a revert PR of the bump commit, approved and merged, then steps 4 and 5 again. A backend deploy takes no
database backup by itself: take one by hand first when it migrates (`LOCAL_CI_MIGRATION.md`, section 0).

## For AI agents

- Run the commands above yourself; never claim a PASS you did not see in the summary table, and paste the table.
- Do not use `--no-verify`, do not edit `scripts/ci-local.sh` or `scripts/lib/ci-common.sh` to make a run pass, and
  do not merge PRs unless a person asked you to, and then only with `scripts/merge-pr.sh`.
- Deploys run only through the `deploy` workflow ("Deploying staging" above). Never publish an image, start a deploy
  run or approve a held run without a person's explicit request, and never touch production unless asked. Never run
  `scripts/deploy-staging.sh` or `scripts/deploy-prod.sh` against a server (no laptop holds the secrets); their
  `--dry-run --offline` is always safe, and so is `--bump --dry-run`.
- Never create `~/.iltiam/deploy/<env>/`: even an empty template there makes the `--full` deploy preflight fail.
