# Local CI migration: GitHub Actions → `scripts/ci-local.sh`

- **Date:** 2026-11-13. **Why:** the organisation's free Actions minutes are used up and the Actions budget is $0, so
  every run is blocked until the monthly reset. **Goal:** zero GitHub-hosted runner usage for normal development.
  This is **not** zero infrastructure cost: OCI, Cloudflare and GHCR are unchanged, and the checks now run on our
  own laptops (time, electricity, disk).
- **Owner:** the organisation owner. **Applies to:** `iltiam-ai-service`, `iltiam-backend`, `iltiam-web`,
  `iltiam-mobile`, `iltiam-deployment`.
- **This repository is public.** Nothing in this document is a secret: no token, IP address or key.

## 0. Final setup (owner's decision, 2026-11-14)

- **CI is local in all five repositories** (`scripts/ci-local.sh`, sections 6 and 7). Their CI workflows stay
  disabled.
- **Deploys run only on GitHub Actions, in this repository**: it is public, so its minutes are free. The `deploy`
  workflow has one trigger, `workflow_dispatch` (iltiam-deployment#71): a person starts it, never a push, a merge or
  another repository. It uses the secrets and variables already in the GitHub `staging` / `production`
  Environments, and both Environments deploy from `main` only.
- **No laptop holds a copy of the deploy secrets.** `scripts/deploy-staging.sh` and `scripts/deploy-prod.sh` are
  never run against a server: only their `--dry-run --offline` preflight, which `ci-local.sh --full` runs, and
  `deploy-staging.sh --bump`, which only opens a PR. Don't create `~/.iltiam/deploy/<env>/`: an empty template there
  makes the `--full` preflight fail.
- **Images are published from a laptop** with `scripts/publish-image.sh` (needs a `gh` login with `write:packages`:
  `gh auth refresh -s write:packages`).
- **Also on Actions here (free):** `env-check` (every PR and push to `main`) and `docs` (docs paths). Re-enabled on
  2026-11-14; they run alongside, not instead of, `ci-local.sh`.
- **Verified end to end on 2026-11-14:** web `sha-aa7deb6` published, bumped (#71), deployed by run 43574332851
  (only the web container recreated, healthy), login and the demo flow checked on staging.

### How to deploy staging

```bash
# 0. The change is merged in its app repository after scripts/ci-local.sh --full PASS on that exact commit.
#    scripts/merge-pr.sh squashes: main gets a new commit, so run --full again on it (a fast-forward keeps the tested one).

# 1. Publish the image, from the app's clone checked out at that commit of main (dry-run first)
iltiam-deployment/scripts/publish-image.sh <ai|backend|web> ../iltiam-<repo> --dry-run
iltiam-deployment/scripts/publish-image.sh <ai|backend|web> ../iltiam-<repo>
#    prints: ok: ghcr.io/iltiam/<image>:sha-<7> (linux/amd64, linux/arm64)

# 2. The bump PR, in iltiam-deployment
git switch -c chore/staging-<service>-sha-<7> origin/main
scripts/set-version.sh staging <ai|backend|web> <40-character commit>
git commit -am "chore(staging): deploy <service> sha-<7>"
scripts/ci-local.sh --full                      # paste the table into the PR
git push -u origin HEAD && gh pr create --fill
#    (scripts/deploy-staging.sh --bump <service> <commit> [--dry-run] does the same and opens the PR; no server)

# 3. A teammate approves the PR (main needs 1 approval); merge it.

# 4. Start the deploy
gh workflow run deploy -R iltiam/iltiam-deployment --ref main -f environment=staging

# 5. Approve the held run: GitHub stops each run with "This workflow file may be malicious. It will not run until
#    someone with write access approves it." Open the run on the Actions page, review deploy.yml, Approve.
#    Approve one run only (two would deploy twice); then watch it to the end:
gh run list -R iltiam/iltiam-deployment --workflow deploy --limit 3
gh run watch <run id> -R iltiam/iltiam-deployment --exit-status

# 6. Check
curl -s https://staging-api.iltiamcare.com/api/ready/             # "ready", db/redis/storage/ai all "ok"
curl -s -o /dev/null -w '%{http_code}\n' https://staging-app.iltiamcare.com/healthz    # 200
#    then sign in and walk the demo flow
```

**Rollback:** a revert PR of the bump commit (approved, merged), then steps 4 and 5 again. Allow time for the
approval: `main` is the only branch staging deploys from.

**Backend deploys take no database backup any more** (only the retired automatic job did, Runbook 9). Migrations
never roll back by themselves (Runbook 9, section 6): before a backend deploy that migrates, take a backup by hand
on the VM. An optional backup step in `deploy.yml` is an open follow-up.

**Production:** the same steps with `env/production.versions` and `-f environment=production`; its Environment also
waits for its required reviewer. Not used yet (#36).

## 1. Status

| Repository | Status | Local CI | GitHub workflows | PR | What is left |
|---|---|---|---|---|---|
| iltiam-mobile | **MIGRATED** | `--fast` PASS (684 s); `--full` PASS incl. the staging debug APK (`e8ad090`); failure proof done | all disabled | iltiam-mobile#78 (merged) | iOS (optional, never in CI) not built: needs macOS |
| iltiam-backend | **MIGRATED** | `--fast` PASS; `--full --image` PASS (`2dab0e7`), image smoke on amd64 (160 s) and arm64 under QEMU (823 s); failure proof done | all disabled | iltiam-backend#131 (merged) | no backend image published through `publish-image.sh` yet |
| iltiam-ai-service | **PARTIAL** | `--fast` PASS; `--full --image` PASS (`1fec8ce`), image smoke with the real weights on amd64 (706 s) and arm64 under QEMU (975 s); failure proof done | all disabled except GitHub's managed "Dependency Graph" (API refuses: 422) | iltiam-ai-service#166 (merged) | the real-weights regression was not run here because it downloads the private wound-image fixtures: `--full --regression` |
| iltiam-web | **MIGRATED** | `--full` PASS on Node 22 (`aa7deb6`, 2026-11-14), all 20 required checks. On Windows the Lighthouse checks run in the Playwright Linux image (iltiam-web#73): headless Chrome on Windows captured blank filmstrip frames (performance 0.89, speed index 11.2 s); Linux Chromium gives 1.00 | all disabled | iltiam-web#71, #73 (merged) | none |
| iltiam-deployment | **MIGRATED** | `--fast` and `--full` PASS; failure proof done. Image publish and a staging deploy verified on 2026-11-14 (section 0) | `deploy` (by hand only), `env-check`, `docs` **active**; nothing automatic | iltiam-deployment#70, #71 (merged) | optional backup step for backend deploys (section 0) |

All five migration PRs are merged (2026-11-14). Section 0 is the setup in force; sections 8, 9 and 11 keep the
history of how it got there.

## 2. Branch protection (Step 0)

Checked with `gh api repos/iltiam/<repo>/branches/main/protection` and `.../rulesets` on 2026-11-13:

| Repository | Visibility | Protection on `main` before | Required status checks | After |
|---|---|---|---|---|
| iltiam-ai-service | private | not available: `403 Upgrade to GitHub Pro or make this repository public` | none possible | unchanged (GitHub Free) |
| iltiam-backend | private | not available (403, same) | none possible | unchanged |
| iltiam-web | private | not available (403, same) | none possible | unchanged |
| iltiam-mobile | private | not available (403, same) | none possible | unchanged |
| iltiam-deployment | public | `404 Branch not protected`, no rulesets | none | PR required, 1 approval, no status checks, admins included, no force push, no deletion |
| organisation rulesets | | `403 Upgrade to GitHub Team` | | unchanged |

So no required status check ever blocked a merge, and nothing on GitHub enforces reviews in the four private repos:
there the policy in each `AGENTS.md` and `scripts/merge-pr.sh` is all there is. Verification after the change:

```
$ gh api repos/iltiam/iltiam-deployment/branches/main/protection --jq '{checks: .required_status_checks, admins: .enforce_admins.enabled, approvals: .required_pull_request_reviews.required_approving_review_count, force_push: .allow_force_pushes.enabled, deletions: .allow_deletions.enabled}'
{"admins":true,"approvals":1,"checks":null,"deletions":false,"force_push":false}
```

Consequence: nobody (admins included) pushes to `iltiam-deployment` `main` directly any more, so the old automatic
`chore(staging): deploy … (auto)` commits become a reviewed PR (`scripts/deploy-staging.sh --bump`, section 7).

## 3. Before → after: every workflow (Step 1)

"Required" = it ran in the old GitHub CI on pull requests or pushes, so the local script must run it too (BLOCKED
when it cannot). "Optional" = new, or platform specific, or it never ran on a PR.

### iltiam-mobile

| Workflow / job (trigger) | What it did | Needs | Local replacement | Level |
|---|---|---|---|---|
| `CI` / Analyze and test (pull_request) | Flutter 3.41.6: pub get, `dart format --set-exit-if-changed lib test tool`, gen-l10n, build_runner, `tool/gen_api.dart --check`, `tool/check_issues.dart`, analyze, `flutter test --coverage` | Linux runner; no secrets | `ci-local.sh --fast` (same commands, same order) | required |
| `CI` / Build debug APK (workflow_dispatch only, since 461fbed) | JDK 17, NDK 28.2.13676358, Firebase config from `GOOGLE_SERVICES_JSON_*` secrets, `flutter build apk --debug --flavor <f>` | Android SDK, secrets (optional: builds without push) | `ci-local.sh --full` (staging; `--flavors "dev staging prod"`) | required in `--full` |
| iOS build | never in CI | macOS + Xcode | `ci-local.sh --full --ios` | optional (BLOCKED off macOS) |

Differences: `gen-l10n` rewrites the committed `lib/l10n/app_localizations*.dart`; CI ignored that, the local
"no files changed" guard fails it (stricter). The Firebase files are read from `android/app/src/<flavor>/` if you
have them (gitignored), never from secrets. CI used JDK 17; any JDK Gradle accepts works locally (recorded).

### iltiam-web

| Workflow / job (trigger) | What it did | Needs | Local replacement | Level |
|---|---|---|---|---|
| `web-ci` / check (push main, PR on `web/**`) | Node 22, `npm ci`, lint, format:check, i18n:check, typecheck, `check:api` (only with the `BACKEND_READ_TOKEN` secret, else skipped), Vitest, build, API build without mocks, bundle budget | Linux; optional secret | `--fast`: up to Vitest; `--full`: the builds and budget | required |
| `web-ci` / smoke | Playwright Chromium: `test:e2e`, `test:e2e:live` | browser | `--full` | required |
| `web-ci` / lighthouse | `lhci` (accessibility ≥ 0.9), build, `lhci:perf` | Chrome | `--full` (on Windows inside `mcr.microsoft.com/playwright:v<installed Playwright>-noble`, iltiam-web#73) | required |
| `web-image` (PR on `web/**`; after web-ci on main; tags; dispatch) | build linux/amd64 + linux/arm64, `docker/smoke.sh`, browser CSP test; on main: publish `sha-<7>` to GHCR, then `repository_dispatch` deploy-staging | Docker, native arm64 runner, `GITHUB_TOKEN` (packages), `DEPLOY_DISPATCH_TOKEN` | `--full`: both smokes + browser; publish: `iltiam-deployment/scripts/publish-image.sh web`; deploy: bump PR, then the `deploy` workflow by hand (section 0) | smoke required; publish/deploy manual |

Differences: `check:api` now always runs: `scripts/gen-api.mjs` reads the pinned contract from the sibling
`iltiam-backend` clone or through `gh` (BLOCKED without either), where CI skipped it without the secret. arm64 runs
under QEMU on an x86 laptop, not a native runner. Node: `.nvmrc` = 22; another major prints a WARNING and still runs
(owner's decision), recorded in the summary.

### iltiam-backend

| Workflow / job (trigger) | What it did | Needs | Local replacement | Level |
|---|---|---|---|---|
| `CI` / dependency-audit (every push, every PR) | Python 3.13, `pip-audit>=2.10,<3 --strict --desc on -r requirements.txt` | network | `--full` (via `uv tool run`) | required |
| `CI` / test | PostgreSQL 16 + Redis 7 services, `makemigrations --check --dry-run`, `migrate`, `spectacular --validate --fail-on-warn` + `git diff --exit-code docs/api/openapi.json`, `pytest --cov` (gate `fail_under` in `.coveragerc`) | Docker services | `--fast`: migrations check, contract (to a temp file, then diffed: nothing rewritten), pytest on SQLite; `--full`: Postgres + Redis in Docker, migrate, coverage-gated pytest | required |
| `API contract` / oasdiff (PR) | `tufin/oasdiff:v1.33.0 breaking` vs the base branch, waived by the `breaking-api` label | Docker | `--full` vs `origin/main`; waived by the PR label (read with `gh`) or `--breaking-api` | required |
| `image` (PR on build paths; after CI on main; tags; dispatch) | build amd64 + arm64, compose smoke (migrate, web/worker/beat healthy, `/api/health/`, `/api/ready/` failing only `ai`), publish, dispatch deploy | Docker, arm64 runner, tokens | `--full` when build paths changed (`--image` forces); publish: `publish-image.sh backend` | smoke required when paths changed |
| `API release` (tag `api-v*`) | `gh release create` with `docs/api/openapi.json` | `GITHUB_TOKEN` contents:write | by hand (section 6) | release-time, not CI |

### iltiam-ai-service

| Workflow / job (trigger) | What it did | Needs | Local replacement | Level |
|---|---|---|---|---|
| `ci` (PR, push main) | Python 3.11, CPU torch, `pip install -e .[service,dev]`, Django-free grep, `ruff check`, `ruff format --check`, `export_openapi.py --check`, `pytest -q -m "not regression"` | Linux | `--fast` (same; `--install` does the pip step) | required |
| `docs` (PR, push main) | `mkdocs build --strict` | | `--full` | required |
| `contract-label` (PR) | contract files changed ⇒ PR has the `contract` label | PR API | `--full` (reads labels with `gh`; BLOCKED before the PR exists) | required |
| `real-weights regression` (push main on paths; weekly cron; dispatch) | download weights + private fixture ZIP from releases, `pytest tests/regression -m regression`, zero skips | `GITHUB_TOKEN`, ~1 GB, CPU | `--full` when its paths changed (`--regression` forces) | required when paths changed |
| `image` (PR on build paths; after ci on main; tags; dispatch) | api + worker images, amd64 + arm64, compose smoke with real weights, `smoke_demo.py`, publish, dispatch deploy | Docker, arm64, token | `--full` when build paths changed (`--image` forces); publish: `publish-image.sh ai` | smoke required when paths changed |
| `contract-release` (tag `contract-v*`) | bundle + `gh release create` | contents:write | by hand (section 6) | release-time |
| `Dependency Graph` (GitHub-managed dynamic workflow) | dependency submission | Actions minutes | none needed | n/a (see section 9) |

Differences: the weekly regression no longer runs by itself: nothing runs on a schedule now (gap, section 10).

### iltiam-deployment

| Workflow / job (trigger) | What it did | Needs | Local replacement | Level |
|---|---|---|---|---|
| `env-check` / templates (PR, push main) | shellcheck (Ubuntu 24.04's, 0.9.0), `check-env.sh`, `check-compose.sh` | jq, openssl, Compose plugin | `--fast` (shellcheck natively at 0.9.0 or `koalaman/shellcheck:v0.9.0`); **also active on GitHub again since 2026-11-14** | required |
| `env-check` / gitleaks | `ghcr.io/gitleaks/gitleaks:v8.30.1 git --redact` on the full history | Docker | `--fast` (native 8.30.1 or the image); **also active on GitHub again** | required |
| `docs` (PR, push main on docs paths) | Python 3.12, `mkdocs build --strict` | | `--full` (checks installed versions = `docs/requirements.txt`); **also active on GitHub again** | required |
| `deploy` / manual (workflow_dispatch) | versions check, render env files from the Environment's secrets, SSH key, `remote-deploy.sh` | Environment secrets | **kept on GitHub, the only way to deploy** (section 0); the laptop scripts are dry-run only | manual |
| `deploy` / auto (repository_dispatch, `AUTO_DEPLOY`) | image check, `set-version.sh`, backend backup, commit to main, deploy, health check, revert + redeploy on failure | secrets, contents:write | **removed** (iltiam-deployment#71): a bump PR, then the manual `deploy` run; no automatic backup or rollback | manual |

The new local check also shellchecks `scripts/lib/*.sh` (new files) and adds a deploy dry-run in `--full`.

## 4. Files created or changed

Same in every repository (keep the copies identical; `CI_COMMON_VERSION` in the header):

| File | Purpose |
|---|---|
| `scripts/ci-local.sh` | `--fast` / `--full`, repo-specific checks |
| `scripts/lib/ci-common.sh` | the summary table, PASS/FAIL/BLOCKED/SKIPPED-OPTIONAL, exit code, the line-ending check, the "no files changed by the run" guard, the `--full` record in `.git/ci-local/last-full.env` |
| `scripts/ci-local.ps1` | PowerShell wrapper (finds Git Bash, never WSL's bash) |
| `scripts/install-hooks.sh` | pre-push hook, `--uninstall` |
| `scripts/merge-pr.sh` | merges only a validated PR |
| `AGENTS.md` | the policy (humans and agents) |
| `CLAUDE.md` | points to AGENTS.md (`@AGENTS.md`); appended to the existing file in ai-service and backend (`claude.md`) |
| `.github/pull_request_template.md` | "Local CI results" section (ai-service: added to its existing template) |

Per repository: mobile `.gitattributes` (new: `*.sh text eol=lf`); web `.nvmrc`, `web/.nvmrc` (22) and
`.gitattributes` (`web/** text=auto eol=lf`); deployment `scripts/deploy-staging.sh`, `scripts/deploy-prod.sh`,
`scripts/publish-image.sh`, `scripts/lib/deploy-local.sh`, this file, and `scripts/remote-deploy.sh`
(`DEPLOY_SSH_KEY_FILE` / `DEPLOY_KNOWN_HOSTS_FILE`, defaults unchanged). No workflow file was deleted or edited
by the migration itself. Later, on 2026-11-14: `deploy.yml` lost its `repository_dispatch` trigger and its `auto`
job (iltiam-deployment#71), and web's `scripts/ci-local.sh` runs Lighthouse in Docker on Windows (iltiam-web#73).

## 5. Setup per OS

Everything is bash. Clone the five repositories side by side (web's `check:api` reads `../iltiam-backend`).

**Windows 11 (Git Bash, the reference machine).** Git for Windows (Git Bash), Docker Desktop (WSL2 engine; start
it before `--full`), `gh` signed in, `jq` on the PATH. Line endings: Git for Windows defaults to
`core.autocrlf=true`; each repo's `.gitattributes` keeps the files the checks compare as LF, and the first check
(`checkout line endings`) tells you if your clone predates a rule and how to refresh it:
`git rm -r -q --cached <path> && git checkout HEAD -- <path>` (only for files without local edits). Run the
scripts from Git Bash, or `.\scripts\ci-local.ps1 --fast` in PowerShell. WSL2 Ubuntu also works (as Linux below)
on a clone inside the WSL filesystem; don't share one clone between Windows and WSL.

**Linux / WSL2.** Docker Engine with the Compose and buildx plugins, and `binfmt` (QEMU) for arm64 smokes:
`docker run --privileged --rm tonistiigi/binfmt --install arm64` once. Playwright: `npx playwright install-deps chromium` once (root).

**macOS.** Docker Desktop (arm64 Macs build arm64 natively and emulate amd64), Xcode for `--ios`.

**Toolchains (pinned = what the old workflows used):** Flutter 3.41.6 (checked, FAIL if different); Node 22
(`.nvmrc`; WARNING if different); Python 3.13 for backend (`uv venv --python 3.13 venv`), 3.11 for ai-service,
3.12 for deployment docs; ruff 0.16.x; shellcheck 0.9.0 and gitleaks 8.30.1 (native or Docker image);
oasdiff 1.33.0, PostgreSQL 16, Redis 7 (Docker images); `pip-audit>=2.10,<3` (through `uv`).

## 6. Commands per repository

```bash
scripts/install-hooks.sh                # once per clone; --uninstall removes it
scripts/ci-local.sh --fast              # before every push (the hook runs it)
scripts/ci-local.sh --full              # on the merge result, before merging
scripts/merge-pr.sh <PR>                # merges only if the last --full matches the PR head and current main
```

Extras: mobile `--full --flavors "dev staging prod"`, `--full --ios`; backend `--full --image`,
`--full --breaking-api`; ai-service `--install`, `--full --regression`, `--full --image`.

Release tags (were workflows, now by hand, after `--full` passed on that commit on main):

```bash
# backend: api-vX.Y.Z = info.version of docs/api/openapi.json
gh release create api-vX.Y.Z "docs/api/openapi.json#openapi.json" --title "API contract api-vX.Y.Z" --verify-tag
# ai-service: contract-vX.Y.Z (docs/contract-release.md)
python scripts/contract_release.py notes contract-vX.Y.Z > notes.md
python scripts/contract_release.py bundle contract-vX.Y.Z --commit "$(git rev-parse HEAD)" --out dist/contract
gh release create contract-vX.Y.Z dist/contract/* --verify-tag --latest=false --title "Contract contract-vX.Y.Z" --notes-file notes.md
```

## 7. The flow (humans and agents)

```
code ─▶ scripts/ci-local.sh --fast ─▶ git push (hook runs --fast again) ─▶ open PR (template: Local CI results)
     ─▶ review + approval ─▶ update the branch with the latest main, push ─▶ scripts/ci-local.sh --full on that head
     ─▶ paste the table ─▶ main moved? run --full again ─▶ scripts/merge-pr.sh <PR>
```

Rules (AGENTS.md): never skip or weaken a check; a required BLOCKED means not validated; never merge an
unvalidated PR; agents paste the table they actually saw and never use `--no-verify`.

## 8. Manual deployment (Step 5)

> **Superseded on 2026-11-14 by section 0.** Deploys run only through the `deploy` workflow on GitHub Actions; no
> laptop holds the secrets, so the laptop deploy commands below are **dry-run only** (`--dry-run --offline`, and
> `--bump`, which only opens a PR). `publish-image.sh` is still how images are published, and it is verified
> (`iltiam-web:sha-aa7deb6`). The rest of this section is kept as the record of the dry-runs of 2026-11-13.

Nothing deploys after a push or a merge any more. **None of this has run against a real server: deploy and image
publishing are NOT YET VERIFIED.** Only the dry-runs below were run.

```bash
# 1. publish an image of a merged commit whose --full passed (in that repo's clone)
iltiam-deployment/scripts/publish-image.sh <ai|backend|web> ../iltiam-<repo> [--version X.Y.Z] [--dry-run]
# 2. point staging at it: opens a PR to env/staging.versions (main is protected)
scripts/deploy-staging.sh --bump <ai|backend|web> <40-char sha> [--dry-run]
# 3. after the PR is merged, from an up-to-date main:
scripts/deploy-staging.sh --check <ai|backend|web> [--dry-run [--offline] [--ssh-check]]
#    backend: pg_dump first; then remote-deploy.sh; then health-check.sh; on failure the VM goes back to the commit it ran
# 4. production (tags changed through a reviewed PR to env/production.versions):
scripts/deploy-prod.sh --dry-run            # then without --dry-run: type "deploy production <sha7>"
```

Secrets are read only from the environment (`SECRETS_JSON`, `VARS_JSON`, `GHCR_USER`, `GHCR_TOKEN`,
`DEPLOY_SSH_KEY_FILE`, `DEPLOY_KNOWN_HOSTS_FILE`) or from `~/.iltiam/deploy/<env>/` (outside every repository):
`secrets.json`, `vars.json` (the same names as the GitHub Environment), `ssh_key`, `known_hosts`. The env files are
rendered into a private temporary directory and deleted on exit; nothing prints a value.

Dry-runs actually run on 2026-11-13 (no SSH, no server touched):

| Command | Result |
|---|---|
| `scripts/deploy-staging.sh --dry-run --offline` | exit 0; versions file OK; warns that no staging secrets are here (rendering, DEPLOY_HOST and SSH files not checked) |
| `scripts/deploy-prod.sh --dry-run --offline` | exit 0; the same for production |
| `scripts/deploy-staging.sh --dry-run` | exit 0; GHCR check (read-only registry API): `iltiam-ai-api` / `iltiam-ai-worker:sha-9ecf382`, `iltiam-backend:sha-14223c2`, `iltiam-web:sha-dce95f2` published with linux/arm64 |
| `scripts/deploy-prod.sh --dry-run` | exit 0; `iltiam-ai-api` / `iltiam-ai-worker:sha-0d1861e` published with linux/arm64 (backend and web profiles are off) |
| `scripts/deploy-staging.sh --bump web <40 zeros> --dry-run --offline` | exit 0; prints the `env/staging.versions` diff it would put in a PR; nothing changed |
| `scripts/publish-image.sh web ../iltiam-web --dry-run` | exit 1, correctly: refuses a clone with uncommitted changes |
| `scripts/ci-local.sh --full` (deployment) | runs both deploy dry-runs offline as its last check: PASS |

The `set-version.sh` comment line said "deployed automatically"; since 2026-11-14 it says "set on <date> for the deploy
workflow (run by hand)", as every change is now a reviewed PR.

~~What the owner must provide to verify deploys from a laptop~~: no longer applies. The owner chose not to keep
secret copies on laptops (section 0); the GitHub Environments stay the only place the deploy secrets live.

## 9. Workflows disabled (Step 6)

The owner approved the list on 2026-11-13. Already disabled before: deployment `deploy` / `docs` / `env-check` and
web `web-image`. Mobile `CI` was found still **active** and disabled after approval. Then
`gh workflow disable <id> -R iltiam/<repo>` for the rest. Proof (`gh workflow list --all -R iltiam/<repo>`):

```
== iltiam-ai-service
ci	disabled_manually	359868858
contract-label	disabled_manually	395146700
contract-release	disabled_manually	395149449
docs	disabled_manually	392893901
image	disabled_manually	395201006
real-weights regression	disabled_manually	393031640
Dependency Graph	active	389710907
== iltiam-backend
API contract	disabled_manually	395060407
API release	disabled_manually	395069082
CI	disabled_manually	363415475
image	disabled_manually	402760740
== iltiam-deployment
deploy	disabled_manually	400933013
docs	disabled_manually	413584517
env-check	disabled_manually	398644478
== iltiam-mobile
CI	disabled_manually	379615902
== iltiam-web
web-ci	disabled_manually	376177358
web-image	disabled_manually	410285796
```

- `Dependency Graph` (ai-service) is GitHub's managed dependency-submission workflow. `gh workflow disable` answers
  `HTTP 422: Unable to disable this workflow`. It is turned off in the repository settings (Settings → Code security
  → Dependency graph / Automatic dependency submission); left to the owner.
- After disabling, the five `ci/local-ci` branches were pushed, and no workflow run started on any of them.
- No required status check exists anywhere (section 2), so nothing can stay pending. Nothing deploys by itself:
  `deploy` (with its `repository_dispatch`) and every image workflow (the only senders of `deploy-staging`) are
  disabled.
- **Changed on 2026-11-14 (section 0):** in iltiam-deployment, `env-check` and `docs` are active again, and `deploy`
  is active with `workflow_dispatch` as its only trigger. The app repositories' workflows stay disabled.

## 10. Gaps compared with GitHub-hosted CI

- **Trust:** a PASS is a claim pasted by the author; nobody re-runs it independently. Reviewers must check the SHAs.
- **Clean environment:** local runs reuse caches, global tools, `node_modules`, venvs and Docker layers; a clean
  runner would catch a missing dependency that a laptop already has. `--full` uses `npm ci` (web); the backend venv
  is synced, not recreated; ai-service needs `--install` to resync.
- **Bypassable:** hooks are local and `--no-verify` skips them; four private repos have no branch protection
  (GitHub Free), so even reviews are policy, not enforcement.
- **`main` drift:** two PRs validated against the same `main` can each pass and break together; `merge-pr.sh`
  refuses a stale result, but only when it is used.
- **Nothing scheduled:** the weekly real-weights regression and post-merge `main` runs no longer happen by
  themselves.
- **Platform:** arm64 image smokes run under QEMU on x86 laptops (slower, not identical to the native arm64
  runner). iOS was never built in CI and is optional.
- **Toolchain drift:** pins are checked where CI pinned them (Flutter exact, Node major warns, Python major.minor,
  ruff series, shellcheck, gitleaks, images); OS, JDK and system libraries are recorded, not enforced.

## 11. Re-enabling GitHub Actions later

The workflow files were not deleted or edited. When the budget allows:

```bash
gh workflow enable <name> -R iltiam/<repo>        # for each workflow in section 9
```

Then decide whether to add required status checks (needs GitHub Team/Pro for the private repos). Keep
`ci-local.sh`: it still gives the same checks before a push. Automatic staging deploys can't simply be switched back
on: the `auto` job was removed from `deploy.yml` (iltiam-deployment#71), and `main` requires a PR, so a new design
would have to open a PR instead of pushing to `main`. The image workflows' dispatch steps would also need the
`DEPLOY_DISPATCH_TOKEN` secrets again.

## 12. Results on the reference machine

Windows 11 (Git Bash, MINGW64), Docker Desktop 29.8.0, 12 CPUs. Every row comes from a command that was run; the
full tables are in each PR.

| Repository | Command | Commit | Verdict | Time |
|---|---|---|---|---|
| mobile | `--fast` | 461fbed + new files | PASS (10/10) | 684 s |
| mobile | `--full` | `e8ad090` | PASS (12 required; iOS SKIPPED-OPTIONAL) | about 9 min |
| web | `--fast` | b3686a4 + new files | FAIL: Prettier (CRLF checkout, fixed by `.gitattributes`), Vitest | 199 s |
| web | `--full` | `7e7e7d7` | FAIL: Vitest, Lighthouse performance (both fail on `main` too); 18 others PASS, both image smokes included | 1039 s |
| web | `--full` | iltiam-web#72's change on `b3686a4` | FAIL only on the Node 24 Vitest test; Lighthouse performance PASS | 777 s |
| web | `npx vitest run` in `node:22-bookworm` | the same | PASS, 45 files, 387 tests | |
| web | `--full` | `e5e5f94` (#71 with `main` and #72) | FAIL: Vitest (Node 24 only), Lighthouse performance 0.89 to 0.90 (blank filmstrip frames, speed index 11.2 s; `main` measures the same here); 18 others PASS | 1010 s |
| web | `npx vitest run` in `node:22-bookworm` | `e5e5f94` | PASS, 45 files, 387 tests | |
| web | `npm run lhci:perf` in `mcr.microsoft.com/playwright:v1.64.1-noble` | `e5e5f94` | PASS, 100 on `/login` and `/login?lang=ar`, speed index 0.3 s | |
| backend | `--fast` | 14223c2 + new files | FAIL: 5 vendored-contract byte checks (stale CRLF checkout, refreshed) | 277 s |
| backend | `--full` | `2dab0e7` | PASS (image smoke SKIPPED-OPTIONAL: no build file changed) | about 12 min |
| backend | `--full --image` | `2dab0e7` | PASS, image smoke amd64 + arm64 included | 1428 s |
| ai-service | `--fast` | 9ecf382 + new files | FAIL only on the changed-files guard (files were being added during the run); pytest 2990 passed, 3 skipped | 401 s |
| ai-service | `--full` | `1fec8ce` | PASS (regression and image smoke SKIPPED-OPTIONAL) | about 7 min |
| ai-service | `--full --image` | `1fec8ce` | PASS, image smoke with real weights amd64 + arm64 included (regression SKIPPED-OPTIONAL) | 2123 s |
| deployment | `--fast` | 3a61591 + new files | FAIL: shellcheck and gitleaks BLOCKED (Docker engine stopped) | 337 s |
| deployment | `--full` | `a99e4d6`, then the PR head | PASS | about 9 min |
| web | `--full` (Node 22) | `18c124b` (`main`) | FAIL only on Lighthouse performance 0.89 (blank filmstrip frames on Windows); 19 others PASS | 1341 s |
| web | `--full` (Node 22, Lighthouse in the Playwright Linux image) | `aa7deb6` (iltiam-web#73) | PASS, 20/20; performance 1.00 on all 6 runs | 1128 s |
| web | `publish-image.sh web` | `aa7deb6` | published `iltiam-web:sha-aa7deb6`, linux/amd64 + linux/arm64 | |
| deployment | `--full` | `21f74a6` (iltiam-deployment#71) | PASS, 10/10 (a first run failed only the preflight, because of an empty `~/.iltiam/deploy/staging/`) | 620 s |
| deployment | `deploy` workflow, staging | `aeec8f3` (run 43574332851) | success after the run was approved on the Actions page; web recreated, healthy; `/api/ready/` all ok | |

Failure proofs (break something, run `--fast`, revert; the tree was clean afterwards):

| Repository | Break | Result |
|---|---|---|
| mobile | `void   ciLocalFailureProof( ){}` appended to `lib/app.dart` | `dart format (check)` FAIL, exit 1 |
| web | (the first real runs) CRLF checkout; untracked `web/dist-api` | Prettier FAIL; changed-files guard FAIL; exit 1 |
| backend | `ci_local_failure_proof = models.IntegerField(default=0)` on `Visit` | `no missing migrations` FAIL (and pytest), exit 1 |
| ai-service | `import os` appended to `src/iltiam_ai/__init__.py` | `ruff check` FAIL, exit 1 |
| deployment | `WEB_IMAGE=...:latest` in `env/staging.versions` | `versions files` and `check-compose.sh` FAIL, exit 1 |

The hook installer was tested in a scratch repository: an existing pre-push hook is kept and runs first; running it
again changes nothing; a failing `--fast` blocks the push (exit 1); a delete-only push skips the check; a custom
`core.hooksPath` is left untouched (chained through `.git/local-ci-hooks`); `--uninstall` restores both cases. It is
**not** installed in anyone's clone yet: run `scripts/install-hooks.sh` once per clone.

What the runs found that CI never saw:

- web: a developer's `web/.env.local` silently turned the demo build into the API build (38 Playwright timeouts);
  the script now pins `VITE_*` as CI had them. On `main`, web-ci has failed on every push since 2026-11-13 08:16
  UTC (quota): Lighthouse performance on `/login?lang=ar` (0.64, CLS 0.918) and one Vitest test have never been green.
  The first is a real bug: the page painted left to right, then flipped to right to left once React ran; fixed in
  iltiam-web#72 (language and direction set before the first paint: 1.00, CLS 0). The second is Node 24 only: in
  the test setup, Node 24's `fetch` (undici) cannot stream a jsdom `File`. It passes on Node 22, the pinned version.
- backend: `apps/integrations/ai/contract/schemas/` was CRLF in this clone (made before its `-text` rule). The first
  check now catches that and prints the fix.
- The new scripts themselves: shellcheck 0.9.0 found 9 issues, all fixed. The image smokes were moved to their own
  Compose projects after noticing that `down -v` on the default `iltiam-ai` project would remove a developer's local
  volumes.
- backend's agent file is tracked as `claude.md` (lower case): Claude Code finds it on Windows and macOS but not on a
  case-sensitive Linux checkout. Not renamed here.

Timing on this machine: `--fast` takes 3 to 11 minutes (mobile's tests take 5.5 minutes; deployment's
`check-env.sh` takes 5 to 8 minutes under Git Bash). That is longer than "a few minutes", and it is what the hook
makes people wait for before a push.
