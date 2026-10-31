# Runbook 5: staging and production as two Compose projects on one ARM VM (memory budget, private AI)

- **Issue:** iltiam/iltiam-deployment#2 (DEP#2). **Decision record:** [ADR-0004](../adr/0004-hosting.md), Decisions 2 and 3.
- **Who:** anyone on the team who can log in to `iltiam-1` as `ubuntu` (`ssh iltiam`, Runbook 1) and has admin rights on `iltiam/iltiam-deployment`. No cloud experience needed; follow the steps in order.
- **Time:** about 2.5 hours the first time: 45 minutes to prepare the VM and GitHub, 20 minutes for the first staging deploy, about 1.5 hours of checks. A later deploy takes about 5 minutes.
- **Result:**
  - two Compose projects on `iltiam-1`, **`iltiam-staging`** and **`iltiam-prod`**, from one [`compose.yml`](../../compose.yml);
  - each with its own Postgres (databases `iltiam` and `iltiam_ai`), Redis, AI service, `cloudflared` and, on staging for now, the backend;
  - **no published port**, and the AI service on a network the tunnel can't reach;
  - a memory limit on every container, sized so both environments fit in 12 GB;
  - a deploy started by hand from GitHub (**Actions → deploy**), which never puts a secret in this repository or on a command line.
- **Scope for now: staging only**, for testing and the demo. Production moves to a later issue; its sections (5 for production, 8, 11.2, and the production lines elsewhere) stay here for then, but are not done now.

> **This repository is public. Never paste a secret into this runbook, an issue, a PR, a commit or a chat.** That includes the env files on the VM, the deploy keys, the VM's IP address, the tunnel ID and the output of `docker compose config` (it prints every secret). Use the placeholders below. **Only ever run `config` with `--quiet`**; `scripts/compose.sh` refuses it otherwise.

| Placeholder | Meaning |
|---|---|
| `<PUBLIC_IP>` | The VM's public IPv4 address (Runbook 1, section 6.2) |
| `<ENV>` | `staging` or `production` |

The Compose project names are `iltiam-staging` and `iltiam-prod`; the folders and GitHub Environments are `staging` and `production`.

## As built

Filled in when the steps are done. Names, versions and dates only: never an IP, a key, a token or a fingerprint.

| Item | Value |
|---|---|
| Docker waits for `/srv/iltiam` (section 4.1) | |
| Directories and modes (section 4.2) | |
| Repository clone `/srv/iltiam/repo` (section 4.3) | |
| Docker and Compose versions on the VM (section 4.4) | Docker 29.9.2, Docker Compose v5.6.1 (2026-10-31) |
| Deploy keys, one per environment (section 5.1) | |
| `DEPLOY_SSH_KNOWN_HOSTS`, `DEPLOY_HOST` (sections 5.2, 5.3) | |
| GHCR access for `iltiam-deployment` (Runbook 4, section 8) | `iltiam-ai-api`, `iltiam-ai-worker`: Read, proven by the 2026-10-31 pull. `iltiam-backend`: Read under **Manage Actions access**, proven by the 2026-10-31 backend deploy (a first grant under Codespaces access gave `denied`; Runbook 4, section 8) |
| Images deployed on staging (`env/staging.versions`) | 2026-10-31: `iltiam-ai-api` and `iltiam-ai-worker` `sha-0d1861e`; `iltiam-backend` `sha-4b5251d`, `COMPOSE_PROFILES=backend` |
| Images deployed on production (`env/production.versions`) | |
| Idle memory, both projects (section 9.5) | Staging complete, 2026-10-31, before any analysis: **2173 MiB** (`ai-api` 608, `ai-worker` 663, `ai-beat` 297, `backend-web` 234, `backend-worker` 204, `backend-beat` 114, `postgres` 32, `redis` 5, `cloudflared` 16); `free -h`: 2.9 GiB used, 8.7 GiB available. Earlier the same day, AI-only: 1615 MiB, 2.2 GiB used. Production isn't running yet (#36) |
| AI worker peak during one analysis (section 11.4) | |

## 1. How it works

**The VM has two names.** In the OCI console it is the instance **`iltiam-vm`** (**Compute → Instances**). Its hostname, the name in its prompt and in `hostnamectl`, is **`iltiam-1`**, and this runbook uses that one.

**Staging started AI-only.** The first staging deploy (2026-10-31) ran with `COMPOSE_PROFILES=` (empty): `cloudflared`, Postgres, Redis, `weights-init` and the AI service, while `staging-api.iltiamcare.com` answered 502. iltiam-backend#99 then published the backend image (`sha-4b5251d`, iltiam-backend PR #101, which also carries #80's storage fix), and `env/staging.versions` now has that tag and `COMPOSE_PROFILES=backend`. The steps below still mark what differs while staging is AI-only, for a rollback to it (section 9.4).

```
iltiam-1  (Ampere A1, arm64, 2 OCPU / 12 GB + 4 GB swap; only port 22 open)
  /srv/iltiam                         the 100 GB data volume (Runbook 1, section 10)
    repo/                             this repository (public clone), at the commit being deployed
    env/staging/  env/production/     infra.env, ai.env, backend.env: written by the deploy workflow (700 / 600)
    staging/{postgres,redis}/         each environment's data
    production/{postgres,redis}/
    weights/                          the AI model files, shared, read-only for the AI containers

  Compose project iltiam-staging                     Compose project iltiam-prod (the same file)
    edge      cloudflared ──▶ backend-web              cloudflared  (backend-web once its profile is on)
    internal  postgres, redis, ai-api, ai-worker,      postgres, redis, ai-api, ai-worker, ai-beat
              ai-beat, backend-web, -worker, -beat
    egress    weights-init, ai-worker, backend-worker  weights-init, ai-worker
```

**Two projects, one file.** The same `compose.yml` runs both environments. What differs comes from outside it:

| | Comes from | Public? |
|---|---|---|
| Project name | `scripts/compose.sh`: `iltiam-staging` or `iltiam-prod` | yes |
| Image tags, which services run | [`env/<ENV>.versions`](../../env/) in this repository | yes |
| Secrets and settings | `/srv/iltiam/env/<ENV>/*.env` on the VM, written from the GitHub Environment ([Runbook 4](04-secrets.md)) | **no** |
| Data | `/srv/iltiam/<ENV>/` on the VM | **no** |

The two projects share only the weights folder. Each has its own containers, networks, database, Redis, tunnel and secrets, so stopping or breaking staging never touches production.

**Three networks per project:**

| Network | Who is on it | Why |
|---|---|---|
| `edge` | `cloudflared`, `backend-web` (and `web` with WEB-03) | The tunnel reaches only what is here. The AI service, Postgres and Redis are not, so `cloudflared` can't even resolve their names |
| `internal` | everything except `cloudflared` and `weights-init` | `internal: true`: no route out of the VM. The services talk to each other here |
| `egress` | `weights-init` (GitHub), `ai-worker` (mask upload to object storage), `backend-worker` (storage, Authentica, FCM, SMTP) | Outbound only, for what must call the internet. `backend-web` goes out through `edge` |

**No `ports:`.** Nothing listens on the VM's public address except SSH. The internet reaches the apps only through the tunnel ([Runbook 3](03-cloudflare-tunnels.md), section 10).

**What runs where:**

| Service | What it is | staging | production now |
|---|---|---|---|
| `cloudflared` | the tunnel connector ([Runbook 3](03-cloudflare-tunnels.md)) | yes | yes |
| `postgres` | Postgres 16; roles and databases `iltiam` (backend) and `iltiam_ai` (AI service) | yes | yes |
| `redis` | Redis 7; backend databases 0 and 2, AI service 3 to 5 | yes | yes |
| `weights-init` | one-shot: downloads the model files the AI image's registry lists, if missing | yes | yes |
| `ai-api`, `ai-worker`, `ai-beat` | the AI service: 1 gunicorn process, 1 Celery process, the scheduler | yes | yes |
| `backend-migrate` | one-shot: database migrations | yes (`sha-4b5251d`) | after DEP-13, DEP-14 and SMTP |
| `backend-web`, `backend-worker`, `backend-beat` | the API, its Celery worker, its scheduler | yes (`sha-4b5251d`) | after DEP-13, DEP-14 and SMTP |
| `web` | the web app | after WEB-03 | after WEB-03 |

**Why production has no backend yet:** the production settings refuse to start with the console SMS, push and email backends. They need Firebase (Runbook 11, DEP-13), Authentica (Runbook 12, DEP-14) and the SMTP provider (Runbook 2, section 11). Until then `env/production.versions` leaves the `backend` profile off, and `api.iltiamcare.com` answers 502.

**A deploy, step by step** ([`.github/workflows/deploy.yml`](../../.github/workflows/deploy.yml)):

1. On GitHub's runner, [`scripts/render-deploy-env.sh`](../../scripts/render-deploy-env.sh) writes the env files from the Environment's secrets and variables. GitHub never shows a secret again, so this is the only way they reach the VM.
2. [`scripts/remote-deploy.sh`](../../scripts/remote-deploy.sh) logs in to the VM as `deploy` with the environment's own SSH key. It:
   - checks out the workflow's commit in `/srv/iltiam/repo`;
   - copies the env files into `/srv/iltiam/env/<ENV>/` (over SSH's input, never on a command line);
   - logs in to GHCR with the job's own short-lived token.
3. [`scripts/deploy.sh`](../../scripts/deploy.sh) on the VM:
   - checks everything it can (section 13 lists its messages);
   - pulls the images;
   - starts Postgres and Redis;
   - runs the one-shots (`weights-init`, `backend-migrate`);
   - starts the rest in order, waiting for each to be healthy;
   - prints what runs.
4. The workflow logs out of GHCR, whatever happened.

Running a deploy again with the same tags changes nothing: no running container is recreated.

## 2. Memory budget

12 GB of RAM (about 11.2 GiB; `free -h` shows about `11Gi`) and 4 GiB of swap for two environments, monitoring (Runbook 7, #10) and the system. Every container has a `mem_limit`: a container that goes over it is stopped by the kernel ("OOMKilled") and restarted, instead of slowing down the whole VM. `scripts/check-compose.sh` fails CI if a service has none.

All figures in MiB and GiB, the units `docker stats` shows. **Idle** is measured or expected use after start-up; **budget** is the rounded figure issue #2 plans with.

| Service | `mem_limit` | Idle | Budget |
|---|---|---|---|
| `cloudflared` | 128 MiB | about 30 MiB | 0.1 GiB, with `web` |
| `postgres` (`shared_buffers=128MB`) | 384 MiB | about 100 MiB | 0.3 GiB |
| `redis` (`maxmemory 128mb`) | 192 MiB | about 10 MiB | 0.1 GiB |
| `ai-api` (1 gunicorn process) | 1024 MiB | **616 MiB** measured | 0.6 GiB |
| `ai-worker` (1 Celery process) | 1536 MiB | **1004 MiB** measured; peak during an analysis: section 11.4 | 1.0 GiB |
| `ai-beat` | 384 MiB | **293 MiB** measured | 0.3 GiB |
| `backend-web` (2 gunicorn workers) | 512 MiB | about 250 MiB | 0.4 GiB |
| `backend-worker` (2 Celery processes) | 640 MiB | about 300 MiB | 0.4 GiB, with `backend-beat` |
| `backend-beat` | 192 MiB | about 100 MiB | |
| `web` (with WEB-03) | 64 MiB | about 10 MiB | |
| One-shots: `weights-init` 512 MiB, `backend-migrate` 384 MiB | | exit after a few seconds, one at a time | |
| **AI service** (`ai-api`, `ai-worker`, `ai-beat`) | **2944 MiB** | **1913 MiB (1.9 GiB)** | **1.9 GiB** |
| **One environment, complete** | **5056 MiB (4.9 GiB)** | **2713 MiB (2.65 GiB)** | **3.2 GiB** |
| **Staging AI-only** (section 1, until the backend deploy) | **3648 MiB (3.6 GiB)** | **2053 MiB (2.0 GiB)**; **1615 MiB** measured on the VM | **2.4 GiB** |

The measured figures are from iltiam-ai-service#154 (native arm64, after `/ready` and one analysis, 1 process each); section 9.5 measures them on the VM. **On the VM, 2026-10-31** (staging AI-only, before any analysis): `ai-api` 608 MiB, `ai-worker` 663 MiB, `ai-beat` 297 MiB, `postgres` 26 MiB, `redis` 5 MiB, `cloudflared` 16 MiB, **1615 MiB** in all. The worker loads its models at its first analysis, so it is still below #154's 1004 MiB. With the backend on (same day): `backend-web` 234 MiB, `backend-worker` 204 MiB, `backend-beat` 114 MiB, `postgres` 32 MiB, **2173 MiB** for the whole staging project, under the 2713 MiB expected for a complete environment. `ai-beat` already uses 77 % of its 384 MiB limit: watch it in section 9.5, and raise its `mem_limit` by a pull request if it nears 350 MiB.

- **Budget, both environments complete:** 2 × 3.2 GiB, plus monitoring (about 1 GiB, #10) and the system (about 0.5 GiB): **about 7.9 GiB** of 11.2. Issue #2's first budget said 3.8 per environment and about 9 in total, with 1.2 for the AI api, 1.3 for the worker and no line for the beat; the measurements came in lower.
- **Peak:** the AI worker's peak during an analysis isn't measured yet (section 11.4). Its `mem_limit` caps it at 1.5 GiB, so both workers analysing at once add at most about 1 GiB: **about 8.9 GiB**.
- **Idle, both environments complete:** about 5.3 GiB of containers (section 9.5 measures it), under the 10 GiB the issue allows.
- **Limits are ceilings, not reservations.** Their total for two complete environments (10112 MiB, 9.9 GiB), plus monitoring and the system, is more than the 11.2 GiB of RAM. It is only reached if everything peaks at once; swap absorbs the rest.
- **Production first.** When memory is short (`free -h` shows little "available", or section 9.5 shows the total near 10 GB), stop the **staging** AI worker, never production's (section 9.6). It holds about 1 GB, and staging analyses simply wait in the queue.
- **CPU:** there are only 2 cores. When staging and production analyse at the same moment, both get slower. The same rule applies: stop the staging AI worker while production is busy.

## 3. Before you start

1. **Done already:** [Runbook 1](01-oci-account-and-vm.md) (the VM, `ssh iltiam` works, the data volume at `/srv/iltiam`), [Runbook 2](02-cloudflare-dns-tls.md), [Runbook 3](03-cloudflare-tunnels.md) (the two tunnels and `CF_TUNNEL_TOKEN`) and [Runbook 4](04-secrets.md) (the GitHub Environments and the generated secrets).
2. **[Runbook 8](08-object-storage.md) (#13, object storage) before the first staging deploy.** Staging's storage part is done. The staging backend needs its storage key, endpoint and bucket names (Runbook 8, section 11): the deploy refuses to write `backend.env` without them, and the backend's `/api/ready/` checks every bucket. The backend image must also include iltiam-backend#80's boto3 checksum setting, or every upload fails with `501` (Runbook 8, section 13); `sha-4b5251d` and later do. While staging is AI-only, only `MASK_UPLOAD_ALLOWED_HOSTS` (in `ai.env`) is needed.
3. **Every required secret and variable is in GitHub.** Set the variables of [Runbook 4](04-secrets.md), section 9, including `NUM_PROXIES=1`, and the secret `WEIGHTS_READ_TOKEN` (`docs/secrets.md`, section 6.6). Then run the two `comm` commands of Runbook 4, section 10.2, for `staging`. **They must print nothing.** `web.env`'s two variables can wait for WEB-03.
   - **While staging is AI-only**, only `infra.env` and `ai.env` are written, so only their values are needed: the secrets `CF_TUNNEL_TOKEN`, `POSTGRES_PASSWORD`, `BACKEND_DB_PASSWORD`, `AI_DB_PASSWORD`, `WEIGHTS_READ_TOKEN`, `DJANGO_SECRET_KEY`, `AI_SERVICE_TOKEN` and `MASK_UPLOAD_ALLOWED_HOSTS`, and the variables `ALLOW_SYNC=0`, `AI_API_WORKERS=1`, `AI_WORKER_CONCURRENCY=1` and `ILTIAM_TISSUE_ENABLED=0`. The backend's values (including `NUM_PROXIES` and `ACTIVATION_LINK_BASE_URL`) are needed once `COMPOSE_PROFILES=backend`; staging has them since 2026-10-31.
4. **The images are published, and their tags are in this repository:**
   - **AI service:** `sha-0d1861e` (published 2026-10-29 for linux/arm64 and linux/amd64), the first build that honours `ILTIAM_TORCH_THREADS`. Both versions files hold it.
   - **Backend:** `sha-4b5251d` (published 2026-10-31 for linux/arm64 and linux/amd64 by iltiam-backend PR #101: #99's image and #80's storage fix). Only `env/staging.versions` holds it; production keeps `to-confirm` until its backend is turned on (#36).
   - Check each tag has an arm64 build, in Git Bash: `docker manifest inspect ghcr.io/iltiam/iltiam-ai-api:sha-<7> | grep -c arm64` prints `1` or more. (Private packages need `docker login ghcr.io` with your own account first; `docker logout ghcr.io` afterwards.) Without Docker, ask GHCR's API with your `gh` login; it prints the platforms, including `linux/arm64`:

     ```bash
     IMAGE=iltiam/iltiam-backend TAG=sha-4b5251d
     TOKEN=$(curl -s -u "x:$(gh auth token)" "https://ghcr.io/token?scope=repository:$IMAGE:pull" | jq -r .token)
     curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.oci.image.index.v1+json" \
       "https://ghcr.io/v2/$IMAGE/manifests/$TAG" | jq -r '.manifests[].platform | "\(.os)/\(.architecture)"'
     unset TOKEN
     ```

     `unknown/unknown` lines are the image's SBOM and provenance attestations.
   - Put the tags into `env/staging.versions` and `env/production.versions` by a pull request, and merge it. **`scripts/deploy.sh` refuses `to-confirm`** for any service it would start.
5. **GHCR access:** each package (`iltiam-ai-api`, `iltiam-ai-worker`, `iltiam-backend`) grants `iltiam-deployment` the **Read** role ([Runbook 4](04-secrets.md), section 8).
6. **This runbook's pull request is merged into `main`.** The Environments deploy only from `main`, and GitHub shows **Run workflow** only for workflows on the default branch.
7. On your laptop: **Git Bash** with `gh auth status` "Logged in", and **PowerShell** for `curl.exe`. For the checks from outside, use a **phone hotspot**, not the King Saud University network ([Runbook 3](03-cloudflare-tunnels.md), section 14).

## 4. Prepare the VM (once)

Log in as `ubuntu`: `ssh iltiam`. Every command in this section runs there.

### 4.1 Docker waits for the data volume

`/srv/iltiam` is mounted with `nofail` (Runbook 1, section 10.2), so the VM still boots without it. Docker would then start the containers anyway, create **empty** data folders on the boot disk, and Postgres would start a **new, empty database** there. This makes Docker refuse to start until the volume is mounted:

```bash
sudo install -d /etc/systemd/system/docker.service.d
printf '[Unit]\nRequiresMountsFor=/srv/iltiam\n' | sudo tee /etc/systemd/system/docker.service.d/10-iltiam-data.conf
sudo systemctl daemon-reload
systemctl show docker -p RequiresMountsFor
```

**What you should see:** the `printf` line echoed back, then `RequiresMountsFor=/srv/iltiam` (other paths may be listed next to it).

`scripts/deploy.sh` checks the same thing on every deploy: it stops with `/srv/iltiam is not mounted` if the volume is missing.

### 4.2 Folders

```bash
sudo install -d -m 700 -o deploy -g deploy /srv/iltiam/env /srv/iltiam/env/staging /srv/iltiam/env/production
sudo install -d -m 755 /srv/iltiam/staging /srv/iltiam/production
sudo install -d -m 700 /srv/iltiam/staging/postgres /srv/iltiam/staging/redis \
  /srv/iltiam/production/postgres /srv/iltiam/production/redis
sudo install -d -m 755 -o 1000 -g 1000 /srv/iltiam/weights
sudo install -d -m 755 -o deploy -g deploy /srv/iltiam/repo
sudo stat -c '%a %U:%G %n' /srv/iltiam/env /srv/iltiam/env/* /srv/iltiam/staging/* /srv/iltiam/production/* \
  /srv/iltiam/weights /srv/iltiam/repo
```

**What you should see:**

```
700 deploy:deploy /srv/iltiam/env
700 deploy:deploy /srv/iltiam/env/production
700 deploy:deploy /srv/iltiam/env/staging
700 root:root /srv/iltiam/staging/postgres
700 root:root /srv/iltiam/staging/redis
700 root:root /srv/iltiam/production/postgres
700 root:root /srv/iltiam/production/redis
755 ubuntu:ubuntu /srv/iltiam/weights
755 deploy:deploy /srv/iltiam/repo
```

- **The data folders change owner** on the first start: the Postgres and Redis containers give them to their own users (uid 70 and 999). That is normal.
- **`weights` is uid 1000**, the AI containers' user. On Ubuntu that is also `ubuntu`, so `stat` shows `ubuntu:ubuntu`.
- **Never delete or move anything under `/srv/iltiam/<ENV>/`:** that is the environment's database.

### 4.3 The repository

The VM keeps a clone of this (public) repository. The deploy checks out the exact commit it deploys, so the VM never runs a Compose file that isn't in Git.

```bash
command -v git || sudo apt-get install -y git
sudo -u deploy git clone https://github.com/iltiam/iltiam-deployment.git /srv/iltiam/repo
sudo -u deploy git -C /srv/iltiam/repo log --oneline -1
```

**What you should see:** `Cloning into '/srv/iltiam/repo'...`, then the latest commit of `main`.

**Never edit files in `/srv/iltiam/repo`.** A local change makes the next deploy fail at the checkout. Change the repository by a pull request instead.

### 4.4 The `deploy` user and Docker

```bash
sudo -u deploy docker version --format 'docker {{.Server.Version}}'
sudo -u deploy docker compose version
```

**What you should see:** `docker 2x.y.z` and `Docker Compose version v2.x.y` (or newer). Write both versions in the As built table. `scripts/deploy.sh` needs Compose 2.20 or newer, and prints the version on every deploy.

If it says `permission denied while trying to connect to the Docker daemon`: `deploy` is not in the `docker` group. Run `sudo usermod -aG docker deploy` (Runbook 1's bootstrap does this), then try again.

**A shortcut for later** (sections 7 to 11). As `deploy`, once:

```bash
sudo -iu deploy
echo "alias iltiam='bash /srv/iltiam/repo/scripts/compose.sh'" >> ~/.bashrc
exit
```

From then on, after `sudo -iu deploy`, `iltiam staging ps` is the same as `bash /srv/iltiam/repo/scripts/compose.sh staging ps`. [`scripts/compose.sh`](../../scripts/compose.sh) adds the project name, the env files and the paths for you. **Always use it instead of plain `docker compose`.**

## 5. GitHub: the deploy key and the VM's address (once per environment)

Each environment has its **own** SSH key, so staging and production never share a credential ([Runbook 4](04-secrets.md), rule 3). Both log in as `deploy`.

### 5.1 Deploy keys

1. On your laptop, in **Git Bash**, make the staging key. It has no passphrase, because the workflow uses it unattended:

   ```bash
   ssh-keygen -t ed25519 -N "" -C "iltiam-deploy-staging" -f ~/iltiam-deploy-staging
   gh secret set DEPLOY_SSH_KEY --env staging -R iltiam/iltiam-deployment < ~/iltiam-deploy-staging
   scp ~/iltiam-deploy-staging.pub iltiam:/tmp/
   ```

   **What you should see:** `Your identification has been saved…`, `✓ Set Actions secret DEPLOY_SSH_KEY for iltiam/iltiam-deployment`, then the `scp` line.

2. On the VM (`ssh iltiam`), add the public key to `deploy`'s keys. `restrict` turns off port forwarding, agent forwarding and terminals for this key; commands still work:

   ```bash
   sudo install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
   printf 'restrict %s\n' "$(cat /tmp/iltiam-deploy-staging.pub)" | sudo tee -a /home/deploy/.ssh/authorized_keys >/dev/null
   sudo chown deploy:deploy /home/deploy/.ssh/authorized_keys
   sudo chmod 600 /home/deploy/.ssh/authorized_keys
   rm /tmp/iltiam-deploy-staging.pub
   sudo grep -c 'iltiam-deploy-' /home/deploy/.ssh/authorized_keys
   ```

   **What you should see:** `1` (after the production key in step 4: `2`).

3. Back on the laptop, test the key, then **delete it**. GitHub now holds the only copy; if it is ever lost, make a new one.

   ```bash
   ssh -i ~/iltiam-deploy-staging -o IdentitiesOnly=yes deploy@<PUBLIC_IP> docker compose version
   rm ~/iltiam-deploy-staging ~/iltiam-deploy-staging.pub
   ```

   **What you should see:** `Docker Compose version v2.x.y`. The first time, SSH asks whether to trust the host: compare with section 5.2 step 1 before you type `yes`.

4. Repeat steps 1 to 3 with `production` instead of `staging` everywhere (`iltiam-deploy-production`, `--env production`). **Not now:** production comes with its own issue (scope, at the top).

### 5.2 The VM's host key (`DEPLOY_SSH_KNOWN_HOSTS`)

The workflow refuses to connect to a host whose key it doesn't know, so nobody can pretend to be the VM.

1. On the VM, the real fingerprint:

   ```bash
   ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
   ```

2. On the laptop (Git Bash), fetch the key over the network and compare:

   ```bash
   ssh-keyscan -t ed25519 <PUBLIC_IP> 2>/dev/null > ~/iltiam-known-hosts
   ssh-keygen -lf ~/iltiam-known-hosts
   ```

   **What you should see:** the **same** `SHA256:…` fingerprint as in step 1. If it differs, **stop**: you are not talking to the VM.
3. Store it in both Environments, then delete the file. For now, staging only: leave out the `production` line.

   ```bash
   gh secret set DEPLOY_SSH_KNOWN_HOSTS --env staging -R iltiam/iltiam-deployment < ~/iltiam-known-hosts
   gh secret set DEPLOY_SSH_KNOWN_HOSTS --env production -R iltiam/iltiam-deployment < ~/iltiam-known-hosts
   rm ~/iltiam-known-hosts
   ```

It is a secret only because the line contains the VM's address, which this public repository never shows.

### 5.3 The VM's address (`DEPLOY_HOST`)

```bash
gh secret set DEPLOY_HOST --env staging -R iltiam/iltiam-deployment
gh secret set DEPLOY_HOST --env production -R iltiam/iltiam-deployment
```

Each asks for the value: type `<PUBLIC_IP>`, Enter. For now, staging only: leave out the `production` line.

### 5.4 Check

```bash
for e in staging production; do echo "== $e"; gh secret list --env $e -R iltiam/iltiam-deployment --json name -q '.[].name' | grep '^DEPLOY_'; done
```

**What you should see:** `DEPLOY_HOST`, `DEPLOY_SSH_KEY` and `DEPLOY_SSH_KNOWN_HOSTS` under each environment (for now under `staging` only; `production` lists nothing). Then run Runbook 4, section 10.2 once more for the environments you set up: it must print nothing.

## 6. Deploy staging

1. Check that `env/staging.versions` on `main` has published tags, not `to-confirm` (section 3, step 4).
2. github.com → **iltiam/iltiam-deployment → Actions → deploy** (left list) **→ Run workflow.**
   - **Use workflow from:** `main`.
   - **environment:** `staging`.
   - **Run workflow.**
3. Open the run (it appears at the top of the list within a few seconds) **→ Deploy staging**.

**What you should see** in the **Deploy over SSH** step. The first deploy takes 10 to 15 minutes, mostly pulling about 1 GB of images and downloading the model files:

- `==> connect`, `==> repository at <7 characters>`;
- `==> env files` with `ai.env (600)`, `backend.env (600)`, `infra.env (600)`;
- `==> GHCR`, `logged in`;
- `==> guards (staging)` with `ok:` lines;
- `==> docker compose version` with both versions;
- `==> pull`;
- `==> postgres and redis`, both `Healthy`;
- `==> weights-init`: the first time, `segformer_b2_wound: ok, sha256 verified`; afterwards `up to date, skipping`;
- `==> backend-migrate`: the first time, a long list of `Applying …`; afterwards `No migrations to apply`;
- `==> start: ai-api backend-web`, then `==> start: ai-worker ai-beat cloudflared backend-worker backend-beat`, each container `Healthy` or `Started`;
- `==> running in this project`: a table with every service `Up … (healthy)` (`ai-beat` shows only `Up`, because it has no health check); then the digest of each image;
- `==> deployed staging`, and a green check on the run.

**While staging is AI-only** (section 1): `==> env files` lists only `ai.env (600)` and `infra.env (600)`, there is no `==> backend-migrate`, the starts are `ai-api`, then `ai-worker ai-beat cloudflared`, and the table has six services.

**If it fails:** the last `ERROR:` line says what to do; section 13 lists them. Nothing is half-deployed by a failed guard or one-shot: the services that were running keep running.

## 7. Check staging

On the VM: `ssh iltiam`, then `sudo -iu deploy` (section 4.4 for the `iltiam` shortcut).

### 7.1 Every container is up

```bash
iltiam staging ps --format 'table {{.Service}}\t{{.Status}}'
```

**What you should see:** nine services. `ai-beat` says `Up …`; the other eight say `Up … (healthy)`. The one-shots don't appear: they ran and were removed. **While staging is AI-only:** six services (`cloudflared`, `postgres`, `redis`, `ai-api`, `ai-worker` healthy, `ai-beat` Up).

### 7.2 Files and ports

```bash
stat -c '%a %n' /srv/iltiam/env/staging /srv/iltiam/env/staging/*
docker ps --format '{{.Names}}  {{.Ports}}'
```

**What you should see:**
- `700` for the folder, `600` for `ai.env`, `backend.env` and `infra.env` (`644` only for `fcm-service-account.json`, after Runbook 11).
- No line with `0.0.0.0:` or `[::]:`. Lines may show internal ports like `8000/tcp`, which aren't published.

**Never `cat` the env files**, and never copy them off the VM.

### 7.3 The backend through the tunnel

From your laptop (PowerShell, on a phone hotspot):

```powershell
curl.exe -s https://staging-api.iltiamcare.com/api/health/
curl.exe -s https://staging-api.iltiamcare.com/api/ready/
```

**What you should see:** `{"status": "ok"}`, then `"status": "ready"` with `db`, `redis`, `storage` and `ai` all `ok`. A `503` names what is failing: `storage` means Runbook 8's keys, endpoint or buckets ([Runbook 8](08-object-storage.md), sections 13 and 16), `ai` means the AI service isn't ready yet (section 7.4).

**While staging is AI-only:** both answer **502** (the tunnel runs, there is no backend behind it). That is expected; do this check once the backend is on.

### 7.4 The AI service, from inside the project

The AI service has no hostname and no route, so check it from the backend's container, the way the backend calls it:

```bash
iltiam staging exec backend-web python -c "import urllib.request as u; print(u.urlopen('http://ai-api:8000/ready', timeout=5).read().decode())"
iltiam staging exec backend-web python -c "import json, urllib.request as u; c = json.load(u.urlopen('http://ai-api:8000/capabilities', timeout=5)); print(json.dumps(c, indent=1)[:1500])"
ls -l /srv/iltiam/weights
```

**While staging is AI-only** there is no `backend-web`: ask `ai-api` itself, at `127.0.0.1`:

```bash
iltiam staging exec ai-api python -c "import urllib.request as u; print(u.urlopen('http://127.0.0.1:8000/ready', timeout=5).read().decode())"
iltiam staging exec ai-api python -c "import json, urllib.request as u; c = json.load(u.urlopen('http://127.0.0.1:8000/capabilities', timeout=5)); print(json.dumps(c, indent=1)[:1500])"
ls -l /srv/iltiam/weights
```

**What you should see:**
- `/ready`: `"status": "ready"`, with `models` and `redis` `ok`.
- `/capabilities`: the segmentation model `segformer_b2_wound` with a SHA-256 starting `382ce77d`, the one in the AI image's `models/registry.yaml`.
- `/srv/iltiam/weights`: `segformer_b2_wound_v2.pth` (about 110 MB) and the tissue model file.

iltiam-ai-service#143 (the image on the VM) was closed on 2026-10-31 on the healthy containers and the downloaded weights. Add these three results there as a comment.

### 7.5 Two torch threads

```bash
iltiam staging logs ai-worker ai-api | grep "torch intra-op threads"
```

**What you should see:** `torch intra-op threads: 2 (requested 2; …)`, once per process that has loaded its models (the worker after its first analysis, section 11.4).
- With an image older than `sha-0d1861e` (for example `sha-42270dc`, 0.1.0, after a rollback) there is no such line: those predate `ILTIAM_TORCH_THREADS` and use 4 threads.

## 8. Deploy production

**Not now.** For now only staging runs (scope, at the top); production moves to a later issue, which follows this section.

Production runs `postgres`, `redis`, `weights-init`, the AI service and `cloudflared`: `env/production.versions` has `COMPOSE_PROFILES=` (empty) until DEP-13, DEP-14 and SMTP are done (section 1).

1. **Actions → deploy → Run workflow**: branch `main`, environment **`production`** → **Run workflow.**
2. The run waits with **Waiting for review**. Open it **→ Review deployments → production → Approve and deploy.**
3. **What you should see:** the same steps as section 6, with only `ai.env (600)` and `infra.env (600)`, no `backend-migrate`, and at the end seven services: `cloudflared`, `postgres`, `redis`, `ai-api`, `ai-worker` (healthy) and `ai-beat` (Up).
4. Check on the VM, as `deploy`:

   ```bash
   iltiam production ps --format 'table {{.Service}}\t{{.Status}}'
   iltiam production exec ai-api python -c "import urllib.request as u; print(u.urlopen('http://127.0.0.1:8000/ready', timeout=5).read().decode())"
   ```

5. Cloudflare dashboard → **Networking → Tunnels:** `iltiam-prod` is **Healthy**. `https://api.iltiamcare.com/api/health/` answers **502**: the tunnel runs, but there is no backend behind it yet. That is expected.

**Later, turning the production backend on** (after DEP-13, DEP-14 and SMTP; Runbook 4, section 7):

1. Set every `prod-required` secret and variable in the `production` Environment. Runbook 4, section 10.2 must print nothing.
2. Open a pull request that sets `COMPOSE_PROFILES=backend` and the published `BACKEND_IMAGE` tag in `env/production.versions`.
3. Merge, deploy production, and run section 7 with `production` and `api.iltiamcare.com`.

## 9. Day to day

Always on the VM as `deploy` (`ssh iltiam`, then `sudo -iu deploy`), and always through `iltiam <ENV> …` (`scripts/compose.sh`).

### 9.1 Logs

```bash
iltiam staging logs --tail 100 backend-web
iltiam staging logs -f --tail 20 ai-worker
```

`-f` follows new lines until you press **Ctrl+C**. Logs can contain email addresses, phone numbers and IP addresses: **never paste them into an issue or a chat**; describe what you saw instead. Each container keeps at most 5 × 10 MB of logs.

### 9.2 Status

```bash
iltiam staging ps --format 'table {{.Service}}\t{{.Status}}'
```

`(unhealthy)` means the health check failed three times in a row. Read that service's logs (9.1).

### 9.3 Restart one service

```bash
iltiam staging restart backend-worker
```

A restart keeps the container and its settings. **A changed secret or variable needs a deploy** (section 6), not a restart: only the deploy writes the env files again.

### 9.4 Roll back to an earlier image

Never retag images by hand. Put the earlier tags back into the versions file instead:

1. In your clone on the laptop: `git log -p env/staging.versions` shows every tag that was deployed.
2. Open a pull request that puts the previous tags back. Merge it.
3. Deploy that environment (section 6 or 8).

**Back to AI-only** (`COMPOSE_PROFILES=` empty again): the deploy then leaves the backend containers running, because `--remove-orphans` doesn't count a service of an inactive profile as an orphan. After that deploy, stop them by hand:

```bash
iltiam staging stop backend-web backend-worker backend-beat
```

**Database migrations don't roll back by themselves.** If the newer backend ran a migration, an older backend may not work with the newer database. Check the backend's release notes first; restoring the database is Runbook 6 (#8).

### 9.5 Memory

```bash
free -h
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.CPUPerc}}'
docker stats --no-stream --format '{{.MemUsage}}' | awk '{v=$1; u=v; gsub(/[0-9.]/,"",u); n=v+0; if(u=="GiB")n*=1024; if(u=="KiB")n/=1024; if(u=="B")n/=1048576; s+=n} END {printf "all containers: %.0f MiB\n", s}'
```

**What you should see:** each container well under its limit (the `MemPerc` column is the share of its own limit), and `all containers:` under **10240 MiB** (10 GB) with both environments idle. Write the idle total in the As built table.

### 9.6 Production first: stop the staging AI worker

When memory or CPU is short (section 2):

```bash
iltiam staging stop ai-worker
```

Staging analyses then wait in the queue; nothing is lost. Start it again when production is quiet:

```bash
iltiam staging start ai-worker
```

**A stopped container stays stopped**, even after a reboot (`restart: unless-stopped`). Don't forget to start it again. **Never stop production's AI worker** to make room.

### 9.7 Stop or start a whole environment

```bash
iltiam staging stop
iltiam staging start
```

Use `stop` and `start`, not `down`. **Never delete anything under `/srv/iltiam/<ENV>/`**: that is the environment's data.

## 10. Runbook 3's checks "after #2"

With staging (and then production) running, do [Runbook 3](03-cloudflare-tunnels.md), section 11, in this order. Record each result in Runbook 3's Verified column and as a comment on issue #9, pass or fail with the date, without IPs or output.

| Order | Runbook 3 row | Section | Now? |
|---|---|---|---|
| 1 | 20 (VM listens only on 22) and 21 (port check from outside) | 10.4 | done on staging, 2026-10-31 |
| 2 | 22, API part: `{"status": "ok"}` on `staging-api.` (on `api.` once production has its backend) | 11.1 | done on staging, 2026-10-31 |
| 3 | 23: API never cached | 11.2 | done on staging, 2026-10-31 |
| 4 | 25, API part: no rewriting | 11.3 | done on staging, 2026-10-31 |
| 5 | 26: AI unreachable from the tunnel's network | 11.4 (and below) | done on staging, 2026-10-31 |
| 6 | 27: `NUM_PROXIES` resists a fake header. Check first with `gh variable list --env staging -R iltiam/iltiam-deployment` that `NUM_PROXIES` is `1` | 11.5 | done on staging, 2026-10-31 |
| 7 | 22 (app part), 24 (assets cached), 25 (app part) | 11.1 to 11.3 | **after WEB-03**, tracked in #35 |
| 8 | 28: HSTS | 11.6 | **after WEB-03**, tracked in #35: HSTS waits until the app hosts serve the real web app |

For production, rows 1 to 8 again on `app.` and `api.`, tracked in #36.

**Row 26, in detail.** On the VM, as `deploy`:

```bash
docker network ls --filter name=iltiam-
docker run --rm --network iltiam-staging_edge curlimages/curl:8.22.0 -sS -m 5 http://ai-api:8000/
docker run --rm --network iltiam-staging_edge curlimages/curl:8.22.0 -sS -m 5 http://postgres:5432/
docker run --rm --network iltiam-staging_edge curlimages/curl:8.22.0 -sS -m 5 -o /dev/null -w '%{http_code}\n' \
  -H 'Host: staging-api.iltiamcare.com' -H 'X-Forwarded-Proto: https' http://backend-web:8000/api/health/
```

**What you should see:**
- six networks: `iltiam-staging_edge`, `_internal`, `_egress` and the same three for `iltiam-prod`;
- `curl: (6) Could not resolve host: ai-api`, then the same for `postgres`. `curl: (28) Resolving timed out …` means the same: the name doesn't exist on `edge`;
- `200`: the network itself works, so the two failures above are real isolation.

For production, use `iltiam-prod_edge`. Until production has its backend, the third command answers `Could not resolve host: backend-web`.

**While only staging runs, AI-only:** three networks (the `iltiam-staging_` ones), and the third command answers `Could not resolve host: backend-web` too. The two `Could not resolve host` lines for `ai-api` and `postgres` still prove the isolation; run the third again once the backend is on.

## 11. The issue's acceptance checks

### 11.1 Deploying again changes nothing

On the VM, as `deploy`:

```bash
docker ps --format '{{.ID}} {{.Names}}' | sort > /tmp/before.txt
```

Run the staging deploy again (section 6) with the same tags. When it is green:

```bash
docker ps --format '{{.ID}} {{.Names}}' | sort > /tmp/after.txt
diff /tmp/before.txt /tmp/after.txt && echo "no container was recreated"
rm /tmp/before.txt /tmp/after.txt
```

**What you should see:** `no container was recreated`. In the run's log, `up` says `Running` for every service.

### 11.2 Breaking staging doesn't touch production

**Not now:** it needs production running, so it moves to the production issue with section 8.

```bash
prod() { docker inspect -f '{{.Name}} {{.State.StartedAt}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' $(docker ps -q --filter label=com.docker.compose.project=iltiam-prod) | sort; }
prod > /tmp/prod-before.txt
iltiam staging kill postgres
iltiam staging stop
sleep 60
prod > /tmp/prod-after.txt
diff /tmp/prod-before.txt /tmp/prod-after.txt && echo "production untouched"
iltiam production exec ai-api python -c "import urllib.request as u; print(u.urlopen('http://127.0.0.1:8000/ready', timeout=5).status)"
```

`ai-beat` has no health check, so its line ends after the start time. That is fine.

**What you should see:** `production untouched` (the same containers, the same start times, still healthy), and `200`. In the dashboard, `iltiam-prod` stays **Healthy** while `iltiam-staging` goes **Inactive**.

Then bring staging back: `iltiam staging start`, wait a minute, and check section 7.1. Delete the two files in `/tmp`.

### 11.3 A reboot

As `ubuntu`:

```bash
sudo reboot
```

Wait two minutes, `ssh iltiam` again, then:

```bash
findmnt /srv/iltiam
sudo -iu deploy bash -c 'iltiam() { bash /srv/iltiam/repo/scripts/compose.sh "$@"; }; iltiam staging ps --format "table {{.Service}}\t{{.Status}}"; iltiam production ps --format "table {{.Service}}\t{{.Status}}"'
```

**What you should see:** `/srv/iltiam` mounted, and both projects back as in sections 7.1 and 8 within about three minutes (for now only staging; `iltiam production ps` says `infra.env not found`, which is fine). The AI services are the slowest; they load their models first. Containers started in any order after a reboot, so some may restart once while Postgres or Redis come up; that is normal.

### 11.4 Memory, idle and during an analysis

1. **Idle, both projects running:** section 9.5. `all containers:` must be under 10240 MiB. Write it in the As built table. For now, staging alone: compare with section 2 (AI-only 1615 MiB measured; the backend adds about 650 MiB).
2. **Peak of the AI worker during one analysis.** One analysis goes through the AI service's job API from inside the staging `ai-api` container, which already holds the service token: it never appears on a command line or on screen. (The AI repository's `scripts/smoke_demo.py` needs `httpx`, which the image doesn't have, and `ai-api` has no internet to install it; so the few lines below do the same with `requests`.)
   - On your laptop, from the `iltiam-ai-service` folder (Git Bash), copy the repository's test photo with the 50 mm marker. For a real 8 MP case, use one of your own 8 MP photos of the printed marker sheet (AI-09): **never a photo of a patient.**

     ```bash
     scp tests/fixtures/good_marker.jpg iltiam:/tmp/
     ```

   - On the VM, open **two** SSH windows, both `sudo -iu deploy`. In the first:

     ```bash
     docker stats --format 'table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}' iltiam-staging-ai-worker-1
     ```

   - In the second, write the script, copy it and the photo into `ai-api`, and run it:

     ```bash
     cat > /tmp/one-analysis.py <<'EOF'
     # One analysis through the AI job API, from inside ai-api (Runbook 5, section 11.4).
     # The token comes from this container's own environment and is never printed.
     import os, sys, time, requests
     url = "http://127.0.0.1:8000"
     headers = {"X-Service-Token": os.environ["AI_SERVICE_TOKEN"]}
     with open(sys.argv[1], "rb") as fh:
         res = requests.post(f"{url}/v1/analyze", headers=headers, timeout=30,
                             files={"image": ("photo.jpg", fh, "image/jpeg")}, data={"marker_size_mm": "50"})
     if res.status_code != 202:
         sys.exit(f"POST /v1/analyze -> {res.status_code}")
     job = res.json()
     deadline = time.monotonic() + 120
     while job["status"] not in ("COMPLETED", "FAILED") and time.monotonic() < deadline:
         time.sleep(0.5)
         job = requests.get(f"{url}/v1/jobs/{job['job_id']}", headers=headers, timeout=30).json()
     if job["status"] != "COMPLETED":
         sys.exit(f"job {job['status']}: {job.get('error')}")
     result = job["result"]
     print("decision:", result["decision"]["status"], "| area_cm2:", result["measurement"]["area_cm2"])
     EOF
     iltiam staging cp /tmp/one-analysis.py ai-api:/tmp/one-analysis.py
     iltiam staging cp /tmp/good_marker.jpg ai-api:/tmp/photo.jpg
     iltiam staging exec ai-api python /tmp/one-analysis.py /tmp/photo.jpg
     ```

   **What you should see:** the second window prints `decision: ACCEPTED | area_cm2: …` after a few seconds. In the first window, write down the **highest** memory value of `iltiam-staging-ai-worker-1` while it ran. It must stay under the 1.5 GB limit with room to spare. If it comes within 200 MB of the limit, raise `ai-worker`'s `mem_limit` in `compose.yml` by a pull request.
   - Clean up: stop `docker stats` with **Ctrl+C**, then `rm /tmp/one-analysis.py`, and as `ubuntu` `rm /tmp/good_marker.jpg`. The copies inside `ai-api` disappear at its next restart. Run section 7.5 again: the worker's `torch intra-op threads` line now appears.

## 12. Backups: not yet

**There are no backups until Runbook 6 (#8).** What lives where:

| Data | Where | Backed up by |
|---|---|---|
| Postgres (`iltiam`, `iltiam_ai`) | `/srv/iltiam/<ENV>/postgres` | **#8**: nightly encrypted `pg_dump` to the Riyadh backup bucket, a weekly restore test |
| Redis (queued jobs, cache) | `/srv/iltiam/<ENV>/redis` | nothing: it is rebuilt by itself |
| Model weights | `/srv/iltiam/weights` | nothing: `weights-init` downloads them again |
| Env files | `/srv/iltiam/env/<ENV>/` | nothing: the next deploy writes them from GitHub |
| Photos, masks, PDFs | OCI Object Storage ([Runbook 8](08-object-storage.md), #13), never on the VM | versioning keeps overwritten or deleted files for 30 days (Runbook 8, section 8); nothing else |
| The whole data volume | `iltiam-data` | **#8**: weekly block volume backups |

**Rule until #8 is done:** staging holds only test data, and **production takes no real patient data before #8's restore test has passed** (DEP-11, the go-live checklist).

## 13. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| **deploy** is not in the Actions list, or has no **Run workflow** button | This runbook's pull request isn't merged into `main` yet (section 3, step 6) |
| The run says **Waiting** | Production needs approval: **Review deployments → production → Approve and deploy** |
| `Branch "…" is not allowed to deploy to staging` | Run the workflow from `main`: the Environments allow only `main` ([Runbook 4](04-secrets.md), section 5) |
| `ERROR: env/<ENV>.versions: … is still 'to-confirm'` | The image isn't published, or its tag isn't in the versions file yet (section 3, step 4) |
| `ERROR: … never 'latest'` or `must be registry/name:tag` | A typo in the versions file. Fix it by a pull request |
| `ERROR: env/backend.env.example: not set for staging: …` | Those secrets or variables are missing from the Environment. Add them; Runbook 4, section 10.2 lists what is missing |
| `DEPLOY_SSH_KEY or DEPLOY_SSH_KNOWN_HOSTS is not set` / `DEPLOY_HOST is not set` | Section 5 wasn't done for this environment |
| `Host key verification failed` | `DEPLOY_SSH_KNOWN_HOSTS` doesn't match the VM. Redo section 5.2. If the VM wasn't rebuilt and the key still differs, treat it as an incident |
| `SSH as deploy failed` / `Permission denied (publickey)` | The environment's public key isn't in `/home/deploy/.ssh/authorized_keys`, or that file isn't `600` owned by `deploy`. Redo section 5.1 with a new key |
| `/srv/iltiam/repo is not a clone of this repository` | Section 4.3 wasn't done |
| `error: Your local changes … would be overwritten by checkout` | Someone edited files in `/srv/iltiam/repo`. As `deploy`: `git -C /srv/iltiam/repo status`, then `git -C /srv/iltiam/repo checkout -- .` to drop the changes, and deploy again |
| `ERROR: /srv/iltiam is not mounted` | The data volume is missing. Don't deploy. Check the OCI console attachment and `findmnt /srv/iltiam` (Runbook 1, section 10) |
| Docker doesn't start after a reboot (`docker ps` hangs or says it can't connect) | The data volume isn't mounted, so section 4.1 keeps Docker off on purpose. Fix the mount (Runbook 1, section 10), then `sudo systemctl start docker` |
| `ERROR: /srv/iltiam/env/<ENV> must be mode 700` or `… must be mode 600` | `sudo chmod 700 /srv/iltiam/env/<ENV>`, or deploy again: the deploy writes each file with `600` |
| `ERROR: another deploy is running on this VM` | Wait for the other run (staging or production) to finish. If none is running, the lock is stale only while a `deploy.sh` process exists: `pgrep -af deploy.sh` |
| `ERROR: Docker Compose 2.20 or newer is needed` | `sudo apt-get update && sudo apt-get install --only-upgrade docker-compose-plugin` |
| `Error response from daemon: … denied` or `unauthorized` at `pull` | The package doesn't grant `iltiam-deployment` read access ([Runbook 4](04-secrets.md), section 8) |
| `weights-init failed` with `401` or `404` | `WEIGHTS_READ_TOKEN` expired, was never approved by the organisation, or lacks access to `iltiam-ai-service` (`docs/secrets.md`, section 6.6). Set a new one and deploy again |
| `backend migrations failed`: `password authentication failed for user "iltiam"` | The database was created with an older `BACKEND_DB_PASSWORD`. Postgres reads its passwords only on the very first start: change the role's password first (`docs/secrets.md`, section 6.3), then deploy |
| `postgres` never healthy; its log says `initdb: error` or `Permission denied` | `/srv/iltiam/<ENV>/postgres` is on the wrong disk or has the wrong owner. Check section 4.2 and `findmnt /srv/iltiam` |
| `ai-api` stays `(unhealthy)`; `/ready` says `checksum mismatch` | A model file is damaged. Deploy again: `weights-init` replaces only that file |
| A container shows `Restarting`, and `docker inspect -f '{{.State.OOMKilled}}' <name>` says `true` | It went over its `mem_limit`. Section 9.5; if it is the AI worker during analyses, section 11.4 step 2 |
| `backend-web` stays `(unhealthy)` | Its health check sends the **first** name in `ALLOWED_HOSTS` as the host. That must be `staging-api.iltiamcare.com` / `api.iltiamcare.com` ([Runbook 4](04-secrets.md), section 9). Then `iltiam <ENV> logs backend-web` |
| `cloudflared` stays `(unhealthy)` | No connection to Cloudflare: wrong or refreshed `CF_TUNNEL_TOKEN` ([Runbook 3](03-cloudflare-tunnels.md), section 12), or outbound traffic is blocked (Runbook 3, section 14) |
| `staging-api` or `api` answers **502** | `cloudflared` runs, but `backend-web` doesn't. Expected on staging while it is AI-only (section 1), and on production until its backend is turned on (section 8). Otherwise `iltiam <ENV> ps` and its logs |
| `staging-api` times out on port 443 from your laptop, but answers from the VM (`curl -s https://staging-api.iltiamcare.com/api/health/`) and over a phone hotspot | The laptop's network, not the stack (seen 2026-10-31). Run section 7.3 over the hotspot or from the VM |
| `400 Bad Request` or `ERR_TOO_MANY_REDIRECTS` from the API | [Runbook 3](03-cloudflare-tunnels.md), section 14 |
| `'config …' would print secrets into this terminal` | `scripts/compose.sh` protects you: use `iltiam <ENV> config --quiet` |
| `infra.env not found or not readable` | You are not `deploy`: run `sudo -iu deploy` first. Or the environment was never deployed |
| Redis log: `OOM command not allowed when used memory > 'maxmemory'` | Redis is full (128 MB) and refuses writes instead of losing queued jobs. Usually a stuck queue: is the worker running (9.2)? Raise `maxmemory` in `compose.yml` only with Runbook 7's numbers |
| `curl: (6) Could not resolve host: backend-web` in section 10 | Wrong network name, or the backend isn't running in that project (production before section 8's "later") |

## 14. Verification checklist

The **When** column says when a row can pass:
- **this PR:** in CI, before the merge;
- **on the VM:** after sections 4 to 11;
- **after WEB-03:** once the web image and its service exist;
- **after #99:** once iltiam-backend#99's image runs on staging (section 1);
- **production issue:** with production, later (scope, at the top);
- **after DEP-13/14/SMTP:** once production's backend is on (section 8).

The **Verified** column records the date each row last passed.

| # | Check | How | Expected | When | Verified |
|---|---|---|---|---|---|
| 1 | CI | the pull request's checks | `env-check` green: shellcheck, `check-env.sh`, `check-compose.sh`, gitleaks | this PR | |
| 2 | Docker waits for the volume | section 4.1 | `RequiresMountsFor=/srv/iltiam` | on the VM | |
| 3 | Folders | section 4.2 | the modes and owners shown there | on the VM | |
| 4 | Repository clone | section 4.3 | `/srv/iltiam/repo` at `main` | on the VM | staging, via the green deploy 2026-10-31 |
| 5 | Deploy keys | section 5.1 | one key per environment, each with `restrict`; each test prints the Compose version | on the VM | staging, via the green deploy 2026-10-31 |
| 6 | Host key | section 5.2 | the two fingerprints are the same | on the VM | staging, via the green deploy 2026-10-31 |
| 7 | Environments complete | section 5.4; Runbook 4, section 10.2 | the three `DEPLOY_*` names in both; the `comm` commands print nothing | on the VM | staging, via the green deploys 2026-10-31 (AI-only, then with the backend's values) |
| 8 | Staging deploy | section 6 | green run, `==> deployed staging` | on the VM | 2026-10-31, `COMPOSE_PROFILES=backend`, backend `sha-4b5251d` (AI-only earlier the same day) |
| 9 | Staging containers | section 7.1 | 9 services, 8 `(healthy)`, `ai-beat` `Up` (AI-only: 6, 5 `(healthy)`) | on the VM | 2026-10-31: 9, 8 `(healthy)`, `ai-beat` `Up` |
| 10 | Env files and ports | section 7.2 | `700`/`600`; no `0.0.0.0:` | on the VM | staging, via the green deploy 2026-10-31: `700`/`600` only. Ports 2026-10-31: no `0.0.0.0:` or `[::]:` mapping (Runbook 3, row 20) |
| 11 | Backend through the tunnel | section 7.3 | `{"status": "ok"}`; `/api/ready/` all `ok` | after #99 | 2026-10-31: `{"status":"ok"}`; `/api/ready/` ready, `db`, `redis`, `storage`, `ai` all `ok` (through the public hostname, from the VM) |
| 12 | AI service | section 7.4 | `/ready` ready; checksum `382ce77d…`; weights present (also ai-service#143) | on the VM | partial, 2026-10-31: AI containers healthy, weights downloaded (ai-service#143 closed on these); `/ready` ready, seen as `ai` `ok` in `/api/ready/` (the backend asks the AI service's `/ready`). The checksum is still open |
| 13 | Two torch threads | section 7.5 | `torch intra-op threads: 2` | on the VM, with `sha-0d1861e` or newer | |
| 14 | Production deploy | section 8 | approval asked; green run; 7 services; `iltiam-prod` Healthy | production issue | |
| 15 | Same tags, no change (AC 3) | section 11.1 | `no container was recreated` | on the VM | 2026-10-31: a second green run with the same tags; every backend and AI container kept its `Up` time |
| 16 | Staging broken, production untouched (AC 2) | section 11.2 | `production untouched`; `200` | production issue | |
| 17 | Reboot | section 11.3 | volume mounted; both projects back (for now staging) | on the VM | |
| 18 | Idle memory (AC 1, part) | section 9.5 | `all containers:` under 10240 MiB, both projects running (for now staging: about 2713 MiB, section 2) | on the VM | partial, 2026-10-31: staging complete 2173 MiB (AI-only earlier: 1615 MiB); production not running yet |
| 19 | AI worker peak | section 11.4 | under 1.5 GiB with room to spare | on the VM | |
| 20 | Production first | section 9.6 | staging `ai-worker` stops and starts; production unchanged | production issue | |
| 21 | Runbook 3, rows 20, 21, 22 (API), 23, 25 (API), 26, 27 | section 10 | as in Runbook 3, section 13 | on the VM: 20, 21, 26; after #99: the rest | PASS 2026-10-31, staging: 22 (API) `{"status":"ok"}`; 23 `cf-cache-status: DYNAMIC`; 25 (API) not rewritten; 20, 21, 26 and 27 pass (details in Runbook 3, section 13). Production: #36 |
| 22 | Runbook 3, rows 22 (app), 24, 25 (app) | section 10 | as in Runbook 3, section 13 | after WEB-03 (#35) | |
| 23 | HSTS, Runbook 3 row 28 | section 10; Runbook 3, section 11.6 | `max-age=15552000; includeSubDomains` | after WEB-03 (#35) | |
| 24 | Production backend | section 8, "later"; section 7 with `production` | `api.iltiamcare.com/api/health/` `{"status": "ok"}` | after DEP-13/14/SMTP | |
| 25 | Both projects fully healthy at once (AC 1) | sections 7.1, 8, 9.5 | every service of both projects healthy; idle under 10 GB | after WEB-03 and DEP-13/14/SMTP | |

**Record the results as a comment on issue #2:** pass or fail per row, with the date. **Never include** IP addresses, fingerprints, keys, tokens, env file contents, `docker compose config` output or logs.

## 15. Security notes

- **No inbound web traffic:** no `ports:` anywhere (`scripts/check-compose.sh` fails CI if one appears), and only SSH on the VM's public address.
- **The AI service is private:** it is on `internal` only, a network with no route out and no tunnel. The tunnel's network doesn't even know its name (section 10).
- **Each secret goes only where it is needed:** the tunnel token only to `cloudflared`, the weights token only to `weights-init`, each database password only to Postgres and its own service. `scripts/check-compose.sh` checks this on every pull request.
- **Secrets on the VM:** only in `/srv/iltiam/env/<ENV>/` (`700`, files `600`, owner `deploy`), written by the deploy. Anyone in the `docker` group can read container settings with `docker inspect`, so the group has only `ubuntu` and `deploy` (Runbook 1). Keep it that way.
- **The deploy keys are as strong as root:** a key that can run Docker can do anything on the VM. One key per environment, `restrict`ed, only in GitHub; remove it from `authorized_keys` on a leak or staff change (`docs/secrets.md`, section 2). Runbook 9 (DEP-03) adds a forced command that limits each key to its own project.
- **GHCR:** no registry token is stored. The deploy logs in with the job's own token, which dies with the job, and logs out on any exit.
- **Containers:** our images and `cloudflared` run as non-root users with every Linux capability dropped and `no-new-privileges`. Postgres and Redis keep the capabilities their own start-up scripts need.
- **Logs** are capped and stay on the VM. They can contain personal data: describe, never paste.
- **PDPL:** the databases and model files stay on the VM in Riyadh; backups (#8) stay in the Riyadh region.

## 16. What comes next

- **The staging backend:** its tag (`sha-4b5251d`) and `COMPOSE_PROFILES=backend` are in `env/staging.versions`. Next: section 6, the "after #99" rows of section 14 and row 12, then [Runbook 8](08-object-storage.md), section 13.
- **Production**, in its own issue (#36): sections 5 (production), 8, 11.2 and the "production issue" rows of section 14.
- **WEB-03** (iltiam/iltiam-web#25): a small pull request adds the `web` service (on `edge`, 64 MB, port 8080, `web.env`), its tag in the versions files, and its rules in `scripts/check-compose.sh`; `scripts/render-deploy-env.sh` then writes `web.env`. Then section 10 rows 7 and 8 (with HSTS), tracked in #35.
- **DEP-13, DEP-14 and SMTP:** production's backend (section 8, "later").
- **Runbook 6** (#8): backups and the weekly restore test (section 12).
- **Runbook 7** (#10): monitoring on a network shared with both projects, memory and disk alerts, Redis memory.
- **Runbook 9** (DEP-03, #16): starts this deploy automatically for staging, then the smoke test (DEP-10, #17), with rollback on failure and the forced-command guard for the deploy keys.
- **Runbook 10** (DEP-04, #19): production releases with approval and rollback.
- **#5:** the local development stack, from the same images.
