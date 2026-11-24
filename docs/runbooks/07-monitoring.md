# Runbook 7: monitoring, logs, alerts and uptime for both environments (about 1 GB, free)

- **Issue:** iltiam/iltiam-deployment#10 (DEP#10). SRS NFR-REL-01 (97 % availability), NFR-MAI-02, SRS §5.6.3 (AI drift, with iltiam/iltiam-ai-service#151).
- **Who:** someone who can sign in to the OCI console as an administrator, to Cloudflare Zero Trust, log in to `iltiam-1` as `ubuntu` (`ssh iltiam`, Runbook 1), and set GitHub Environments on `iltiam-deployment`. A Discord server where you can make a webhook, and the healthchecks.io account of [Runbook 6](06-backups.md), section 5.
- **Time:** about 2 hours for the setup (sections 3 to 11 and 14), then about 1 hour for the staged failures (section 15), and a week for the AI drift check (section 16).
- **Result:** one monitoring stack, the Compose project `iltiam-monitoring`, watches staging and (once it runs) production on the same VM, with every memory limit adding up to 1168 MiB. Grafana at `https://grafana.iltiamcare.com`, behind Cloudflare Access, shows latency, upload-to-result time, the AI queue and job time, errors, the VM, the backups, and 7 days of every container's logs. Alerts reach the team by email and Discord. UptimeRobot checks the public hostnames from outside, and OCI alarms catch a stopped VM and full object storage.

> **This repository is public.** Never paste a token, a password, a webhook or ping URL, an email address, an OCID or the VM's address into this runbook, an issue, a PR, a commit or a chat. `scripts/monitoring.sh` prints names, tags, states and sizes only.

## As built

Filled in when the steps are done. Names and dates only.

| Item | Value |
|---|---|
| Folders on the VM (section 3) | |
| Tunnel `iltiam-monitoring`, route `grafana.iltiamcare.com` (section 4) | |
| GitHub Environment `monitoring` (section 5) | |
| SMTP user `iltiam-smtp-monitoring` (section 6) | |
| Discord webhook (section 7) | |
| Dead-man check `iltiam-monitoring-watchdog` (section 8) | |
| OCI Metrics data source and the object storage dashboard (section 9) | |
| OCI alarm `iltiam-instance-down` (section 10) | |
| First monitoring deploy (section 11), run number | |
| Grafana behind Access, Runbook 3 row 17 (section 13) | |
| `docker stats` of `iltiam-monitoring` (section 13) | |
| UptimeRobot monitors and status page (section 14) | |
| Each alert fired in a staged failure (section 15) | |
| AI drift synthetic check (section 16) | |
| Production monitored (`MONITORED_ENVIRONMENTS`, section 17.5) | after #36 |

## 1. How it works

```
                       Cloudflare Access (team-only, one-time PIN)
                                     │ grafana.iltiamcare.com
                                     ▼
   iltiam-monitoring ─────────────────────────────────────────────────────────────────────────────
   │ cloudflared (own tunnel) ── tunnel ── Grafana ── monitoring ── Prometheus ── Alertmanager ──▶ email (OCI Email Delivery)
   │                                         │                     │   ▲   ▲        │          ▶ Discord
   │                                         └── Loki ◀── Alloy    │   │   │        └─ Watchdog ▶ healthchecks.io
   │                                                       │       │   │   └── node-exporter (the VM; backup status files)
   │                                           docker-proxy (read-only Docker API) ── cAdvisor (per container)
   │                                                                │   └── blackbox exporter ──▶ public URLs (internet)
   ────────────────────────────────────────────────────────── metrics-staging ── metrics-production ──
                                     iltiam-staging: staging-ai-api:8000, staging-ai-worker:9808,
                                                     staging-backend-web:9100 (and :8000 /api/health/),
                                                     staging-backend-worker:9101
   UptimeRobot (outside) ──▶ https://api. / app. / staging-api. / staging-app.        OCI alarms ──▶ topic iltiam-alerts
```

| Container | What it does | `mem_limit` |
|---|---|---|
| `prometheus` | Scrapes every 30 s, keeps **35 days** (the AI drift rules compare this week with the 4 before), at most 6 GB on disk; evaluates the alert rules | 288m |
| `alertmanager` | Groups alerts and sends them: email and Discord; the Watchdog to the dead-man check | 48m |
| `blackbox` | Probes `/api/health/` and the AI `/ready` inside the VM, and the public hostnames from the internet | 32m |
| `node-exporter` | The VM's memory, CPU and disks; reads Runbook 6's backup status files | 48m |
| `cadvisor` | Memory and CPU per container, against its `mem_limit` | 64m |
| `docker-proxy` | The Docker API, read-only: lists containers and networks, reads logs | 32m |
| `alloy` | Ships every container's logs into Loki ([promtail](https://grafana.com/docs/loki/latest/send-data/promtail/)'s successor; promtail reached its end of life in March 2026) | 112m |
| `loki` | Keeps the logs **7 days** | 192m |
| `grafana` | Dashboards and log search | 256m |
| `cloudflared` | The monitoring tunnel: `grafana.iltiamcare.com` only | 96m |
| **Total** | issue #10: at most 1.2 GB; `scripts/check-monitoring.sh` fails CI above 1228 MiB | **1168m** |

**Decisions (issue #10):**

- **Its own tunnel.** `grafana.` goes through a third free tunnel, `iltiam-monitoring`, not staging's or production's: Grafana stays reachable while an environment is redeployed or down, and joins neither environment's `edge` network.
- **The metrics networks.** Each environment has an internal network, `iltiam-metrics-<env>`, made by `scripts/deploy.sh` and `scripts/monitoring.sh` (`scripts/lib/metrics-network.sh`). On it are only the environment's four scrape targets, as `<env>-<service>`, and Prometheus and the blackbox exporter. So monitoring never reaches Postgres or Redis, and the environments never reach each other. `scripts/check-compose.sh` enforces this.
- **Deployed by the `deploy` workflow** (`-f environment=monitoring`), from the GitHub Environment `monitoring`, like the environments (AGENTS.md). No laptop holds its secrets.
- **Targets follow `env/<env>.versions`.** `scripts/monitoring.sh` writes the targets from `MONITORED_ENVIRONMENTS` and each versions file: production's backend has no target while its profile is off, so nothing alerts on a service that doesn't run.
- **"Readiness" without `/api/ready/`.** Each call to the backend's `/api/ready/` costs 5 object storage requests ([Runbook 8](08-object-storage.md), section 2): at 2 a minute it would use the month's free 50,000 in 9 days. So its parts are watched one by one: `/metrics` answers (`TargetDown`), `/api/health/` and the AI `/ready` (`ServiceNotReady`), Redis (`RedisDown`) and Postgres (`DatabaseErrors`).
- **What Prometheus can't see** stays with OCI: the VM stopped or reclaimed (section 10) and object storage at 70 % (Runbook 8's alarm, section 12); the space used is a Grafana panel through OCI's own metrics (section 9).
- **cAdvisor needs containerd's socket.** Docker 29 keeps images in containerd, and cAdvisor 0.55 and later read containers through containerd; 0.52 can't read Docker 29's image store (tested for this runbook). The socket is mounted read-only, but that doesn't limit its API: cAdvisor can control containerd, as root. It is on internal networks only, and nothing publishes its port. If that is ever unacceptable, remove the `cadvisor` service: only the per-container memory panels and the `ContainerNearMemoryLimit` and `ContainerOomKilled` alerts go.

**What is kept, and where:** metrics 35 days (at most 6 GB) and logs 7 days, both on the data volume under `/srv/iltiam/monitoring/` in Riyadh ([retention](../privacy/retention.md) rows 17 and 25). Grafana's own database (users, the object storage dashboard) is there too.

## 2. Before you start

- This runbook's PR is merged, and **staging has been deployed since** (automatically or by hand): that deploy makes `iltiam-metrics-staging` and recreates the AI api, AI worker, backend web and backend worker on it (`backend-web` restarts in a few seconds; the AI services roll without downtime).
- [Runbook 3](03-cloudflare-tunnels.md), section 9.3 is done: the Access application `grafana` and the policy `team-only` exist.
- [Runbook 6](06-backups.md), section 5 is done: you have the healthchecks.io account.
- On your laptop: Git Bash, `gh` signed in with the `repo` and `workflow` scopes (`gh auth status`).

## 3. Prepare the VM (once)

`ssh iltiam` (as `ubuntu`), then:

```bash
sudo install -d -m 755 -o deploy -g deploy /srv/iltiam/monitoring
sudo install -d -m 700 -o deploy -g deploy /srv/iltiam/env/monitoring
# The backup status folder, as Runbook 6's install-backup-timers.sh makes it (no change if it exists):
sudo install -d -m 700 -o deploy -g deploy /srv/iltiam/backups
sudo install -d -m 755 -o deploy -g deploy /srv/iltiam/backups/status
sudo stat -c '%a %U %n' /srv/iltiam/monitoring /srv/iltiam/env/monitoring /srv/iltiam/backups/status
test -S /run/containerd/containerd.sock && echo "containerd socket: ok"
```

**What you should see:**

```
755 deploy /srv/iltiam/monitoring
700 deploy /srv/iltiam/env/monitoring
755 deploy /srv/iltiam/backups/status
containerd socket: ok
```

**If the containerd line is missing:** `systemctl status containerd`. Docker CE runs it; without it cAdvisor shows nothing (section 1, "Decisions").

## 4. The monitoring tunnel (Cloudflare, once)

1. Cloudflare → **Zero Trust → Networking → Tunnels** (older dashboards: **Networks → Tunnels**) → **Create a tunnel → Cloudflared** → name `iltiam-monitoring` → **Save tunnel.**
2. On **Install and run connectors**, choose **Docker**, copy the whole command, and **don't run it**. In Git Bash, paste it at the prompt of the first line:

   ```bash
   read -rsp 'Paste the docker run command: ' CMD; echo
   printf '%s' "${CMD##* }" | gh secret set MONITORING_TUNNEL_TOKEN --env monitoring -R iltiam/iltiam-deployment
   unset CMD; clear
   ```

   The Environment `monitoring` doesn't exist yet: `gh` makes it. Section 5 sets its rules. Then copy some harmless text, so the command no longer sits in your clipboard.
3. **Next** → **Add a published application route:**

   | Subdomain | Domain | Path | Service type | URL |
   |---|---|---|---|---|
   | `grafana` | `iltiamcare.com` | (empty) | HTTP | `grafana:3000` |

   Leave **Additional application settings** as they are. **Save.** This is the tunnel's only route.

**What you should see:**

- `✓ Set Actions secret MONITORING_TUNNEL_TOKEN for iltiam/iltiam-deployment`.
- `iltiam-monitoring` in the tunnel list, **Inactive** until section 11.
- **DNS → Records:** a new **CNAME** `grafana`, **Proxied**. Don't paste its target anywhere: it contains the tunnel ID.
- **Access → Applications:** `grafana` (Runbook 3, section 9.3) now has a DNS record behind it. Nothing to change there.

`grafana.` is only ever served through Cloudflare, over HTTPS, as HSTS with `includeSubDomains` requires (#35).

## 5. The GitHub Environment `monitoring` (once)

1. **github.com/iltiam/iltiam-deployment → Settings → Environments → `monitoring`** (made in section 4):
   - **Deployment branches and tags:** **Selected branches and tags → Add rule →** `main`. As staging ([Runbook 4](04-secrets.md), section 5.1).
   - **No required reviewers:** like staging, someone with write access starts it and approves the held run (AGENTS.md, step 5).
2. **The deploy key**, its own, as in [Runbook 5](05-compose-stack.md), section 5.1, with `monitoring` instead of `staging`: key `iltiam-deploy-monitoring`, `gh secret set DEPLOY_SSH_KEY --env monitoring …`, the public key appended to `deploy`'s `authorized_keys` with `restrict`. The `grep -c` then shows one more key than before.
3. **The VM's host key and address**, the same values as staging's (Runbook 5, sections 5.2 and 5.3), with `--env monitoring`:

   ```bash
   ssh-keyscan -t ed25519 <PUBLIC_IP> 2>/dev/null > ~/iltiam-known-hosts
   ssh-keygen -lf ~/iltiam-known-hosts          # the same SHA256 fingerprint as Runbook 5, section 5.2
   gh secret set DEPLOY_SSH_KNOWN_HOSTS --env monitoring -R iltiam/iltiam-deployment < ~/iltiam-known-hosts
   rm ~/iltiam-known-hosts
   read -rsp 'VM public IP: ' IP; echo; printf '%s' "$IP" | gh secret set DEPLOY_HOST --env monitoring -R iltiam/iltiam-deployment; unset IP
   ```

4. **Grafana's admin password**, random, straight into GitHub and Bitwarden. It is shown once, so the Bitwarden note can be made from it:

   ```bash
   P="$(openssl rand -base64 24)"; printf '%s' "$P" | gh secret set GRAFANA_ADMIN_PASSWORD --env monitoring -R iltiam/iltiam-deployment
   printf '%s\n' "$P" | clip; unset P; clear
   ```

   Paste it into a new Bitwarden note `grafana admin` in **ILTIAM escrow** (Runbook 4, section 11), then copy some harmless text.
5. **What is monitored** (a variable, not secret):

   ```bash
   gh variable set MONITORED_ENVIRONMENTS --env monitoring --body staging -R iltiam/iltiam-deployment
   ```

**What you should see:** `gh secret list --env monitoring -R iltiam/iltiam-deployment` lists `DEPLOY_HOST`, `DEPLOY_SSH_KEY`, `DEPLOY_SSH_KNOWN_HOSTS`, `GRAFANA_ADMIN_PASSWORD` and `MONITORING_TUNNEL_TOKEN`; `gh variable list --env monitoring …` lists `MONITORED_ENVIRONMENTS`.

## 6. Email: the SMTP user (OCI, once)

Alerts go out through OCI Email Delivery in Riyadh, from the approved sender `no-reply@iltiamcare.com` ([Runbook 2](02-cloudflare-dns-tls.md), section 11). Monitoring has its own credential, so rotating it never touches the environments' mail.

1. **☰ → Identity & Security → Domains → Default domain → User management → Create user:** `iltiam-smtp-monitoring` (a team address if the form needs one). **Groups:** `iltiam-smtp-senders` (Runbook 2, section 11.5; its policy `iltiam-smtp-send` already covers it).
2. Open the user → **SMTP credentials → Generate credentials**, description `iltiam-monitoring-<YYYY-MM>`. The password is shown once: keep the dialog open.
3. In Git Bash, paste each value at its prompt:

   ```bash
   gh secret set ALERT_SMTP_USERNAME --env monitoring -R iltiam/iltiam-deployment
   gh secret set ALERT_SMTP_PASSWORD --env monitoring -R iltiam/iltiam-deployment
   gh secret set ALERT_EMAIL_TO --env monitoring -R iltiam/iltiam-deployment
   ```

   `ALERT_EMAIL_TO`: the team's addresses, comma-separated, **no spaces** (for example the two of Runbook 8's alarm topic). Close the OCI dialog, then `clear`.

**What you should see:** three `✓ Set Actions secret …` lines. Delivery is tested in section 13.

## 7. Discord (once)

1. In the team's Discord server: **Server Settings → Integrations → Webhooks → New Webhook.** Name `ILTIAM alerts`, channel: the team's alerts channel (make one, for example `#alerts`) → **Copy Webhook URL.**
2. In Git Bash, paste it at the prompt:

   ```bash
   gh secret set ALERT_DISCORD_WEBHOOK_URL --env monitoring -R iltiam/iltiam-deployment
   ```

   Then copy some harmless text.

**What you should see:** `✓ Set Actions secret ALERT_DISCORD_WEBHOOK_URL …`. Optional: without it, alerts go by email only. Anyone with the URL can post into that channel, so rotate it (**Webhooks → the webhook → Delete**, then a new one) if it leaks.

## 8. The Watchdog's dead-man check (healthchecks.io, once)

Prometheus can't tell you that Prometheus is down. The rule `Watchdog` always fires, and Alertmanager sends it every 5 minutes to a healthchecks.io check, which emails the team when it stops coming: Prometheus, Alertmanager or the VM is down.

1. healthchecks.io, the project of Runbook 6, section 5 → **Add Check:** name `iltiam-monitoring-watchdog`; **Period** 10 minutes; **Grace** 10 minutes. **Integrations:** email to the team (as Runbook 6's checks).
2. Copy its **ping URL** and paste it at the prompt:

   ```bash
   gh secret set ALERT_HEARTBEAT_URL --env monitoring -R iltiam/iltiam-deployment
   ```

**What you should see:** the check **New** (grey); it turns **Up** within 5 minutes of section 11.

## 9. Object storage used vs the free 20 GB (OCI and Grafana, once)

Prometheus can't see OCI Object Storage. Grafana reads OCI's own `StoredBytes` metric (the one Runbook 8's 70 % alarm uses) through Oracle's signed **OCI Metrics** plugin (pinned in `compose.monitoring.yml`). It signs in as the VM itself (an **instance principal**), so no key is stored anywhere, and it may only read metrics.

### 9.1 OCI: let the VM read metrics

1. **☰ → Compute → Instances →** `iltiam-1` → copy its **OCID** (keep it in your clipboard only).
2. **☰ → Identity & Security → Domains → Default domain → Dynamic groups → Create dynamic group:** name `iltiam-vm`, rule (paste the OCID in place of the placeholder):

   ```
   instance.id = '<INSTANCE_OCID>'
   ```

3. **Identity & Security → Policies**, compartment **root** (the plugin lists compartments) → **Create Policy** `iltiam-vm-read-metrics`, manual editor:

   ```
   Allow dynamic-group 'Default'/'iltiam-vm' to read metrics in compartment iltiam
   Allow dynamic-group 'Default'/'iltiam-vm' to read compartments in tenancy
   ```

**What you should see:** the dynamic group with one rule, the policy with two statements.

### 9.2 Grafana: the data source and the panel (after section 11)

1. Open `https://grafana.iltiamcare.com` (section 13), sign in as `admin`.
2. **Connections → Data sources → Add new data source →** *Oracle Cloud Infrastructure Metrics*. **Name:** `OCI Metrics`. **Environment:** *OCI Instance* (instance principal). **Tenancy mode:** single. **Region:** `me-riyadh-1`. **Save & test.**
3. **Dashboards → New → New dashboard → Add visualization →** `OCI Metrics`:
   - **Compartment** `iltiam`, **Namespace** `oci_objectstorage`, **Metric** `StoredBytes`, **Interval** 1 hour, **Aggregation** max, grouped by bucket (`resourceDisplayName`).
   - Visualization **Time series**, **Stack series: Normal**, **Unit:** bytes (IEC).
   - **Thresholds:** 15032385536 (14 GiB, the 70 % alarm) and 21474836480 (20 GiB, the free limit); **Show thresholds: As lines.**
   - Title `Object storage used vs the free 20 GB` → **Save dashboard** as `ILTIAM object storage`, folder `ILTIAM`.

**What you should see:** one stacked series per bucket that has objects (an empty bucket reports nothing); the top of the stack is about the sum of the buckets' **Approximate Size** in the console.

**If the plugin's form differs** (names change between versions): the settings that matter are the instance principal, single tenancy and `me-riyadh-1`. **If the test fails:** wait 5 minutes (a new policy takes a moment), then check section 9.1. **If it still fails,** use OCI's **Metrics Explorer** for the same query until it is fixed: the alarm doesn't depend on Grafana.

## 10. The VM stopped or reclaimed (OCI alarm, once)

An Always Free VM can be stopped, or reclaimed by Oracle when idle. When it is, nothing on it can alert, so OCI watches it: the VM's CPU metric stops arriving.

**☰ → Observability & Management → Monitoring → Alarm Definitions**, compartment `iltiam` → **Create Alarm:**

| Field | Value |
|---|---|
| Alarm name | `iltiam-instance-down` |
| Severity | Critical |
| Metric: compartment, namespace | `iltiam`, `oci_computeagent` |
| Query (**Switch to Advanced Mode**) | `CpuUtilization[1m]{resourceDisplayName = "iltiam-1"}.absent()` |
| Trigger delay | 5 minutes |
| Destination | Notifications, topic `iltiam-alerts` (Runbook 8, section 12.1) |
| Repeat notification | every 4 hours |

**Save alarm.**

**What you should see:** the alarm **OK** (the VM reports its CPU every minute). **If it shows Firing right away:** the VM's Oracle Cloud Agent isn't sending metrics: **Compute → Instances → `iltiam-1` → Oracle Cloud Agent → Compute Instance Monitoring: Enabled.**

## 11. Deploy the monitoring stack

Only when a person asks for it (AGENTS.md: deploys go through the `deploy` workflow).

```bash
gh workflow run deploy -R iltiam/iltiam-deployment --ref main -f environment=monitoring
```

GitHub holds the run ("This workflow file may be malicious ..."): on the Actions page, someone with write access reviews `deploy.yml` and approves this one run. Then:

```bash
gh run list -R iltiam/iltiam-deployment --workflow deploy -L 1
gh run watch <run id> -R iltiam/iltiam-deployment --exit-status
```

**What you should see** in **Deploy over SSH** (names and sizes only):

```
==> env files
    monitoring.env (600)
==> guards
    ok: deploy lock taken
    ok: monitoring.env: every required setting present
==> metrics networks
    ok: iltiam-metrics-staging (internal)
    ok: made iltiam-metrics-production (internal)
==> render
    ok: targets: staging (profiles 'backend,web')
    ok: alertmanager.yml (email, Discord, heartbeat)
==> docker compose
...
==> running in iltiam-monitoring
SERVICE         IMAGE                                STATUS
alertmanager    prom/alertmanager:v0.34.2            Up ... (healthy)
...
    memory in use: 5xx MiB (issue #10: at most 1.2 GB, about 1229 MiB)
==> monitoring deployed
```

The first run pulls about 1 GB of images. Later runs change only what changed: Prometheus, Alertmanager and the blackbox exporter reread their files, and Loki, Alloy or Grafana restart only when their configuration changed.

**AI logs as JSON** (optional, better log search): set the staging Environment variable `AI_LOG_FORMAT` to `json` (`gh variable set AI_LOG_FORMAT --env staging --body json -R iltiam/iltiam-deployment`) and deploy staging. Alloy then labels the AI service's lines by `level`.

## 12. When an alert fires

Every alert says its environment, and the email and Discord message say what fired. Look in Grafana first (**ILTIAM overview**, then **Explore → Loki** for the logs). On the VM: `bash /srv/iltiam/repo/scripts/compose.sh <env> ps` and `logs --tail 100 <service>`.

| Alert | Severity | What it means | What to do |
|---|---|---|---|
| `TargetDown` | critical | A container's `/metrics` hasn't answered for 2 minutes: it is down, restarting or out of memory | `compose.sh <env> ps`; `logs --tail 100 <service>`; `docker inspect -f '{{.State.OOMKilled}}' <container>`. Runbook 5, section 13 |
| `ServiceNotReady` | critical | The backend's `/api/health/` or the AI api's `/ready` has failed inside the VM for 2 minutes | The AI api: models not loaded, or Redis down (`RedisDown`). The backend: the container (`TargetDown`) |
| `PublicEndpointDown` | critical | A public hostname failed from the internet for 3 minutes | The same check inside the VM passes? Then the tunnel or Cloudflare: Runbook 3, section 14; `compose.sh <env> logs --tail 50 cloudflared` |
| `RedisDown` | critical | The backend can't read Redis for 2 minutes: uploads are not analysed | `compose.sh <env> ps redis`; `logs --tail 50 redis`. A full Redis refuses writes (`OOM command not allowed`): Runbook 5, section 13 |
| `DatabaseErrors` | critical | More than 3 database errors in 5 minutes | `compose.sh <env> logs --tail 100 postgres`: is it up, below `max_connections` (50)? |
| `HighErrorRate` | critical | More than 5 % of the backend's or the AI api's answers are 5xx, at least 5 of them, for 5 minutes | Grafana **Errors** row and the error lines; then that service's logs |
| `AiJobFailures` | warning | AI analyses ended `FAILED` in the last 15 minutes, with their reason | `compose.sh <env> logs --tail 200 ai-worker`; the reasons: iltiam-ai-service `docs/observability.md` |
| `BackendTaskFailures` | warning | A backend Celery task failed | `compose.sh <env> logs --tail 200 backend-worker` |
| `AiQueueSlow` | warning | Photos wait more than 2 minutes (p95) before the AI starts | Is the AI worker running (Runbook 5, section 9.6 stops staging's on purpose)? |
| `HostMemoryHigh` | warning | More than 85 % of the VM's memory in use for 10 minutes | `free -h`, Runbook 5, section 9.5; stop **staging's** AI worker first (section 9.6), never production's |
| `ContainerNearMemoryLimit` | warning | A container uses more than 90 % of its `mem_limit` for 15 minutes | Near the limit the kernel stops it. The limits: Runbook 5, section 2; this runbook, section 1 |
| `ContainerOomKilled` | warning | A container was stopped for going over its limit | As above |
| `DiskSpaceHigh` | warning | `/` or `/srv/iltiam` is more than 80 % full | `df -h`; `docker system df`; `docker image prune` (images no container uses); the logs are capped |
| `BackupTooOld` | critical | The last good nightly backup is more than 26 hours old | `journalctl -u iltiam-backup@<env> -n 50` ([Runbook 6](06-backups.md), section 15) |
| `BackupNeverSucceeded` | critical | A monitored environment has never had a good nightly backup | Runbook 6, sections 6 to 9 aren't done for it yet |
| `BackupFailed` | warning | The last nightly backup or restore test failed | `journalctl -u 'iltiam-*@<env>' -n 100` (Runbook 6, section 15) |
| `RestoreTestTooOld` | warning | No good restore test for 8 days | Runbook 6, sections 13 and 15 |
| `MonitoringTargetDown` | warning | A part of the monitoring stack hasn't answered for 5 minutes | `bash /srv/iltiam/repo/scripts/monitoring.sh ps` and `logs --tail 50 <service>` |
| `AiConfidenceDrift`, `AiDecisionMixDrift`, `AiDecisionReasonDrift`, `AiWoundAreaDrift` | warning | The AI service's weekly figures moved away from their baseline (iltiam-ai-service#151) | iltiam-ai-service `docs/drift-monitoring.md`: alert → threshold report → model-change issue |
| OCI `iltiam-instance-down` | critical | The VM sends no metrics: stopped or reclaimed | OCI console → **Compute → Instances → `iltiam-1`**: **Start**. Then `ssh iltiam` and Runbook 5, section 11.3 |
| OCI `iltiam-object-storage-70pct` | warning | Object storage above 14 GiB | Runbook 8, section 14.1 |
| healthchecks.io `iltiam-monitoring-watchdog` down | | Prometheus or Alertmanager is down, or the VM | `monitoring.sh ps`; if the VM is down, the OCI alarm says so too |

**Silence an alert** you are working on: Grafana → **Alerting → Silences**, **Choose Alertmanager:** `Alertmanager` → **New silence**, matcher `alertname = <name>` (and `env`), for the time you need. A silence never hides other alerts.

## 13. Check the deploy

1. **Grafana behind Access ([Runbook 3](03-cloudflare-tunnels.md), row 17).** Open `https://grafana.iltiamcare.com` in a private window.
   - **What you should see:** Cloudflare's Access page asks for an email. An address on `team-only` gets a 6-digit code, then Grafana's login page: sign in as `admin` (Bitwarden `grafana admin`). An address **not** on the list gets no code.
   - Record it in Runbook 3's **Verified** column, row 17.
   - Make each team member their own Grafana user (**Administration → Users and access → Users → New user**, role *Viewer*, or *Admin* for the owner): the shared `admin` stays for emergencies.
2. **Targets.** Grafana → **Explore** → `Prometheus` → query `up`. **What you should see:** `1` for every series: `ai-api`, `ai-worker`, `backend-web`, `backend-worker` with `env="staging"`, and `node`, `cadvisor` and `monitoring`. And `probe_success`: `1` for each `check`.
3. **Dashboards.** **Dashboards → ILTIAM → ILTIAM overview**, environment `staging`: every row has data within 5 minutes (the latency and AI panels need some traffic: open the staging app). **ILTIAM AI: drift** has data after a week of analyses.
4. **Logs.** **Explore → Loki**, query `{env="staging", service="backend-web"}`: the last lines.
5. **An alert reaches the team.** The `BackupNeverSucceeded` alert fires within the hour if Runbook 6 isn't done yet; otherwise send a test alert (it resolves by itself after 5 minutes):

   ```bash
   ssh iltiam
   sudo -iu deploy bash /srv/iltiam/repo/scripts/monitoring.sh exec -T alertmanager amtool alert add Runbook7Test \
     severity=warning env=staging --annotation=summary="Runbook 7, section 13: test alert" \
     --alertmanager.url=http://127.0.0.1:9093 --end="$(date -u -d '+5 min' +%Y-%m-%dT%H:%M:%SZ)"
   ```

   **What you should see:** within a minute, an email from `ILTIAM monitoring` and a Discord message `[FIRING:1] Runbook7Test`; 5 minutes later a `[RESOLVED]` one.
6. **The Watchdog.** healthchecks.io: `iltiam-monitoring-watchdog` is **Up**.
7. **Memory (acceptance criterion: at most 1.2 GB).** On the VM:

   ```bash
   docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}' | grep -E 'NAME|iltiam-monitoring'
   ```

   **What you should see:** ten lines, each below its limit, and their total below 1.2 GiB (the deploy log prints the total too). Grafana shows up to its limit: most of that is file cache the kernel takes back, not a leak.

## 14. External uptime checks and the status page (UptimeRobot, once)

UptimeRobot (free: 50 monitors, a check every 5 minutes) checks the API from outside Cloudflare's and Oracle's networks, so it sees what a phone sees even when the VM, the tunnel or monitoring is down. **It calls `/api/health/` only**, as the privacy decisions require ([privacy index](../privacy/index.md), 2026-11-13): no sign-in, no personal data ([ROPA](../privacy/ropa.md)). Never `/api/ready/` (section 1). The web app's hostnames are checked by our own blackbox exporter from the VM (`PublicEndpointDown`, `check="app-public"`), not by a third party.

1. Sign up at uptimerobot.com with a **team** address (not a personal one), free plan.
2. **New monitor**, twice, type **HTTP(s)**, interval **5 minutes**:

   | Friendly name | URL |
   |---|---|
   | `ILTIAM API` | `https://api.iltiamcare.com/api/health/` |
   | `ILTIAM staging API` | `https://staging-api.iltiamcare.com/api/health/` |

   **Alert contacts:** the team address (and Discord, if the plan offers it). **Pause `ILTIAM API` until production runs** (#36): an API that isn't deployed is "down".
3. **Status pages → New status page:** name `ILTIAM status`, monitor `ILTIAM API` only (staging is for the team). Publish.
4. **`status.iltiamcare.com`** ([Runbook 2](02-cloudflare-dns-tls.md), section 5): only if the free plan offers a **custom domain** for the status page. Then add the CNAME record it names in Cloudflare **DNS → Records**, as UptimeRobot says (usually **DNS only**, grey cloud, so UptimeRobot serves its own HTTPS certificate). If the free plan doesn't offer it, don't create `status.`; link to the status page's own address instead, and record that in Runbook 2's table.

**What you should see:** `ILTIAM staging API` **Up**; the status page shows `ILTIAM API` as Up once production runs and the monitor is unpaused.

## 15. Each alert in a staged failure (acceptance criterion, staging)

Each alert's rule is tested by `promtool test rules` in CI (`monitoring/prometheus/tests/iltiam.test.yml`). This section proves the whole path on staging: the metric, the rule, Alertmanager, the email and Discord. **Say in the team chat before you start: staging will be unavailable for a few minutes several times.** Do it before production runs on the VM: rows 6 and 7 use the VM's memory and disk.

All commands on the VM: `ssh iltiam`, then `sudo -iu deploy`, then `cd /srv/iltiam/repo`. `C="bash scripts/compose.sh staging"`.

| # | Alert | Staged failure | Expect | Undo |
|---|---|---|---|---|
| 1 | `TargetDown` (ai), `AiQueueSlow` later | `$C stop ai-worker`; wait 3 minutes | `TargetDown` for `ai-worker` (about 2.5 minutes after the stop) | `$C start ai-worker` |
| 2 | `TargetDown` (backend), `ServiceNotReady`, `PublicEndpointDown`, UptimeRobot | `$C stop backend-web`; wait 6 minutes | `TargetDown` `backend-web`, `ServiceNotReady` `backend-health`, `PublicEndpointDown` `api-public`, and UptimeRobot's email for `ILTIAM staging API` | `$C start backend-web`; all `[RESOLVED]` |
| 3 | `RedisDown`, `ServiceNotReady` (ai), `HighErrorRate` (backend) | `$C stop redis`, then from your laptop call the readiness URL every 5 seconds for 7 minutes (it answers 503 while Redis is down; about 85 calls, about 400 object storage requests, once): `for i in $(seq 85); do curl -s -o /dev/null -w '%{http_code} ' https://staging-api.iltiamcare.com/api/ready/; sleep 5; done` | `RedisDown`, `ServiceNotReady` `ai-ready`, then `HighErrorRate` `service=backend` | `$C start redis` (its queue survives: append-only file) |
| 4 | `DatabaseErrors` | `$C stop postgres`; open the staging app and sign in (it fails); wait 5 minutes | `DatabaseErrors` (and `HighErrorRate` if enough requests failed) | `$C start postgres` |
| 5 | `AiJobFailures` | In the staging app, upload a wound photo, and within 2 seconds `$C kill ai-worker`, then `$C start ai-worker` | `AiJobFailures` with `reason="worker_lost"` once the AI service's stale-job sweep fails the job. If the job is retried and completes instead, repeat with `$C stop ai-worker` for 10 minutes after the upload | none |
| 6 | `HostMemoryHigh` | Fill the memory up to about 88 %, for 18 minutes, with a throwaway container that writes into its own memory (`/dev/shm`). First `free -m`; take `MB = 0.88 × total − used` (the `Mem:` line) and set it: `MB=<your number>`. Then `docker run -d --rm --name mem-test --label com.docker.compose.project=iltiam-staging --label com.docker.compose.service=mem-test -m "$((MB * 105 / 100))m" --shm-size "${MB}m" busybox:1.37.0 sh -c "dd if=/dev/zero of=/dev/shm/fill bs=1M count=$MB; sleep 1080"`. Watch `free -m`; **stop it at once** (`docker rm -f mem-test`) if `available` falls under 500 MB | `HostMemoryHigh` after 10 minutes | `docker rm -f mem-test` (it also ends by itself after 18 minutes) |
| 7 | `DiskSpaceHigh` | `df -B1G /srv/iltiam`; take `G = 0.82 × size − used`: `fallocate -l ${G}G /srv/iltiam/monitoring/disk-test` (with your number for `G`; takes no time and writes nothing) | `DiskSpaceHigh` `mountpoint="/srv/iltiam"` after 10 minutes | `rm /srv/iltiam/monitoring/disk-test` |
| 8 | `BackupTooOld` | A status file for a pretend environment `test`, 27 hours old: `printf 'iltiam_backup_last_success_timestamp_seconds{env="test",job="nightly"} %s\n' "$(( $(date +%s) - 97200 ))" > /srv/iltiam/backups/status/test-nightly.prom` | `BackupTooOld` `env="test"` within a minute | `rm /srv/iltiam/backups/status/test-nightly.prom` |
| 9 | Object storage above 70 % (OCI) | Runbook 8's alarm `iltiam-object-storage-70pct` → **Edit**: threshold `1` instead of `15032385536` → **Save** | the OCI email within an hour (`StoredBytes` is hourly) | threshold back to `15032385536` |
| 10 | VM stopped (OCI) | Alarm `iltiam-instance-down` → **Edit**: `resourceDisplayName = "iltiam-none"` (no such VM, so no metric) → **Save** | the OCI email after the 5-minute delay | `resourceDisplayName = "iltiam-1"` |
| 11 | Monitoring down (dead-man) | `bash scripts/monitoring.sh stop alertmanager`; wait 20 minutes | healthchecks.io emails that `iltiam-monitoring-watchdog` is down | `bash scripts/monitoring.sh start alertmanager` |
| 12 | `ContainerNearMemoryLimit` | Row 6's container: it runs at about 95 % of its own limit (`-m` is 105 % of what it fills), and its labels put it in `iltiam-staging` for cAdvisor | `ContainerNearMemoryLimit` `service="mem-test"` after 15 minutes | as row 6 |

**Record on issue #10:** per row, the time of the staged failure, the alert, and the time the email and the Discord message arrived. **Never include** an address, a URL or a value.

## 16. The AI drift check on staging (once, a week)

The drift rules and dashboard come from iltiam-ai-service (`monitoring/AI_SOURCE`). Staging's AI image already writes the drift metrics (it includes iltiam-ai-service#171). The check, from iltiam-ai-service `docs/drift-monitoring.md`, "Synthetic drift on staging":

```bash
python scripts/drift_smoke.py image drift-no-wound.jpg            # on a clone of iltiam-ai-service
scp drift-no-wound.jpg drift_smoke.py iltiam:/tmp/
ssh iltiam
sudo -iu deploy
C="bash /srv/iltiam/repo/scripts/compose.sh staging"
$C cp /tmp/drift-no-wound.jpg ai-api:/tmp/drift-no-wound.jpg
$C exec -T ai-api python - send --image /tmp/drift-no-wound.jpg --count 60 < /tmp/drift_smoke.py
```

**What you should see:** the script ends with `decisions: {'INSUFFICIENT': 60}`. About 7 hours later, `AiConfidenceDrift` and `AiDecisionMixDrift` fire for `env="staging"` and reach email and Discord. Record it in section 18, row 12, then **silence both** for 8 days (section 12): the 60 analyses stay in the 7-day window. If nothing fires, iltiam-ai-service `docs/drift-monitoring.md` lists four checks.

## 17. Day to day

### 17.1 The stack

On the VM as `deploy`: `M="bash /srv/iltiam/repo/scripts/monitoring.sh"`.

```bash
$M ps                       # every service Up (healthy)
$M logs --tail 100 grafana  # one service's log
$M restart alloy            # one service
```

`$M config` is refused unless it prints no secret (`--quiet`, `--services`, `--images`). Changes reach the VM only through a PR and a monitoring deploy (section 11), never by editing the VM's clone.

### 17.2 Logs

Grafana → **Explore → Loki**. Labels: `env` (`staging`, `production`, `monitoring`), `project`, `service`, `container`, `stream`, and `level` for the AI service's JSON lines. Examples:

```
{env="staging", service="backend-web"} |= "ERROR"
{env="staging", service=~"ai-.*", level="ERROR"}
{env="staging"} |= "<request id>"
```

Lines are kept 7 days. For an incident, export the result first ([incident response](../security/incident-response.md), section 7): Loki deletes them on time.

### 17.3 Changing a rule, a dashboard or a limit

A PR: `monitoring/` and `compose.monitoring.yml`, with `scripts/ci-local.sh --full` (it runs `scripts/check-monitoring.sh`: promtool tests, Compose rules, the 1228 MiB total). Then section 11. A new alert needs a test in `monitoring/prometheus/tests/iltiam.test.yml`.

### 17.4 The AI drift files

`monitoring/prometheus/rules/ai-drift*.yml`, `monitoring/prometheus/tests/ai-drift.test.yml` and `monitoring/grafana/dashboards/ai-drift.json` are copies from iltiam-ai-service, at the commit in `monitoring/AI_SOURCE`. **Never edit them here.** When the AI service changes them, copy them again from the commit of the AI image staging runs, then run the checks and open a PR:

```bash
bash scripts/sync-ai-monitoring.sh ../iltiam-ai-service <commit>    # rewrites monitoring/AI_SOURCE too
bash scripts/check-monitoring.sh
```

### 17.5 Production (when it runs, #36)

1. `gh variable set MONITORED_ENVIRONMENTS --env monitoring --body staging,production -R iltiam/iltiam-deployment`.
2. Deploy monitoring (section 11). Production's targets appear as its profiles turn on (`env/production.versions`).
3. UptimeRobot: unpause `ILTIAM API` (section 14).
4. Section 13, rows 2 and 3, with `production`. The go-live checklist's monitoring row: stop production's AI worker for 5 minutes, on purpose, and record the alert email's time.

## 18. Verification checklist

| # | Check | How | Expected | When | Verified |
|---|---|---|---|---|---|
| 1 | CI | the PR's checks | `scripts/ci-local.sh --full` PASS, including `check-monitoring.sh` (promtool test rules) and `check-compose.sh` (the metrics network rules) | this PR | |
| 2 | Monitoring tunnel | section 4 | `iltiam-monitoring` Healthy, one route `grafana.iltiamcare.com` | after section 11 | |
| 3 | Access in front of Grafana | section 13, step 1 | a code for a team address, none for another; Runbook 3 row 17 filled | after section 11 | |
| 4 | Targets and probes | section 13, step 2 | every `up` and `probe_success` is 1 | after section 11 | |
| 5 | Dashboards | section 13, step 3 | ILTIAM overview with data in every row; ILTIAM AI: drift | after section 11 | |
| 6 | Logs | section 13, step 4 | staging's lines in Loki | after section 11 | |
| 7 | Alert delivery | section 13, step 5 | the test alert by email and in Discord, then resolved | after section 11 | |
| 8 | Monitoring at most 1.2 GB (acceptance criterion) | section 13, step 7 | total of `docker stats` below 1.2 GiB | after section 11, and after a week | |
| 9 | Each alert in a staged failure (acceptance criterion) | section 15 | rows 1 to 12, each with its alert's time | staging | |
| 10 | External uptime and status page | section 14 | `ILTIAM staging API` Up; status page published | console | |
| 11 | OCI alarms | sections 9, 10 | `iltiam-instance-down` OK; object storage dashboard shows the buckets | console | |
| 12 | AI drift (iltiam-ai-service#151 hand-off) | section 16 | both drift alerts fired for staging, then silenced | a week | |
| 13 | Production | section 17.5 | rows 4, 5 and 8 for production | after #36 | |

**Record the results on issue #10:** pass or fail per row, with the date. **Never include** an address, a URL, a token or an OCID.

## 19. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| The deploy stops at `must exist, mode 700` or `must exist and be writable` | Section 3 |
| `missing from monitoring.env: …` | The named secrets or variable aren't in the Environment `monitoring` (sections 4 to 8); set them and deploy again |
| `network iltiam-metrics-staging declared as external, but could not be found` on a staging deploy | An older `scripts/deploy.sh` ran: deploy staging from `main` again (it makes the network) |
| Every `ai-api`/`backend-web` target is down, `no such host` | Staging hasn't been deployed since this runbook's PR: its containers aren't on the metrics network yet (section 2) |
| `probe_success` 0 for `backend-health` with a 400 | The backend refused the `Host` header: `ALLOWED_HOSTS` of staging must contain `staging-api.iltiamcare.com` (`monitoring/blackbox/blackbox.yml`) |
| `PublicEndpointDown` but UptimeRobot is Up | Cloudflare may challenge the VM's address: **Security → Events**, filter by the VM's IP; allow the user agent `iltiam-monitoring` in a WAF skip rule (Runbook 3, section 7.2) |
| Grafana shows **Bad gateway** or Cloudflare error 1033 | The tunnel: `$M ps cloudflared`, `$M logs --tail 50 cloudflared`. Error 1033: no connector; check `MONITORING_TUNNEL_TOKEN` |
| No email, but Discord works | `$M logs --tail 50 alertmanager`: `535 Authentication credentials invalid` → section 6, new credential. `554 … not authorized` → the user is not in `iltiam-smtp-senders` |
| Neither email nor Discord | `$M ps alertmanager`; Grafana → **Alerting → Alert rules** shows the alert *Firing*? If not, the rule's `for` hasn't passed yet |
| cAdvisor panels empty | `$M logs cadvisor \| grep -i factory`: the Docker factory must register. `containerd.sock: no such file` → section 3 |
| No logs in Loki | `$M logs --tail 50 alloy`: `403 Forbidden` → the proxy lacks a permission (`docker-proxy` environment in `compose.monitoring.yml`) |
| `ContainerNearMemoryLimit` for Grafana | Grafana counts file cache (section 13, step 7). Only an OOM kill (`ContainerOomKilled`) means a real problem |
| Prometheus' disk grows | `--storage.tsdb.retention.size=6GB` caps it. More series than expected: Grafana → Explore → `topk(10, count by (__name__)({__name__=~".+"}))` |

## 20. Security and privacy

- **No public port.** Grafana is reachable only through its tunnel and Cloudflare Access, then its own login. Prometheus, Alertmanager, Loki and the rest have no route from the internet; their APIs have no authentication, so they must stay on internal networks (`scripts/check-monitoring.sh` checks).
- **Monitoring never reaches the data.** Prometheus and the blackbox exporter are on the environments' metrics networks only, where Postgres and Redis are not. Grafana and Loki are on neither.
- **Docker access is narrowed.** Only `docker-proxy` opens the Docker socket and passes on read-only calls (no POST: no container can be made, started or exec'd). cAdvisor reads containerd's socket, which is root-equivalent (section 1, "Decisions").
- **No personal data in metrics.** Labels come from fixed lists (iltiam-ai-service `docs/observability.md`; django-prometheus labels views, never paths). Alert messages carry names, environments and numbers only.
- **Logs may hold user ids and IP addresses** (never codes or passwords, iltiam-backend#24, iltiam-ai-service#121): the same as Docker's own log files ([ROPA](../privacy/ropa.md) row 17). Loki keeps them 7 days on the VM in Riyadh ([retention](../privacy/retention.md) row 17).
- **Outside services receive no user data:** UptimeRobot calls `/api/health/` only; healthchecks.io receives the Watchdog's alert (names only); Discord receives the alert messages.
- **Secrets:** [docs/secrets.md](../secrets.md), section 2 (Environment `monitoring`).

## 21. What comes next

- **#36 (production):** section 17.5.
- **Go-live checklist:** the monitoring row (stop production's AI worker for 5 minutes, record the alert email).
- **Later, if Grafana gets more users:** sign in through Cloudflare Access itself (Grafana's JWT login with the `Cf-Access-Jwt-Assertion` header), so Grafana has no password of its own.
