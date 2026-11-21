# Runbook 9: automatic staging deploys (health check, rollback, database backup)

> **Version 2, 2026-11-21: `auto-deploy-staging.yml`, in this repository only.** Every 15 minutes it compares the `main` of `iltiam-ai-service`, `iltiam-backend` and `iltiam-web` with what staging runs, builds what changed here (this repository is public: its Actions minutes and ARM runners are free; the app repositories' minutes are used up, so nothing runs there), and deploys it with the health check, rollback and backend backup of version 1. **Version 1** (2026-11-12 to 2026-11-14: the app repositories built and sent a `repository_dispatch`, the bot committed to `main`) is retired; its text is at the end of this page (Appendix), as the record.

- **Issue:** iltiam/iltiam-deployment#16 (DEP-03). Builds on [Runbook 5](05-compose-stack.md) (the Compose stack and the manual deploy).
- **Who:** an admin of `iltiam-deployment` who can create a fine-grained token for the `iltiam` organisation, change GHCR package settings and log in to `iltiam-1` (`ssh iltiam`, Runbook 1).
- **Time:** about 20 minutes to set up (section 2), about 1 hour for the web tests (section 5).
- **Result:** a merge to `main` of an app repository is on **staging** within about 15 to 30 minutes, **only that service** changes, a failed health check puts the previous version back by itself, and a backend deploy saves the staging database first. Production is never touched.

> **This repository is public, and so is every log, artifact and cache its workflows make.** Never paste a secret, the VM's IP address or a backup's content into this runbook, an issue, a PR, a commit or a chat. Section 9 says how the workflow keeps the private app code and the secrets out of its log.

## As built

Filled in when the steps are done. Names and dates only: never a token, an IP or a fingerprint.

| Item | Value |
|---|---|
| `APP_SOURCE_TOKEN` created (section 2.1), expiry | expires 2027-01-15 |
| Environment `app-source`, main only, secret set (section 2.2) | |
| GHCR **Write** for `iltiam-deployment` on the 4 packages (section 2.3) | |
| `/srv/iltiam/backups/pre-deploy` on the VM (section 2.4) | done 2026-11-12 (version 1) |
| `AUTO_DEPLOY` (section 3) | `false` |
| Tests T1 to T4, web (section 5) | |
| Tests T5 to T8 (backend after its backup is confirmed, ai, queue, schedule) | |

## 1. How it works

```
every 15 min (or Run workflow) ─▶ AUTO_DEPLOY "true"? (a run by hand doesn't ask) ── no ─▶ skipped, nothing changes
   └─ yes ─▶ sources: each app repository's main (APP_SOURCE_TOKEN, read-only)
          ─▶ plan: what staging runs (SSH, read-only) against main ─▶ nothing behind? done
          ─▶ build (ubuntu-24.04-arm): the source tarball ─▶ docker buildx, linux/arm64 ─▶ GHCR sha-<7>
          ─▶ deploy, one service at a time (ai, backend, web), in the deploy-staging queue:
                (backend only) database backup ─▶ push auto/staging ─▶ deploy ─▶ health check
                ─▶ failed? deploy the commit before it again ─▶ health check ─▶ tag auto-failed/<service>/sha-<7> ─▶ red
```

In plain words:

1. **sources** reads the commit each app repository's `main` is at, with `APP_SOURCE_TOKEN` (Contents: Read-only on those three repositories, nothing else).
2. **plan** asks the VM over SSH which image each service runs (`scripts/remote-deploy.sh --status staging`: names and tags only, the VM changes nothing) and compares the tag with `sha-<7>` of that `main`. A service is left alone when it is up to date, when its profile is off, when its container is missing (a person looks first, section 6) or when that commit already failed (an `auto-failed/<service>/sha-<7>` tag, section 6). The run's summary shows the table.
3. **build**, for each service whose image isn't on GHCR yet, on a free `ubuntu-24.04-arm` runner: downloads that commit as a tarball, builds the same targets as `scripts/publish-image.sh` (ai: `api` and `worker`; backend: `runtime`; web: the `web/` folder) for **linux/arm64 only**, and pushes `sha-<7>` with the `org.opencontainers.image.revision` label the health check reads. The build's own output is never shown (section 9). An image published from a laptop with `publish-image.sh` is used as it is: nothing is rebuilt.
4. **deploy**, one service at a time, in the same `deploy-staging` queue as a manual deploy (`deploy.yml`), so two deploys never overlap. For each service:
   1. the image is on GHCR with linux/arm64 (if its build failed, this service is skipped);
   2. what staging runs, read again now that the queue is held;
   3. two commits, on top of the workflow's own commit of `main`: the **base** (`env/staging.versions` set to what the VM runs) and the **target** (plus the new tag, `scripts/set-version.sh --auto`). Only `env/staging.versions` may differ from `main`, so every script the VM runs is `main`'s, reviewed;
   4. **backend only:** the database backup (section 7). If it fails, nothing is pushed and nothing on the VM changes;
   5. both commits are pushed to the branch **`auto/staging`** (never to `main`, which is protected), and the VM deploys the target with the same scripts as a manual deploy; Compose restarts only the containers whose tag changed;
   6. the health check (section 4);
   7. if the deploy or the health check fails: the VM deploys the **base** again and checks it, `auto/staging` goes back to the base, and the failed commit is tagged `auto-failed/<service>/sha-<7>` so the next runs don't try it again. The run ends **red** and GitHub emails you.
5. **report**: a build that failed is tagged `auto-failed/...` the same way.

**Where the truth is.** While this is on, `git show origin/auto/staging:env/staging.versions` says what staging runs, and `main` may be behind it. A manual deploy (`deploy.yml`) deploys `main`'s tags: with `AUTO_DEPLOY` on, the next run moves the changed services forward again, so **turn `AUTO_DEPLOY` off first** when a manual deploy must stay. Before a freeze, make `main` say what staging runs (section 3.2).

**Two changes at once.** One run at a time (concurrency `auto-deploy-staging`); GitHub keeps one more waiting and a newer one replaces it (it shows as **cancelled**, which loses nothing: each run compares `main` with what runs now). Several merges to one repository within 15 minutes deploy only the newest. A merge during a run is picked up by the next one. Changes in two repositories deploy one after the other, ai first, then backend, then web; a failure stops the ones after it until the next run.

## 2. Set up (once)

In PowerShell on your laptop. Nothing here prints a secret.

### 2.1 The source token

1. GitHub → your picture → **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token.**
2. **Token name:** `iltiam-auto-deploy-source-read`. **Resource owner:** `iltiam`.
3. **Expiration:** custom, **2027-01-15**.
4. **Repository access:** **Only select repositories → `iltiam-web`, `iltiam-backend`, `iltiam-ai-service`.**
5. **Permissions → Repository permissions → Contents: Read-only.** GitHub adds **Metadata: Read-only** by itself. Nothing else, no account permissions.
6. **Generate token.** Copy it once, for 2.2.
7. If the organisation requires approval: organisation **Settings → Personal access tokens → Pending requests → Approve**.

**What it can do:** read the code of the three private app repositories. Treat it like a password (`docs/secrets.md`, section 2).

### 2.2 The `app-source` Environment and its secret

The token lives in an Environment of its own that only `main` can use, so the deploy jobs never see it and a pushed branch can't read it:

```powershell
'{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}' | gh api -X PUT repos/iltiam/iltiam-deployment/environments/app-source --input -
gh api -X POST repos/iltiam/iltiam-deployment/environments/app-source/deployment-branch-policies -f name=main -f type=branch
gh secret set APP_SOURCE_TOKEN --env app-source -R iltiam/iltiam-deployment
gh secret list --env app-source -R iltiam/iltiam-deployment
```

`gh secret set` asks for the value and doesn't show it, so it never lands in your PowerShell history. **What you should see:** `APP_SOURCE_TOKEN` with today's date. Never a value.

### 2.3 GHCR: Write for this repository

The build job pushes with its own `GITHUB_TOKEN` (`packages: write`), so no registry token is stored. For each of **`iltiam-ai-api`, `iltiam-ai-worker`, `iltiam-backend`, `iltiam-web`**: `https://github.com/orgs/iltiam/packages/container/<name>/settings` → **Manage Actions access** → `iltiam-deployment` (already there with **Read**, for the manual deploy) → **Role: Write**. If it isn't listed: **Add Repository** → `iltiam-deployment` → **Write**.

### 2.4 The backup folder on the VM

Done for version 1 on 2026-11-12. To check it, as `ubuntu` on the VM (`ssh iltiam`):

```bash
sudo install -d -m 700 -o deploy -g deploy /srv/iltiam/backups /srv/iltiam/backups/pre-deploy
sudo stat -c '%a %U:%G %n' /srv/iltiam/backups /srv/iltiam/backups/pre-deploy
df -h /srv/iltiam
```

**What you should see:** `700 deploy:deploy` twice, and more than 1 GB free (the backup refuses to run with less, because the database lives on the same volume).

## 3. Turn it on and off

### 3.1 The switch

The repository variable `AUTO_DEPLOY` (**Settings → Secrets and variables → Actions → Variables**). Anything but `true` (or no variable) is off: **scheduled runs are skipped** and change nothing. A run started by hand (**Actions → auto-deploy-staging → Run workflow**) works whatever it says, as a manual deploy does.

```powershell
gh variable set AUTO_DEPLOY -R iltiam/iltiam-deployment --body true    # on
gh variable set AUTO_DEPLOY -R iltiam/iltiam-deployment --body false   # off
gh variable list -R iltiam/iltiam-deployment
```

**Everything off**, the button too: `gh workflow disable auto-deploy-staging.yml -R iltiam/iltiam-deployment` (`gh workflow enable ...` brings it back). **Turn `AUTO_DEPLOY` off whenever you work on the VM by hand** (a manual `scripts/deploy.sh` and an automatic one would collide on the VM's deploy lock).

### 3.2 Freeze before the Dec 1 demo (on 2026-11-29)

Staging must not change by itself before a demo. In this order:

```powershell
gh variable set AUTO_DEPLOY -R iltiam/iltiam-deployment --body false
gh workflow disable auto-deploy-staging.yml -R iltiam/iltiam-deployment
gh run list -R iltiam/iltiam-deployment --workflow auto-deploy-staging.yml --status in_progress
gh run list -R iltiam/iltiam-deployment --workflow auto-deploy-staging.yml --status queued
```

1. **Wait** until both lists are empty. Never cancel a run that is deploying: a cancelled deploy can leave a service half rolled.
2. **Make `main` say what staging runs**, so an emergency manual deploy during the demo week deploys what is running now, not older tags:

   ```powershell
   git -C iltiam-deployment fetch origin
   git -C iltiam-deployment diff origin/main origin/auto/staging -- env/staging.versions
   ```

   No output: nothing to do. Otherwise open the PR from `auto/staging` (it holds only `env/staging.versions` changes), get the approval, merge:

   ```powershell
   gh pr create -R iltiam/iltiam-deployment --base main --head auto/staging --title "chore(staging): record the tags staging runs before the Dec 1 demo" --body "Freeze (Runbook 9, section 3.2): env/staging.versions as the automatic deploy left it. No deploy needed: staging already runs these tags."
   ```

3. **Check staging** as in section 5 (the `/api/ready/` check and a sign-in), and write the tags down in the demo notes.

### 3.3 Freeze before the final demo (around 2026-12-08)

The same steps as 3.2, **two days before** that demo (2026-12-06 if it is on 2026-12-08), with `final demo` in the PR title. Between the two demos you may turn it back on (3.4) to deliver fixes; if you don't, nothing changes until you do.

### 3.4 Back on after a freeze

```powershell
gh workflow enable auto-deploy-staging.yml -R iltiam/iltiam-deployment
gh workflow run auto-deploy-staging.yml -R iltiam/iltiam-deployment --ref main -f mode=plan
gh variable set AUTO_DEPLOY -R iltiam/iltiam-deployment --body true
```

Read the plan run's summary first: it lists what the next scheduled run will build and deploy.

## 4. The health check

[`scripts/health-check.sh`](https://github.com/iltiam/iltiam-deployment/blob/main/scripts/health-check.sh) runs on the VM after `scripts/deploy.sh`, which has already waited for every container's own health check (Runbook 5, section 6).

| Service | Containers (each must run the tag in `env/staging.versions`, with the matching `org.opencontainers.image.revision`, be running and healthy, and not restart during 60 seconds) | Probes |
|---|---|---|
| `ai` | `ai-api`, `ai-worker` (healthy), `ai-beat` (running; it has no health check) | `ai-api` answers `/ready` with `ready`; `backend-web` reaches `http://ai-api:8000/ready`; `https://staging-api.iltiamcare.com/api/ready/` is 200 `ready` |
| `backend` | `backend-web`, `backend-worker`, `backend-beat` (healthy) | `https://staging-api.iltiamcare.com/api/health/` is 200 `ok`; `/api/ready/` is 200 `ready` (`db`, `redis`, `storage`, `ai`) |
| `web` | `web` (healthy) | `https://staging-app.iltiamcare.com/` is 200; `/config.js` is 200 and points at `https://staging-api.iltiamcare.com` |

The public addresses are asked **from the VM**: the request still goes out through Cloudflare and back through the tunnel (Runbook 5, section 7.3), and Cloudflare can't mistake a GitHub runner for a bot. The log shows names, tags, states, HTTP codes and the names of failing readiness checks only: never a response body or a log line. To see why a container is unhealthy, read its logs on the VM (Runbook 5, section 9.1).

**It doesn't test** sign-in, an upload or an analysis: that is the end-to-end smoke, #17.

## 5. Test it

In PowerShell on your laptop, in the folder that holds the clones, with `AUTO_DEPLOY` still `false` (scheduled runs skip; these runs are started by hand). Wait for each run to end before the next. **Web first**: it has no database. The backend (T5) only after you have confirmed that the staging demo data is backed up.

```powershell
function Last { gh run list -R iltiam/iltiam-deployment --workflow auto-deploy-staging.yml -L 1 --json databaseId --jq '.[0].databaseId' }
function Watch { gh run watch (Last) -R iltiam/iltiam-deployment --exit-status }
function Summary { gh run view (Last) -R iltiam/iltiam-deployment }
```

**After every run, check its public log for leaks** (replace `<VM IP>` with the address from `~/.ssh/config`; any line printed needs a look, and a real secret means section 7 of `docs/secrets.md`):

```powershell
gh run view (Last) -R iltiam/iltiam-deployment --log > "$env:TEMP\auto-run.log"
Select-String -Path "$env:TEMP\auto-run.log" -Pattern 'github_pat_','ghs_','ghp_','PRIVATE KEY','PASSWORD=','SECRET_KEY=','HEAD is now','Dockerfile:','import ','def ','src/','<VM IP>'
```

| # | What it proves | Do | What you should see |
|---|---|---|---|
| T1 | The plan reads both sides, changes nothing | `gh workflow run auto-deploy-staging.yml -R iltiam/iltiam-deployment --ref main -f mode=plan -f only=all`; `Watch`; `Summary` | Green. Jobs **App repositories' main** and **Plan** only. The table shows what staging runs (on 2026-11-21: ai `sha-a11a24d`, backend `sha-14223c2`, web `sha-aa7deb6`), each `main`, and `would build, would deploy` for the ones behind. No build, no deploy, no `auto/staging` branch |
| T2 | Build and push, no deploy | `... -f mode=build -f only=web`; `Watch` | Green; a **Build web** job on `ubuntu-24.04-arm` whose log shows `source: iltiam-web at sha-<7>`, `unpacked`, `ok: ghcr.io/iltiam/iltiam-web:sha-<7>`, and nothing of the build itself. On the laptop: `docker buildx imagetools inspect ghcr.io/iltiam/iltiam-web:sha-<7>` lists `linux/arm64` |
| T3 | One service deploys, the rest doesn't | `... -f mode=deploy -f only=web`; `Watch` | Green; **Deploy web**: image published, base and target, push `auto/staging`, deploy, health check `ok` lines; summary `deployed and healthy`. On the VM only `web` has a new start time. `git -C iltiam-deployment fetch; git -C iltiam-deployment show origin/auto/staging:env/staging.versions` names the new web tag. Sign in on `https://staging-app.iltiamcare.com` |
| T4 | **Rollback** | `... -f mode=deploy -f only=web -f sha=aa7deb66bb0e70c96e5f060fe6088b34e6864fda -f simulate_failure=true`; `Watch` | Red, on purpose. The log deploys `sha-aa7deb6` (already on GHCR, no build), passes the health check, then **Simulated failure**, **Roll back** (the T3 tag again, health check `ok`) and **Record the failure**; summary `FAILED, rolled back to sha-<T3>`. `auto/staging` names the T3 tag again; the tag `auto-failed/web/sha-aa7deb6` exists. Then delete it: `gh api -X DELETE repos/iltiam/iltiam-deployment/git/refs/tags/auto-failed/web/sha-aa7deb6` |
| T5 | **Backend: the backup** (only after you confirm the demo data is backed up) | `... -f mode=deploy -f only=backend`; `Watch` | Green; summary line `Database backup: /srv/iltiam/backups/pre-deploy/<UTC time>-backend-sha-<7>.sql.gz`; on the VM that file is `-rw------- deploy deploy` and `gzip -t <file> && echo ok` prints `ok`. Backend `main` has a migration staging doesn't have (2026-11-21): it runs, and a rollback would not undo it (section 6) |
| T6 | ai: the no-downtime rollout | `... -f mode=deploy -f only=ai`; `Watch` | Green; two **ai** images built (`iltiam-ai-api`, `iltiam-ai-worker`); the rollout lines of `scripts/deploy.sh`; health check `ok` |
| T7 | Two deploys wait for each other | Start a run with `mode=deploy` that has something to deploy, then at once `gh workflow run deploy -R iltiam/iltiam-deployment --ref main -f environment=staging` | The manual one says **Waiting** until the automatic one's deploy job ends; neither is cancelled. (The manual deploy then puts `main`'s tags back: run T1 to see what is behind again) |
| T8 | The schedule | `gh variable set AUTO_DEPLOY -R iltiam/iltiam-deployment --body true`, then wait for :07, :22, :37 or :52 | A run by **schedule**: with nothing behind, green in about 2 minutes, only sources and plan. Merge something small to `iltiam-web`: within about 15 to 30 minutes, a run builds and deploys it by itself |

## 6. When a deploy fails

**A deploy job is red, its summary says `FAILED, rolled back to sha-…`.** Staging runs the previous version again, `auto/staging` says so, and the failed commit is tagged `auto-failed/<service>/sha-<7>`: the next runs skip it, so nothing loops. Find out why in the failed step's log (and on the VM, `iltiam staging logs --tail 100 <service>`), fix it in the app repository and merge: the new commit deploys by itself. To try the same commit again (a flaky check, say): **Run workflow** with `mode=deploy`, `only=<service>`, `retry_failed` ticked.

**A build job is red** (`the build of ghcr.io/iltiam/... failed`). Its output is not in the log on purpose (section 9): rebuild on a laptop, from the app's clone at that commit, the command the error line gives (`docker buildx build --platform linux/arm64 ...`), or `scripts/publish-image.sh <service> <clone> --dry-run` then without `--dry-run`. The **report** job tagged it `auto-failed/...`: fix and merge, or publish it from the laptop and run with `retry_failed`.

**The summary says `FAILED before anything changed`.** The image check, the backup, a commit or the push failed. The VM is as it was. Read the failed step; fix; run again by hand.
- **`the backup script ended without reporting its file`:** read the lines above it (the script's own `ERROR:` line, if any), then on the VM `ls -l /srv/iltiam/backups/pre-deploy/` and `df -h /srv/iltiam`.
- **`could not read iltiam-<repo> main`** (job **App repositories' main**): `APP_SOURCE_TOKEN` is missing, expired or lacks that repository (section 2.1).
- **`GHCR login failed` or a push denied** (build job): the package lacks **Write** for this repository (section 2.3).

**The plan says `no <container> container on staging`.** A service that should run has no container at all: that is an incident, not a version change, so nothing deploys it by itself. On the VM: `iltiam staging ps -a`, then a manual deploy (Runbook 5, section 6).

**The summary says `FAILED, and the rollback failed too`.** Staging may run a broken service. Turn the automatic deploy off (section 3.1), then:

1. `git -C iltiam-deployment fetch` and `git -C iltiam-deployment show origin/auto/staging:env/staging.versions`: the tags staging should run (the base).
2. Run a manual deploy (Runbook 5, section 6). It deploys `main`'s tags: if they are older than the base, open a PR from `auto/staging` first (section 3.2, step 2).
3. On the VM: `iltiam staging ps` and the service's logs.
4. If the backend's database is the problem, section 7.

**A run was cancelled** (it timed out, or a newer one replaced it while it waited): nothing to do; the next run compares again. If it was cancelled in the middle of a deploy, check `iltiam staging ps` on the VM and run the plan (section 5, T1).

**Migrations never roll back by themselves.** A rollback puts the previous image back, not the previous database. Write backend migrations so the previous version still works with them: add tables and columns (nullable, or with a default) in one release, and remove them only in a later one. If an older backend can't run on the newer database, either fix forward (merge a fix) or restore the backup (section 7). The same holds for the AI service's own database (`ai-api` migrates when it starts), which has no pre-deploy backup.

## 7. Restore from a pre-deploy backup

Each automatic backend deploy saves the staging database `iltiam` just before it:
`/srv/iltiam/backups/pre-deploy/<UTC time>-backend-sha-<7>.sql.gz` (mode 600, owner `deploy`; the newest 5 are kept). `sha-<7>` is the build that **was about to be deployed**: the file holds the database as the backend **before** it used it, so it belongs with the tag that ran before (the deploy run's summary: `### Staging: backend <before> -> <tag>`).

**Restoring deletes everything written to staging after that time** (accounts, visits, messages). Photos in object storage stay, but nothing points to the newer ones any more. The AI service's database is not touched.

On the VM, as `deploy` (`ssh iltiam`, then `sudo -iu deploy`):

1. **Pick the file and check it.**

   ```bash
   stg() { bash /srv/iltiam/repo/scripts/compose.sh staging "$@"; }
   ls -lt /srv/iltiam/backups/pre-deploy/
   FILE=/srv/iltiam/backups/pre-deploy/<the file's name>
   gzip -t "$FILE" && echo "the file is readable"
   ```

   **What you should see:** the files, newest first, then `the file is readable`.

2. **The backend must already run the matching, older version.** After an automatic rollback it does. Otherwise, put that tag back first (Runbook 5, section 9.4) and deploy, or the newer backend would migrate the restored database again.

   ```bash
   stg ps --format '{{.Service}} {{.Image}}' | grep backend
   ```

3. **Stop everything that writes to the database:**

   ```bash
   stg stop backend-web backend-worker backend-beat
   ```

4. **Replace the database with an empty one** (as the `postgres` superuser, inside the container):

   ```bash
   stg exec -T postgres psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
     -c 'DROP DATABASE iltiam WITH (FORCE);' \
     -c 'CREATE DATABASE iltiam OWNER iltiam;' \
     -c 'REVOKE ALL ON DATABASE iltiam FROM PUBLIC;'
   ```

   **What you should see:** `DROP DATABASE`, `CREATE DATABASE`, `REVOKE`.

5. **Load the backup** (quiet: it prints only errors, and stops at the first one):

   ```bash
   gzip -dc "$FILE" | stg exec -T postgres psql -U postgres -d iltiam -v ON_ERROR_STOP=1 -q >/dev/null
   stg exec -T postgres psql -U postgres -d iltiam -Atc 'SELECT count(*) FROM django_migrations;'
   ```

   **What you should see:** no output from the first command, then a number above 0: the backend migrations recorded in the backup.

6. **Start the backend again and check it:**

   ```bash
   stg up -d --wait --no-deps backend-web backend-worker backend-beat
   bash /srv/iltiam/repo/scripts/health-check.sh staging backend
   ```

   **What you should see:** the three containers `Healthy`, then `backend healthy on staging`.

7. Write down in the issue what you restored and why (the file name and the time; never the content).

**Never copy a backup off the VM, attach it anywhere or open it in a chat:** it holds patients' personal data.

## 8. Day to day

- **Everything that reaches an app repository's `main` goes to staging**, merged with `scripts/merge-pr.sh` or not: the private repositories can't be protected on GitHub Free. Keep merging only what passed `scripts/ci-local.sh --full`; the health check is the only gate here (the old image workflows' smoke tests don't run).
- **A docs-only merge** builds and deploys too (free here, about 5 to 15 minutes of runner time). Harmless: the new image runs the same code.
- **The token expires on 2027-01-15.** GitHub emails you a week before. Then the job **App repositories' main** turns red and nothing changes. Make a new token (2.1) and set it again (2.2).
- **GHCR fills up.** Every build adds an arm64 image (about 400 MB for the AI images, less for the others; private packages). Prune old `sha-` tags of private packages now and then (package page → **Package settings** or the versions list), never the ones `env/*.versions` or `auto/staging` name.
- **Images built here are linux/arm64 only.** A laptop on x86 can't run those tags; for one it needs, publish it from the laptop with `scripts/publish-image.sh` (both architectures). Releases (`X.Y.Z`) still go through `publish-image.sh`.
- **A deploy deploys the workflow's commit of this repository's `main`**, with only `env/staging.versions` changed. A merged change to `compose.yml` goes live with the next deploy of any service, automatic or manual.
- **Scheduled runs are best effort**: GitHub may start one late or skip it when busy. A schedule also stops after 60 days without any activity in this repository (GitHub emails first).

## 9. Security notes: public logs, private code

`scripts/check-public-workflows.sh` (run by `scripts/ci-local.sh` and `env-check.yml`, with a self-test that proves each rule refuses a workflow breaking it) enforces these on every workflow of this repository:

- **Who can run it.** Triggers `schedule` and `workflow_dispatch` only: no `pull_request_target` or `workflow_run`, and no `pull_request` workflow uses a secret or an Environment, so no fork's code ever runs with these secrets. Both Environments (`app-source`, `staging`) allow `main` only, and `main` needs a reviewed PR: a pushed branch with an edited workflow can't read them.
- **Secrets by name.** Never `toJSON(secrets)` (GitHub held every deploy run that passed all of them, "This workflow file may be malicious"); each secret the render needs is listed as `DEPLOY_SECRET_<NAME>`, and the list is checked against the env templates. `APP_SOURCE_TOKEN` is used only as `GH_TOKEN` for `gh`, never in a URL, a git remote or a command line, and the deploy jobs never see it (another Environment).
- **No git on private code.** `actions/checkout` and git print commit messages and file names; the source comes as `gh api repos/iltiam/<repo>/tarball/<sha>` into the runner's temporary folder, unpacked quietly, deleted when the step ends.
- **No build output.** `docker buildx build --progress=quiet` with its whole output in a file that is never printed: on a failure Docker quotes the Dockerfile and the failing command's output. The log gets one fixed line instead (section 6).
- **No artifacts, no caches.** Anyone signed in can download a public repository's artifacts, and a fork's pull request workflow can restore caches saved on `main` (image layers hold the code). So no `actions/upload-artifact`, no `actions/cache`, no buildx `type=gha` cache, and no `docker/build-push-action` (its build record artifact and job summary hold the Dockerfile and the log). Builds start cold.
- **Logins.** `docker login --password-stdin` only, with the job's own `GITHUB_TOKEN` (dead when the job ends); `docker logout` at the end. No `set -x`, no `printenv`, no debug logging.
- **What the log shows:** service names, `sha-<7>` tags, image names, container states, HTTP codes and the backup's file name: what `env/staging.versions` and this runbook publish anyway. The scripts the VM runs (`deploy.sh`, `health-check.sh`, `pre-deploy-backup.sh`) already print names only.
- **What the bot can write:** the `auto/staging` branch and `auto-failed/*` tags of this repository (its own `GITHUB_TOKEN`, `contents: write`); never `main` (protected), never production (`set-version.sh`, `pre-deploy-backup.sh` and `health-check.sh` refuse it).
- **Check it yourself** after a run: section 5, the log search.

## Appendix: version 1 (retired 2026-11-14)

As built and tested on 2026-11-12 (#57, #58), kept as the record. **Nothing here is in use:** the app repositories' image workflows are disabled, the `auto` job and the `repository_dispatch` trigger are gone from `deploy.yml`, and the `DEPLOY_DISPATCH_TOKEN` secrets are no longer read (delete them). Its health check (section 4), backup and restore (section 7) live on in version 2. Section numbers inside this appendix are version 1's own.

### v1: As built

Filled in when the steps are done. Names and dates only: never a token, an IP or a fingerprint.

| Item | Value |
|---|---|
| `DEPLOY_DISPATCH_TOKEN` created, expiry date (section 2.1) | |
| Secret set in ai-service, backend, web (section 2.2) | |
| `/srv/iltiam/backups/pre-deploy` on the VM (section 2.3) | |
| `AUTO_DEPLOY` (section 3) | |
| Tests T1 to T10 (section 5) | |

### v1: 1. How it works

```
merge to main ─▶ CI green ─▶ image workflow builds that commit ─▶ GHCR sha-<7>
   ─▶ "deploy-staging" job sends {service, sha} ─▶ iltiam-deployment, workflow "deploy", job "auto"
   ─▶ AUTO_DEPLOY is "true"? ── no ─▶ job skipped, nothing changes
                             └─ yes ─▶ image published? ─▶ new tag in env/staging.versions
                                        ─▶ (backend only) database backup ─▶ commit to main ─▶ deploy ─▶ health check
                                        ─▶ failed? revert the commit ─▶ deploy again ─▶ health check ─▶ job red
```

In plain words:

1. **The app repositories** (`image.yml` in ai-service and backend, `web-image.yml` in web) start by themselves when their CI workflow (`ci`, `CI`, `web-ci`) finishes **green on a push to `main`**. They build the exact commit CI tested, smoke-test it on both architectures and publish `sha-<7>`. Their last job, **deploy-staging**, then asks this repository to deploy it. A pull request still only builds; a manual **Run workflow** or a `vX.Y.Z` tag publishes but doesn't deploy.
2. **This repository's `deploy` workflow** gets the request (a `repository_dispatch` called `deploy-staging`). Its **auto** job runs only while the repository variable `AUTO_DEPLOY` is `true`. It:
   1. checks the request (service `ai`, `backend` or `web`; a full commit hash) and that the image is on GHCR with `linux/arm64`;
   2. writes the new tag into `env/staging.versions` with [`scripts/set-version.sh`](https://github.com/iltiam/iltiam-deployment/blob/main/scripts/set-version.sh): only that service's line (both AI lines for `ai`), plus a one-line comment naming the commit. Nothing changed means no commit: it only runs the health check;
   3. **for the backend only**, saves the staging database on the VM ([`scripts/pre-deploy-backup.sh`](https://github.com/iltiam/iltiam-deployment/blob/main/scripts/pre-deploy-backup.sh), section 7). If that fails, the job stops: nothing is committed and nothing on the VM changes;
   4. commits the file to `main` as `github-actions[bot]`, with the message `chore(staging): deploy <service> sha-<7> (auto)`;
   5. deploys that commit with the same scripts as a manual deploy (Runbook 5, section 6). Compose only restarts the containers whose tag changed, so the other services keep running;
   6. runs [`scripts/health-check.sh`](https://github.com/iltiam/iltiam-deployment/blob/main/scripts/health-check.sh) on the VM (section 4);
   7. if the deploy or the health check fails: `git revert` of its own commit (`chore(staging): roll back …`), pushed to `main`, deployed, and checked again. The job then ends **red**, and GitHub emails you.
3. **Git stays the truth.** `env/staging.versions` on `main` always says what staging runs, and `git log -p env/staging.versions` shows every deploy and rollback. **Run `git pull` before you edit that file yourself.**

The manual deploy (**Actions → deploy → Run workflow**) works as before, whatever `AUTO_DEPLOY` says, and shares the same queue: only one deploy runs at a time.

### v1: 2. Set up (once)

#### v1 2.1 The dispatch token

The app repositories need permission to start a workflow here. That is a fine-grained personal access token that can do exactly one thing: write to `iltiam-deployment`.

1. GitHub → your picture → **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token.**
2. **Token name:** `iltiam deploy-staging dispatch`. **Resource owner:** `iltiam`.
3. **Expiration:** a custom date after the project ends (for example 2027-01-31), or the longest the organisation allows. Write the date in As built.
4. **Repository access:** **Only select repositories → `iltiam-deployment`**. Nothing else.
5. **Permissions → Repository permissions → Contents: Read and write.** GitHub adds **Metadata: Read-only** by itself. Nothing else: this is the minimum GitHub accepts for a `repository_dispatch`.
6. **Generate token.** Copy it once; you'll paste it in 2.2 and then never need it again.
7. If the organisation requires approval: organisation **Settings → Personal access tokens → Pending requests → Approve**.

**What it can do:** start this workflow, and write to this repository (which is public and its `main` unprotected), so treat it like a password.

#### v1 2.2 The secret in the three app repositories

The same token, as a **repository** secret in each (on GitHub Free, private repositories can't read organisation secrets). In PowerShell, on your laptop; each command asks for the value and doesn't show it:

```powershell
gh secret set DEPLOY_DISPATCH_TOKEN -R iltiam/iltiam-ai-service
gh secret set DEPLOY_DISPATCH_TOKEN -R iltiam/iltiam-backend
gh secret set DEPLOY_DISPATCH_TOKEN -R iltiam/iltiam-web
gh secret list -R iltiam/iltiam-web
```

**What you should see:** `DEPLOY_DISPATCH_TOKEN` in the list, with today's date. Never a value.

#### v1 2.3 The backup folder on the VM

As `ubuntu` on the VM (`ssh iltiam`):

```bash
sudo install -d -m 700 -o deploy -g deploy /srv/iltiam/backups /srv/iltiam/backups/pre-deploy
sudo stat -c '%a %U:%G %n' /srv/iltiam/backups /srv/iltiam/backups/pre-deploy
df -h /srv/iltiam
```

**What you should see:** `700 deploy:deploy` twice, and more than 1 GB free (the backup refuses to run with less, because the database lives on the same volume).

#### v1 2.4 Package access

Nothing new: the auto job uses the same GHCR read access as the manual deploy (Runbook 5, As built). If a test says `is not published (or this repository has no read access to the package)` for a tag that exists, check the package's **Package settings → Manage Actions access**: `iltiam-deployment` must have **Read**.

### v1: 3. Turn it on and off

The switch is a repository variable in `iltiam-deployment`, **not** a secret:

```powershell
gh variable set AUTO_DEPLOY -R iltiam/iltiam-deployment --body true    # on
gh variable set AUTO_DEPLOY -R iltiam/iltiam-deployment --body false   # off
gh variable list -R iltiam/iltiam-deployment
```

Or **Settings → Secrets and variables → Actions → Variables**. Anything but `true` (or no variable at all) is off. **Off:** the images are still built and published, the request still arrives, and the **auto** job shows as **skipped**: nothing changes. **Turn it off whenever you work on the VM by hand** (a manual `scripts/deploy.sh` and an automatic one would collide on the VM's deploy lock).

### v1: 5. Test it

In PowerShell on your laptop, in the folder that holds the four clones. **On the VM** means `ssh iltiam`, then `sudo -iu deploy`.

Helpers for this section (paste once per PowerShell window):

```powershell
function Dispatch($svc, $sha, [switch]$fail) {
  $f = @('-f', 'event_type=deploy-staging', '-f', "client_payload[service]=$svc", '-f', "client_payload[sha]=$sha")
  if ($fail) { $f += @('-F', 'client_payload[simulate_failure]=true') }
  gh api repos/iltiam/iltiam-deployment/dispatches @f
}
function Runs { gh run list -R iltiam/iltiam-deployment -w deploy -L 3 }
function Watch { gh run watch (gh run list -R iltiam/iltiam-deployment -w deploy -L 1 --json databaseId --jq '.[0].databaseId') -R iltiam/iltiam-deployment --exit-status }
$web_old = gh api repos/iltiam/iltiam-web/commits/d6049aa --jq .sha
$web_cur = gh api repos/iltiam/iltiam-web/commits/c3552ff --jq .sha
$be_old = gh api repos/iltiam/iltiam-backend/commits/d136af4 --jq .sha
$be_cur = gh api repos/iltiam/iltiam-backend/commits/8097a18 --jq .sha
```

Your own `gh` login can send a dispatch (you are an admin of this repository), so T1 to T9 need no app-repository change. Wait for each run to finish (`Watch`) before the next. **On the VM**, after each deploy:

```bash
iltiam staging ps --format 'table {{.Service}}\t{{.Image}}\t{{.Status}}'
docker inspect -f '{{.Name}} rev={{index .Config.Labels "org.opencontainers.image.revision"}} started={{.State.StartedAt}} restarts={{.RestartCount}}' $(docker ps -q --filter label=com.docker.compose.project=iltiam-staging)
docker compose ls
```

And on the laptop: `git -C iltiam-deployment pull; git -C iltiam-deployment log --oneline -5 -- env/staging.versions`.

| # | What it proves | Do | What you should see |
|---|---|---|---|
| T1 | Off means skipped | `gh variable set AUTO_DEPLOY -R iltiam/iltiam-deployment --body false`; `Dispatch web $web_cur`; `Runs` | The run is green with the **auto** job **skipped**; no new commit on `main` |
| T2 | A manual deploy still works while it's off | `gh workflow run deploy.yml -R iltiam/iltiam-deployment -f environment=staging`; `Watch` | Green, the same as Runbook 5, section 6 |
| T3 | A wrong request changes nothing | `--body true`, then `Dispatch web 1234567890123456789012345678901234567890`; `Watch` | Red at **The image is published**; no new commit |
| T4 | Same tag: health check only | `Dispatch web $web_cur`; `Watch` | Green; summary `unchanged: sha-c3552ff already runs`; health check lines `ok`; no commit |
| T5 | One service changes, the rest doesn't | `Dispatch web $web_old`; `Watch` | Green; a bot commit `deploy web sha-d6049aa (auto)`; on the VM only `web` has a new `started` time and `rev=d6049aa…`; `docker compose ls` shows no other project touched |
| T6 | **Rollback** | `Dispatch web $web_cur -fail`; `Watch` | Red. The log deploys `sha-c3552ff`, passes the health check, then **Simulated failure**, **Roll back (revert the commit)** and the second deploy; summary `FAILED, rolled back to sha-d6049aa`; two bot commits (deploy, then roll back); on the VM `web` runs `sha-d6049aa` |
| T7 | Back to normal | `Dispatch web $web_cur`; `Watch` | Green; `web` on `sha-c3552ff` again |
| T8 | **Backend: the backup** | `Dispatch backend $be_old`; `Watch` | Green; summary line `Database backup: /srv/iltiam/backups/pre-deploy/<UTC time>-backend-sha-d136af4.sql.gz`; on the VM `ls -l /srv/iltiam/backups/pre-deploy/` shows that file, `-rw------- deploy deploy`; `gzip -t <file> && echo ok` prints `ok`. (d136af4 → 8097a18 has no migration, only #122; for these minutes an SMS code fails, because d136af4 reads the Authentica key as empty) |
| T9 | Backend back, and two at once wait | `Dispatch backend $be_cur; Dispatch web $web_cur`; `Runs` | The second run says **Waiting** until the first ends; backend back on `sha-8097a18` with a second backup file; web `unchanged` |
| T10 | The whole chain, per repository | Merge the iltiam-web PR with `AUTO_DEPLOY` `false`, then `true` for the backend and ai-service PRs | Web: `web-ci`, then `web-image` with a green **deploy-staging** job, and a skipped **auto** job here (send `Dispatch web <that merge's sha>` to deploy it). Backend and AI: live on staging without you doing anything; DEP-03's target is 15 minutes for the backend |

**Keep at most 5:** after a sixth backend deploy, `ls /srv/iltiam/backups/pre-deploy/` still lists 5 files, the newest ones.

### v1: 6. When a deploy fails

**The job is red, the summary says `FAILED, rolled back to sha-…`.** Staging runs the previous version again and `main` says so. Nothing to do on the VM. Find out why in the failed step's log (and on the VM, `iltiam staging logs --tail 100 <service>`), fix it in the app repository, and merge again.

**The summary says `FAILED before anything changed`.** The image check, the backup or the push failed. `main` and the VM are as they were. Read the failed step; fix; send the request again (section 8, re-run).
- **`the backup script ended without reporting its file`:** read the lines above it (the script's own `ERROR:` line, if any), then on the VM `ls -l /srv/iltiam/backups/pre-deploy/` and `df -h /srv/iltiam`. A script sent to the VM must never run from SSH's input: that made the first T8 end silently (#16).

**The summary says `FAILED, and the rollback failed too`.** Staging may run a broken service. Turn `AUTO_DEPLOY` off (section 3), then:

1. `git -C iltiam-deployment pull` and look at `git log -p -3 env/staging.versions`: the last commit should be the bot's `roll back`. If it isn't there (the revert couldn't be pushed), open a pull request that puts the previous tag back (Runbook 5, section 9.4) and merge it.
2. Run a manual deploy of staging (Runbook 5, section 6) and read its log.
3. On the VM: `iltiam staging ps` and the service's logs.
4. If the backend's database is the problem, section 7.

**The run was cancelled** (it timed out, or a newer request replaced it while it was waiting; section 8): check `git log` and `iltiam staging ps` as above; deploy by hand if they disagree.

**Migrations never roll back by themselves.** A rollback puts the previous image back, not the previous database. Write backend migrations so the previous version still works with them: add tables and columns (nullable, or with a default) in one release, and remove them only in a later one. If an older backend can't run on the newer database, either fix forward (merge a fix) or restore the backup (section 7). The same holds for the AI service's own database (`ai-api` migrates when it starts), which has no pre-deploy backup.

### v1: 8. Day to day

- **A run cancelled while it waited.** GitHub keeps one deploy running and one waiting; a third request that arrives meanwhile replaces the waiting one, which then shows as **cancelled**. Re-run it with the same request: `gh run rerun <run id> -R iltiam/iltiam-deployment` (the id is in `Runs`).
- **The token expires.** GitHub emails you a week before. Then the **deploy-staging** job of an app's image run turns red, and the image is still published. Make a new token (2.1), set it again (2.2), then **Re-run failed jobs** on that image run (`gh run rerun <run id> --failed -R iltiam/iltiam-<repo>`): only the request is sent again, nothing is rebuilt.
- **A docs-only merge** still builds and deploys (it costs Actions minutes, the AI image most of all). To skip it, put `[skip ci]` in the squash-merge commit message: no CI, so no build.
- **Don't rename a CI workflow** (`name:` of `ci.yml` in ai-service and backend, `web-ci.yml` in web): the image workflows find it by that name, and the automatic deploy would stop without an error.
- **A deploy deploys this repository's whole `main`.** A merged change to `compose.yml` goes live with the next deploy of any service, automatic or manual.

### v1: 9. Security notes

- The request carries only a service name and a commit hash; the workflow checks both before it uses them and passes them to scripts through variables, never pasted into a command.
- The auto job can write to this repository only with its own `GITHUB_TOKEN` (dead when the job ends), and it deploys **staging only**: `set-version.sh`, `pre-deploy-backup.sh` and `health-check.sh` refuse production.
- The log is public: it shows tags, states, HTTP codes and the backup's file name, never a value, a response body, a log line or the backup's content.
