# Runbook 13: the production environment on the VM

Everything production (`iltiam-prod`) needs before its first real release, in order, with what is already done
(issue #36). Production runs from the same [`compose.yml`](https://github.com/iltiam/iltiam-deployment/blob/main/compose.yml)
as staging, as a second Compose project ([Runbook 5](05-compose-stack.md)); there is no production-only compose file,
on purpose: the two environments differ only in their GitHub Environment, `env/production.versions` and their data
folder. Releases after this: [Runbook 10](10-production-release.md).

**Not before the Dec 1 demo.** Nothing here changes staging, but the first production deploy shares the VM's memory
with the staging the demo uses. Start section 6 after the demo.

## As built (2026-11-23)

| Item | State |
|---|---|
| GitHub Environment `production` | Exists, with a required reviewer. Secrets set: the generated ones (`SECRET_KEY`, `JWT_SECRET_KEY`, `FIELD_ENCRYPTION_KEY`, `AI_SERVICE_TOKEN`, `DJANGO_SECRET_KEY`, the three database passwords), `CF_TUNNEL_TOKEN`, `TURNSTILE_SECRET_KEY`. **No variables yet** |
| Missing secrets | `STORAGE_ENDPOINT_URL`, `STORAGE_ACCESS_KEY`, `STORAGE_SECRET_KEY`, `MASK_UPLOAD_ALLOWED_HOSTS` (section 3.1), `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD` (3.2), `AUTHENTICA_API_KEY` (3.3), `WEIGHTS_READ_TOKEN` (3.5); and `FCM_SERVICE_ACCOUNT_JSON` (3.4, not in a template). Since #8, also the backup settings (3.6) |
| Variables | Ready in [`env/production.vars`](https://github.com/iltiam/iltiam-deployment/blob/main/env/production.vars), set with `scripts/set-env-vars.sh` (section 2). Two wait for you: `AUTHENTICA_SENDER_NAME` (decision) and `TURNSTILE_SITE_KEY` (the widget's site key) |
| `env/production.versions` | AI `sha-0d1861e`; backend and web `to-confirm`; `COMPOSE_PROFILES=` empty (AI only) |
| Tunnel `iltiam-prod`, DNS `app.` and `api.` | Runbook 3 |
| Production deployed | **No** |

The table's "missing" lines come from Runbook 4, section 10.2, run on 2026-11-23: it prints names only.

## 1. Decisions first

| Decision | Options | Where it lands |
|---|---|---|
| Production SMS sender | A Commercial Registration and an approved sender name (Runbook 12, section 12); or a separate Authentica account; production refuses to start the backend without a sender name | `AUTHENTICA_SENDER_NAME` in `env/production.vars` |
| Who is the controller (legal L1) and SDAIA (L2) | [privacy overview](../privacy/index.md#legal-review-before-public-launch) | Before real patients (#23), not before the first deploy |
| When | After the Dec 1 demo, outside clinic hours | Section 6 |

## 2. Variables

From your clone, after this runbook's PR is merged:

```bash
scripts/set-env-vars.sh production env/production.vars            # dry run: lists add / change / skip
scripts/set-env-vars.sh production env/production.vars --apply    # sets them
```

**What you should see:** 28 `add` lines and 2 `skip` (the two `TO-...` values) on the first dry run; after `--apply`,
the next dry run says `same` for each. When a `TO-...` value is decided, change it in `env/production.vars` in a PR,
then `--apply` again.

## 3. Secrets, one provider at a time

Each with `gh secret set <NAME> --env production -R iltiam/iltiam-deployment` (it asks for the value; nothing on the
command line, nothing in a file of this repository).

### 3.1 Object storage (Runbook 8)

1. [Runbook 8, section 9.6](08-object-storage.md): group and user `iltiam-prod-storage`, policy `iltiam-storage-prod`
   with the five `iltiam-prod-…` bucket names, its Customer Secret Key. The buckets themselves exist (section 7 there).
2. Section 10 there: the probe with `production`.
3. Section 11 there: `STORAGE_ENDPOINT_URL`, `STORAGE_ACCESS_KEY`, `STORAGE_SECRET_KEY`, `MASK_UPLOAD_ALLOWED_HOSTS`.
4. Lifecycle rules on `iltiam-prod-reports` (section 8 there, #65).

### 3.2 Email (Runbook 2, section 11)

A production SMTP user in OCI Email Delivery (its own, never staging's), then `EMAIL_HOST_USER` and
`EMAIL_HOST_PASSWORD`. Approved sender `no-reply@iltiamcare.com` is shared by both environments (same domain).

### 3.3 Authentica (Runbook 12, sections 4.2, 4.3 and 7)

Production's own Authentica application and API key: `AUTHENTICA_API_KEY`. The sender name: section 1.

### 3.4 Firebase push (Runbook 11)

The production Firebase project's service account: `FCM_SERVICE_ACCOUNT_JSON` (secret first, then the variable, as
Runbook 11 says). The deploy writes it next to the env files and `compose.fcm.yml` mounts it.

### 3.5 Weights (docs/secrets.md, section 6.6)

A fine-grained token with read access to iltiam-ai-service's releases, production's own: `WEIGHTS_READ_TOKEN`.

### 3.6 Backups (Runbook 6, #8)

**The first production deploy needs these:** they are `prod-required` in `env/backup.env.example`, because production
takes no real patient data before its backups work. [Runbook 6, section 11](06-backups.md): the lifecycle rules on
`iltiam-prod-backups`, the backup user `iltiam-prod-backup` and its key, the two dead-man checks, the age key pair
(escrowed), then `BACKUP_STORAGE_ACCESS_KEY`, `BACKUP_STORAGE_SECRET_KEY`, `BACKUP_AGE_IDENTITY`, `BACKUP_PING_URL`,
`BACKUP_RESTORE_PING_URL` (secrets) and `BACKUP_AGE_RECIPIENT` (variable). After the first deploy, the timers:
`sudo bash /srv/iltiam/repo/scripts/install-backup-timers.sh production`.

### 3.7 Check: nothing missing

Runbook 4, section 10.2 with `ENV=production`: both commands print nothing. Then `gh secret list --env production`
lists `FCM_SERVICE_ACCOUNT_JSON` too.

## 4. The deploy key and the VM's address

[Runbook 5, section 5](05-compose-stack.md): the production deploy key on the VM, `DEPLOY_SSH_KEY`,
`DEPLOY_SSH_KNOWN_HOSTS` and `DEPLOY_HOST` in the `production` Environment (`DEPLOY_HOST` is a secret: it holds the
VM's address).

## 5. The VM

As `ubuntu`, once (Runbook 5, section 4.2 makes both environments' folders; check that production's exist):

```bash
sudo stat -c '%a %U:%G %n' /srv/iltiam/production /srv/iltiam/env/production
free -h
```

**What you should see:** `700 deploy:deploy` twice, and with staging running idle, at least 5 GB available (Runbook 5,
section 2: production needs about 3.2 GB idle, more during an analysis).

## 6. First deploy: the AI service only

`env/production.versions` already has `COMPOSE_PROFILES=` (AI only). [Runbook 5, section 8](05-compose-stack.md):
deploy production, approve the reviewer's hold, check the seven services.

## 7. Backend and web on: release v1.0.0

[Runbook 10, section 4](10-production-release.md): `scripts/release.sh promote all`, set `COMPOSE_PROFILES=backend,web`
in `env/production.versions` by hand in the same PR, `scripts/release.sh prepare 1.0.0`, approval, deploy, smoke.
**No real patient data yet:** the go-live checklist (#23) decides that.

## 8. The checks of #36

Write each result in #36, with the date.

| # | Check | How |
|---|---|---|
| 1 | Both projects healthy at the same time | `iltiam staging ps` and `iltiam production ps`: every service healthy |
| 2 | `docker stats` total under 10 GB at idle | Runbook 5, section 9.5, both projects idle |
| 3 | Breaking staging does not affect production | Runbook 5, section 11.2: stop staging's Postgres, production's `/api/ready/` stays `ready`, start it again |
| 4 | Re-running a deploy with the same tags changes nothing | Runbook 5, section 11.1 for production: no container recreated |
| 5 | Read-only smoke | `scripts/smoke-readonly.sh production` (#19) |
| 6 | Runbook 3 row 7 | `iltiam-prod` Healthy, one connector |
| 7 | Rows 22 and 23 | `https://api.iltiamcare.com/api/health/` ok with `cf-cache-status` DYNAMIC or BYPASS twice; `https://app.iltiamcare.com` 200 with a CSP |
| 8 | Rows 24 and 25 | Runbook 3, sections 11.2 and 11.3, on `app.` and `api.` |
| 9 | Row 16 | `api.iltiamcare.com/admin/` 302 to Cloudflare Access; `/api/health/` 200 |
| 10 | Row 26 | Runbook 3, section 11.4 with `iltiam-prod_edge` |
| 11 | Row 27 | `NUM_PROXIES=1` (set in section 2), then Runbook 3, section 11.5 and the second-visitor check |
| 12 | Rows 20 and 21 | Again, with both projects running |
| 13 | Row 28 | HSTS on `app.` and `api.` (`SECURE_HSTS_SECONDS=15552000`, section 2) |
| 14 | Storage | `iltiam production exec backend-web python manage.py check_storage`: `All storage checks passed.` (Runbook 8, section 13, row 19) |
| 15 | Secrets differ | `scripts/check-env-differ.sh` on the VM (#23) |

## 9. Gaps found while preparing this

- `RETENTION_ENFORCE` (#66) is not in `env/backend.env.example` yet, so the deploy cannot set it in production. Add it
  to the template with #66, as `var, optional`, then to `env/production.vars`.
- Production's Turnstile widget: its secret key is set, its site key must be copied into `env/production.vars`
  (Runbook 2, section 10).
