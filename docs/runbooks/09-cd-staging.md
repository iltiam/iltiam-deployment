# Runbook 9: automatic staging deploys on merge to main (health check, rollback, database backup)

- **Issue:** iltiam/iltiam-deployment#16 (DEP-03). Builds on [Runbook 5](05-compose-stack.md) (the Compose stack and the manual deploy).
- **Who:** anyone with admin rights on the four repositories (`iltiam-ai-service`, `iltiam-backend`, `iltiam-web`, `iltiam-deployment`) who can log in to `iltiam-1` (`ssh iltiam`, Runbook 1). No cloud experience needed; follow the steps in order.
- **Time:** about 30 minutes to set up (section 2), about 1 hour for the tests (section 5). After that, nothing: a merge deploys itself.
- **Result:** a merge to `main` of one of the three app repositories, with CI green, builds that exact commit, publishes it to GHCR and updates **only that service** on **staging**. The deploy checks the service's health and, if anything fails, puts the previous version back by itself. Before a backend deploy it saves a copy of the staging database. Production is never touched.

> **This repository is public. Never paste a secret into this runbook, an issue, a PR, a commit or a chat.** That includes the dispatch token, the env files on the VM, the VM's IP address, and the content of a database backup (it holds personal data).

## As built

Filled in when the steps are done. Names and dates only: never a token, an IP or a fingerprint.

| Item | Value |
|---|---|
| `DEPLOY_DISPATCH_TOKEN` created, expiry date (section 2.1) | |
| Secret set in ai-service, backend, web (section 2.2) | |
| `/srv/iltiam/backups/pre-deploy` on the VM (section 2.3) | |
| `AUTO_DEPLOY` (section 3) | |
| Tests T1 to T10 (section 5) | |

## 1. How it works

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

## 2. Set up (once)

### 2.1 The dispatch token

The app repositories need permission to start a workflow here. That is a fine-grained personal access token that can do exactly one thing: write to `iltiam-deployment`.

1. GitHub → your picture → **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token.**
2. **Token name:** `iltiam deploy-staging dispatch`. **Resource owner:** `iltiam`.
3. **Expiration:** a custom date after the project ends (for example 2027-01-31), or the longest the organisation allows. Write the date in As built.
4. **Repository access:** **Only select repositories → `iltiam-deployment`**. Nothing else.
5. **Permissions → Repository permissions → Contents: Read and write.** GitHub adds **Metadata: Read-only** by itself. Nothing else: this is the minimum GitHub accepts for a `repository_dispatch`.
6. **Generate token.** Copy it once; you'll paste it in 2.2 and then never need it again.
7. If the organisation requires approval: organisation **Settings → Personal access tokens → Pending requests → Approve**.

**What it can do:** start this workflow, and write to this repository (which is public and its `main` unprotected), so treat it like a password.

### 2.2 The secret in the three app repositories

The same token, as a **repository** secret in each (on GitHub Free, private repositories can't read organisation secrets). In PowerShell, on your laptop; each command asks for the value and doesn't show it:

```powershell
gh secret set DEPLOY_DISPATCH_TOKEN -R iltiam/iltiam-ai-service
gh secret set DEPLOY_DISPATCH_TOKEN -R iltiam/iltiam-backend
gh secret set DEPLOY_DISPATCH_TOKEN -R iltiam/iltiam-web
gh secret list -R iltiam/iltiam-web
```

**What you should see:** `DEPLOY_DISPATCH_TOKEN` in the list, with today's date. Never a value.

### 2.3 The backup folder on the VM

As `ubuntu` on the VM (`ssh iltiam`):

```bash
sudo install -d -m 700 -o deploy -g deploy /srv/iltiam/backups /srv/iltiam/backups/pre-deploy
sudo stat -c '%a %U:%G %n' /srv/iltiam/backups /srv/iltiam/backups/pre-deploy
df -h /srv/iltiam
```

**What you should see:** `700 deploy:deploy` twice, and more than 1 GB free (the backup refuses to run with less, because the database lives on the same volume).

### 2.4 Package access

Nothing new: the auto job uses the same GHCR read access as the manual deploy (Runbook 5, As built). If a test says `is not published (or this repository has no read access to the package)` for a tag that exists, check the package's **Package settings → Manage Actions access**: `iltiam-deployment` must have **Read**.

## 3. Turn it on and off

The switch is a repository variable in `iltiam-deployment`, **not** a secret:

```powershell
gh variable set AUTO_DEPLOY -R iltiam/iltiam-deployment --body true    # on
gh variable set AUTO_DEPLOY -R iltiam/iltiam-deployment --body false   # off
gh variable list -R iltiam/iltiam-deployment
```

Or **Settings → Secrets and variables → Actions → Variables**. Anything but `true` (or no variable at all) is off. **Off:** the images are still built and published, the request still arrives, and the **auto** job shows as **skipped**: nothing changes. **Turn it off whenever you work on the VM by hand** (a manual `scripts/deploy.sh` and an automatic one would collide on the VM's deploy lock).

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

## 6. When a deploy fails

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

## 7. Restore from a pre-deploy backup

Each automatic backend deploy saves the staging database `iltiam` just before it:
`/srv/iltiam/backups/pre-deploy/<UTC time>-backend-sha-<7>.sql.gz` (mode 600, owner `deploy`; the newest 5 are kept). `sha-<7>` is the build that **was about to be deployed**: the file holds the database as the backend **before** it used it, so it belongs with the tag that ran before (`git log -p env/staging.versions`).

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

- **A run cancelled while it waited.** GitHub keeps one deploy running and one waiting; a third request that arrives meanwhile replaces the waiting one, which then shows as **cancelled**. Re-run it with the same request: `gh run rerun <run id> -R iltiam/iltiam-deployment` (the id is in `Runs`).
- **The token expires.** GitHub emails you a week before. Then the **deploy-staging** job of an app's image run turns red, and the image is still published. Make a new token (2.1), set it again (2.2), then **Re-run failed jobs** on that image run (`gh run rerun <run id> --failed -R iltiam/iltiam-<repo>`): only the request is sent again, nothing is rebuilt.
- **A docs-only merge** still builds and deploys (it costs Actions minutes, the AI image most of all). To skip it, put `[skip ci]` in the squash-merge commit message: no CI, so no build.
- **Don't rename a CI workflow** (`name:` of `ci.yml` in ai-service and backend, `web-ci.yml` in web): the image workflows find it by that name, and the automatic deploy would stop without an error.
- **A deploy deploys this repository's whole `main`.** A merged change to `compose.yml` goes live with the next deploy of any service, automatic or manual.

## 9. Security notes

- The request carries only a service name and a commit hash; the workflow checks both before it uses them and passes them to scripts through variables, never pasted into a command.
- The auto job can write to this repository only with its own `GITHUB_TOKEN` (dead when the job ends), and it deploys **staging only**: `set-version.sh`, `pre-deploy-backup.sh` and `health-check.sh` refuse production.
- The log is public: it shows tags, states, HTTP codes and the backup's file name, never a value, a response body, a log line or the backup's content.
