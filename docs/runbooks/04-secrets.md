# Runbook 4: secrets and environment files (GitHub Environments, rotation, third-party keys)

- **Issue:** iltiam/iltiam-deployment#3 (DEP#3). **Inventory, owners, rotation, revocation:** [`docs/secrets.md`](../secrets.md).
- **Who:** anyone on the team with admin rights on `iltiam/iltiam-deployment`. No cloud experience needed; follow the steps in order.
- **Time:** about 1.5 hours the first time, then a few minutes for each third-party secret as its runbook is done.
- **Result:** two GitHub Environments, `staging` and `production` (production waits for a reviewer before any deploy). They hold every secret and setting the env templates in [`env/`](../../env/) name, plus an escrow copy in Bitwarden of what can't be regenerated. The deploy workflow ([Runbook 5](05-compose-stack.md); automated later by Runbooks 9 and 10) turns them into `/srv/iltiam/env/<staging|production>/*.env` on `iltiam-1`.

> **This repository is public. Never paste a secret into this runbook, an issue, a PR, a commit, a chat or a workflow log.** Use the placeholders below. A secret pasted anywhere public counts as leaked: rotate it (`docs/secrets.md`, section 7). Deleting the text doesn't help.

| Placeholder | Meaning |
|---|---|
| `<NAMESPACE>` | The OCI Object Storage namespace ([Runbook 8](08-object-storage.md), section 4.1: Governance & Administration → Tenancy details → Object storage namespace) |
| `<ENV>` | `staging` or `production` |

GitHub moves menus between releases. If a menu below is not where this says, look for its name on the same page.

## 1. How it works

```
GitHub Environment  ──deploy workflow──▶  scripts/render-deploy-env.sh  ──SSH──▶  /srv/iltiam/env/<ENV>/*.env  ──▶  docker compose
(secrets + variables)    (Runbook 5)         (on the runner)                       (700 dir, 600 files, deploy)
```

- **Four templates** in `env/` list every variable by name, each with a one-line comment and **no values**:

  | Template | Becomes | Used by |
  |---|---|---|
  | `env/backend.env.example` | `backend.env` | backend web, worker, beat, migrate |
  | `env/ai.env.example` | `ai.env` | AI api, worker, beat |
  | `env/web.env.example` | `web.env` | the web container (nothing secret: browsers see all of it) |
  | `env/infra.env.example` | `infra.env` | Compose itself: DB passwords, tunnel token, weights token |

- **The comment above each variable says what to do with it:**
  - `secret, …` → an **Environment secret**. `var, …` → an **Environment variable**. The name in GitHub is exactly the name in the template.
  - `required`: needed in both environments.
  - `prod-required`: production needs it; staging may skip it until its provider is set up.
  - `optional`: leave it out unless you know why you want it; the app's default applies.
  - `staging-only`: staging only. Production refuses to start if it is set.
- **One secret can fill two files.** `AI_SERVICE_TOKEN` is one secret; it goes into both `backend.env` and `ai.env`.
- **Workflow-only secret:** `FCM_SERVICE_ACCOUNT_JSON` is in no template. The deploy writes it as a file (`docs/secrets.md`, section 1).

## 2. Before you start

- **Admin rights** on `iltiam/iltiam-deployment` (needed for Settings → Environments).
- **Git Bash** (comes with Git for Windows). Run every command below in Git Bash, not PowerShell, from the repository folder.
- **openssl** in Git Bash: `openssl version` prints `OpenSSL 3.x`. Git for Windows ships it. You don't need Python.
- **GitHub CLI**, optional but recommended: `gh auth status` says "Logged in to github.com". With it, values go straight into GitHub without your clipboard.
- **Docker Desktop**, only for the local check in section 10.
- **Access to the Bitwarden organisation "ILTIAM"** (ask ben-fatah or Omar-Nasri).

## 3. Rules for secrets in this repository

1. **Never print a secret in GitHub Actions.** The repository is public, so its logs are public:
   - no `set -x` or `bash -x` in a step that has secrets in its environment;
   - no `echo`, `cat` or `env` of a value or of a rendered env file;
   - `docker compose config` only with `--quiet`; `docker login` only with `--password-stdin`;
   - gitleaks only with `--redact`;
   - GitHub hides registered secrets in logs, but **not** values made from them (base64, URLs). A workflow that builds one masks it first with `echo "::add-mask::$VALUE"`.
2. **Never use `pull_request_target` with a checkout of PR code.** Forks' PRs would get the secrets.
3. **Staging and production never share a value.**
4. **GitHub secrets can't be read back.** What can't be regenerated also goes to Bitwarden (section 11).
5. **After a value was on your screen, run `clear`.**

## 4. Make the repository public (once, owner only)

Environment secrets, variables and required reviewers need a **public** repository on the GitHub Free plan. This repository becomes public once issue #3 is merged.

1. **Scan the whole history first** (Docker Desktop running, in Git Bash, from the repository folder):

   ```bash
   MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/repo" ghcr.io/gitleaks/gitleaks:v8.30.1 \
     git /repo --redact --no-banner --verbose
   ```

   **What you should see:** `no leaks found` at the end. **Anything else: stop.** Rotate whatever it found and ask the owner how to rewrite the history before going public.
2. **Settings → General →** (bottom) **Danger Zone → Change repository visibility → Change visibility → Make public**, and confirm.
3. **What you should see:** a **Public** label next to the repository name.

## 5. Create the two Environments

### 5.1 `staging`

1. **Settings →** (left, under "Code and automation") **Environments → New environment.** Name: `staging` → **Configure environment.**
2. **Deployment branches and tags:** choose **Selected branches and tags → Add deployment branch or tag rule.** Ref type **Branch**, name pattern `main` → **Add rule.**
3. Leave **Required reviewers** off: staging deploys automatically (Runbook 9).

### 5.2 `production`

1. **Environments → New environment.** Name: `production` → **Configure environment.**
2. **Deployment protection rules:**
   - **Required reviewers: on.** Add **ben-fatah**.
   - **Prevent self-review: off.** For now ben-fatah both starts and approves production deploys.
   - **Allow administrators to bypass configured protection rules: off.**
   - **Save protection rules.**
3. **Deployment branches and tags:** **Selected branches and tags.**
   - Add a rule: Ref type **Branch**, name pattern `main`.
   - Add a second rule: Ref type **Tag**, name pattern `v*`.

**Later, a second reviewer:** to add Omar-Nasri, open **Environments → production → Required reviewers**, add `Omar-Nasri` and **Save protection rules**. Once there are two reviewers, consider turning **Prevent self-review** on, so nobody approves their own deploy. Up to six people or teams can be reviewers.

**What you should see:** **Settings → Environments** lists `staging` and `production`, and `production` shows "1 protection rule" (the reviewer) and its branch rules.

## 6. Generate the random secrets

Do this **once for staging, then again for production**. The script makes new values on every run.

1. In Git Bash, from the repository folder:

   ```bash
   bash scripts/bootstrap-secrets.sh staging
   ```

2. **What you should see:** comment lines, then 8 lines `NAME=value` grouped by file: `SECRET_KEY`, `JWT_SECRET_KEY`, `FIELD_ENCRYPTION_KEY`, `AI_SERVICE_TOKEN`, `DJANGO_SECRET_KEY`, `POSTGRES_PASSWORD`, `BACKEND_DB_PASSWORD`, `AI_DB_PASSWORD`. `FIELD_ENCRYPTION_KEY` is 44 characters ending in `=`; the others are hex.
3. For each line: **Settings → Environments → staging → Environment secrets → Add environment secret.** **Name:** the text left of `=`. **Value:** everything right of it, nothing else (no spaces, no quotes). **Add secret.**
   - With the GitHub CLI instead: `gh secret set SECRET_KEY --env staging -R iltiam/iltiam-deployment`, paste the value at the prompt, Enter.
4. **`FIELD_ENCRYPTION_KEY`: also save it in Bitwarden now** (section 11). It can never be changed and GitHub can't show it again.
5. `clear`.
6. Repeat steps 1 to 5 with `production`.

**Never** redirect the script into a file (`> secrets.txt`). If you did, delete the file and run the script again: those values count as exposed.

## 7. Third-party secrets

Each one comes from its own runbook. Add it to **both** Environments, each with its own value, when that runbook is done.

- **Needed before the first staging deploy** (`required` in the templates): the storage keys, `CF_TUNNEL_TOKEN`, `TURNSTILE_SECRET_KEY` and `WEIGHTS_READ_TOKEN`.
- **Can wait on staging** (`prod-required`): Authentica, SMTP and Firebase. Until they exist, the staging backend prints SMS, push and email to its log instead (section 9 table).
- **Production refuses to start** until every `prod-required` one is set.

| Secret (Environment secret) | From | Runbook / issue |
|---|---|---|
| `STORAGE_ACCESS_KEY`, `STORAGE_SECRET_KEY` | OCI Customer Secret Key of the environment's storage user | [Runbook 8](08-object-storage.md) (DEP-02), sections 9.5 and 11 |
| `STORAGE_ENDPOINT_URL`, `MASK_UPLOAD_ALLOWED_HOSTS` | Built from the Object Storage namespace; secrets only so the namespace never shows in this public repository's logs | [Runbook 8](08-object-storage.md), section 11 |
| `CF_TUNNEL_TOKEN` | Cloudflare Zero Trust, tunnel `iltiam-staging` / `iltiam-prod` | [Runbook 3](03-cloudflare-tunnels.md) (#9), section 3 |
| `AUTHENTICA_API_KEY` (plus the variable `AUTHENTICA_SENDER_NAME`) | Authentica dashboard | Runbook 12 (DEP-14) |
| `TURNSTILE_SECRET_KEY` (plus the variable `TURNSTILE_SITE_KEY`) | Cloudflare → Turnstile, one widget per environment | [Runbook 2](02-cloudflare-dns-tls.md) (DEP-01), section 10 |
| `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD` | OCI Email Delivery SMTP credentials of the environment's own SMTP user (**pending SMTP provider**) | [Runbook 2](02-cloudflare-dns-tls.md) (DEP-01), section 11.5 |
| `FCM_SERVICE_ACCOUNT_JSON` | Firebase → Project settings → Service accounts → Generate new private key | Runbook 11 (DEP-13) |
| `WEIGHTS_READ_TOKEN` | Fine-grained PAT, **one per environment**: only `iltiam-ai-service`, Contents read-only, 1-year expiry | `docs/secrets.md`, section 6.6 |
| `STAGING_TEST_PASSWORD` (staging only) | You choose it; it must meet the password policy | backend `docs/deployment.md` |
| `DEPLOY_SSH_KEY`, `DEPLOY_SSH_KNOWN_HOSTS`, `DEPLOY_HOST` | The environment's own deploy key, the VM's host key line, the VM's address | [Runbook 5](05-compose-stack.md) (#2), section 5 |

**A JSON key file** (Firebase): don't paste it by hand. Use `gh secret set FCM_SERVICE_ACCOUNT_JSON --env staging -R iltiam/iltiam-deployment < <FILE>.json`, then delete the file from Downloads and empty the recycle bin.

**Mobile secrets** (`google-services.json` per flavor, the Android upload keystore) go into the **iltiam-mobile** repository's secrets, not here (`docs/secrets.md`, section 3).

## 8. Let the deploy job pull images from GHCR

No registry token is stored. The deploy job uses its own `GITHUB_TOKEN`, which only lives as long as the job. It logs in on the VM with `--password-stdin`, pulls, and logs out. For that, each image package must allow this repository to read it. Do this **once per package**, and again whenever a new package appears (the web image with WEB-03, name TO CONFIRM):

1. github.com → **iltiam** organisation → **Packages** → the package (`iltiam-ai-api`, `iltiam-ai-worker` and `iltiam-backend`; all three have it since 2026-10-31).
2. **Package settings → Manage Actions access → Add Repository** → `iltiam-deployment` → role **Read.**
3. **What you should see:** `iltiam-deployment` listed with role **Read**.

**If you skip it:** the deploy fails at the pull with `denied` or `unauthorized`.

## 9. Environment variables (not secret)

**Settings → Environments → `<ENV>` → Environment variables → Add environment variable**, or `gh variable set NAME --env <ENV> --body "VALUE" -R iltiam/iltiam-deployment`.

These are the values to set. Every other `var` in the templates is `optional`: leave it out.

| Variable | staging | production |
|---|---|---|
| `ENVIRONMENT` | `staging` | `production` |
| `ALLOWED_HOSTS` | `staging-api.iltiamcare.com` | `api.iltiamcare.com` |
| `CORS_ALLOWED_ORIGINS`, `CSRF_TRUSTED_ORIGINS` | `https://staging-app.iltiamcare.com` | `https://app.iltiamcare.com` |
| `NUM_PROXIES` | `1` (confirmed by the header test in [Runbook 3](03-cloudflare-tunnels.md), section 8) | `1` |
| `STORAGE_REGION` | `me-riyadh-1` | same |
| `STORAGE_BUCKET_WOUND_IMAGES`, `…_WOUND_MASKS`, `…_REPORTS`, `…_PRESCRIPTIONS`, `…_PROFILE_PHOTOS` | `iltiam-staging-wound-images`, `-wound-masks`, `-reports`, `-prescriptions`, `-profile-photos` | `iltiam-prod-wound-images`, `-wound-masks`, `-reports`, `-prescriptions`, `-profile-photos` ([Runbook 8](08-object-storage.md), section 7) |
| `AI_MASK_UPLOAD_ENABLED` | `True` | `True` |
| `ACTIVATION_LINK_BASE_URL` | `https://staging-app.iltiamcare.com/activate` (set 2026-10-31; TO CONFIRM, below) | `https://app.iltiamcare.com/activate` (TO CONFIRM, below) |
| `SMS_BACKEND` | leave out until Runbook 12, then as production | `apps.notifications.sms.AuthenticaSMSBackend` |
| `AUTHENTICA_SENDER_NAME` | the approved sender name | same |
| `PUSH_BACKEND` | leave out until Runbook 11, then as production | `apps.notifications.push.FCMPushBackend` |
| `EMAIL_BACKEND` | leave out until Runbook 2's SMTP, then as production | `django.core.mail.backends.smtp.EmailBackend` |
| `EMAIL_HOST`, `EMAIL_PORT`, `DEFAULT_FROM_EMAIL` | OCI Email Delivery's Riyadh SMTP endpoint (Runbook 2, section 11.2), `587`, `ILTIAM Staging <no-reply@iltiamcare.com>` | same host and port, `ILTIAM <no-reply@iltiamcare.com>` |
| `TOTP_ISSUER` | `ILTIAM Staging` | leave out (`ILTIAM`) |
| `OTP_DEV_ECHO_NUMBERS` | the line `manage.py seed_staging` prints | **never** (production refuses it) |
| `ALLOW_SYNC` | `0` | `0` |
| `AI_API_WORKERS`, `AI_WORKER_CONCURRENCY` | `1`, `1` | `1`, `1` |
| `ILTIAM_TISSUE_ENABLED` | `0` | `0` |
| `API_BASE_URL` (name TO CONFIRM, WEB-03) | `https://staging-api.iltiamcare.com/api` | `https://api.iltiamcare.com/api` |
| `TURNSTILE_SITE_KEY` (name TO CONFIRM, WEB-03) | the staging widget's site key | the production widget's site key |

**`ACTIVATION_LINK_BASE_URL`: TO CONFIRM with the web team (WEB-05).** The backend emails `<ACTIVATION_LINK_BASE_URL>?token=<token>` to an invited clinic admin or Super Admin. The web app has no such page yet: an unknown path redirects to `/`, which drops the token. Until WEB-03 runs the web app, `staging-app` answers 502 anyway, and staging's console email backend writes the link only to the backend's log. Questions for the web team:

1. Is the page's path `/activate`, or something else (for example `/set-password`)?
2. Does it read the query parameter `token`? The base URL must not contain a `?` of its own.
3. Is the page public, outside the role guards (no sign-in needed)?
4. Which backend endpoint does it call to set the first password?
5. How does it handle an expired or used link? The link lasts 24 hours (`INVITATION_TTL_HOURS`).

Change the variable in both Environments once they answer, and deploy.

`STORAGE_ENDPOINT_URL` and `MASK_UPLOAD_ALLOWED_HOSTS` are **secrets**, not variables, because they contain the storage namespace: [Runbook 8](08-object-storage.md), section 11 sets them.

**Type values exactly**, with no quotes around them and no trailing spaces. A value must not contain a single quote `'` or a line break; the deploy refuses those.

**What a deploy needs today** ([Runbook 5](05-compose-stack.md)): `infra.env` and `ai.env` always; `backend.env` only while `env/<ENV>.versions` turns the backend on (staging now, production after DEP-13, DEP-14 and SMTP). `web.env` (`API_BASE_URL`, `TURNSTILE_SITE_KEY`) is written once the web service exists (WEB-03), so its variables can wait until then.

## 10. Check your work

### 10.1 The templates and scripts (on your laptop)

With Docker Desktop installed and running:

```bash
bash scripts/check-env.sh
```

**What you should see:** sections starting with `==>`, each with `ok:` lines, and at the end `==> all checks passed`. It uses dummy values only. It checks that:
- the templates are well formed;
- `bootstrap-secrets.sh` makes values of the right shape;
- both environments render and pass `docker compose config`;
- what must be refused is refused.

### 10.2 Nothing missing in GitHub (AC: a new environment from the templates alone)

List what an environment needs, straight from the templates. `must` means "add it now"; `may` means optional, or staging-only, or not needed on staging yet:

```bash
for f in env/*.env.example; do bash scripts/render-env.sh --list staging "$f"; done | sort -u
```

Compare with what GitHub has. This prints the **required** names still missing (empty output means none):

```bash
ENV=staging; REPO=iltiam/iltiam-deployment
comm -23 \
  <(for f in env/*.env.example; do bash scripts/render-env.sh --list "$ENV" "$f"; done | awk '$1=="secret" && $2=="must" {print $3}' | sort -u) \
  <(gh secret list --env "$ENV" -R "$REPO" --json name -q '.[].name' | sort -u)
comm -23 \
  <(for f in env/*.env.example; do bash scripts/render-env.sh --list "$ENV" "$f"; done | awk '$1=="var" && $2=="must" {print $3}' | sort -u) \
  <(gh variable list --env "$ENV" -R "$REPO" --json name -q '.[].name' | sort -u)
```

Run it again with `ENV=production`. Both commands print names only; neither can show a secret's value. `FCM_SERVICE_ACCOUNT_JSON` is not in a template: check it with `gh secret list --env <ENV> -R iltiam/iltiam-deployment`.

### 10.3 On the VM

**Once, before the first deploy:** [Runbook 5](05-compose-stack.md), section 4 creates the directories, with this command among others (as `ubuntu`):

```bash
sudo install -d -m 700 -o deploy -g deploy /srv/iltiam/env /srv/iltiam/env/staging /srv/iltiam/env/production
```

**After each deploy**, check the modes:

```bash
sudo stat -c '%a %U:%G %n' /srv/iltiam/env /srv/iltiam/env/staging /srv/iltiam/env/staging/*
```

**What you should see:**
- `700 deploy:deploy` for both directories;
- `600 deploy:deploy` for `ai.env`, `backend.env`, `infra.env` and `web.env`;
- `644 deploy:deploy` for `fcm-service-account.json` **only**, once Runbook 11 is done. This is the one exception; the reason is in `docs/secrets.md`, section 1.

**Never `cat` these files**, and never copy them off the VM.

## 11. Escrow in Bitwarden

GitHub can't show a secret again, so these also go into Bitwarden, organisation **ILTIAM**, collection **ILTIAM escrow**. Each is a **Secure Note**:

| Item name | What goes in it | When |
|---|---|---|
| `FIELD_ENCRYPTION_KEY staging` | the staging value | right after section 6 |
| `FIELD_ENCRYPTION_KEY production` | the production value | right after section 6 |
| `Android upload keystore` | `base64 -w0 upload-keystore.jks` output, plus its store password, key alias and key password | when MOB-03 creates it (owner MYF25, TO CONFIRM) |
| `age backup key` | the private `AGE-SECRET-KEY-…` line | when Runbook 6 (#8) creates it |

**Why:**
- **`FIELD_ENCRYPTION_KEY`:** losing it makes every stored authenticator secret and message unreadable.
- **The keystore:** losing it blocks app updates until Google resets the upload key.
- **The age key:** losing it makes every backup useless.

Nothing else goes into Bitwarden: a second copy of a regenerable secret is just one more place to rotate.

## 12. Rotation, revocation and leaks

Everything is in [`docs/secrets.md`](../secrets.md):
- section 2: the table of every secret with its rotation frequency;
- section 6: step-by-step rotation;
- section 7: what to do when a secret leaks.

The short version:

- **Yearly:**
  - OCI storage keys, the Firebase key, SMTP;
  - the weights tokens (they expire after a year; set a reminder two weeks before);
  - the OCI Vault keys ([Runbook 8](08-object-storage.md), section 15.1).
- **When someone leaves the team:**
  - `SECRET_KEY`, `JWT_SECRET_KEY`, `AI_SERVICE_TOKEN`, the AI `DJANGO_SECRET_KEY`;
  - the three DB passwords (change the role in Postgres **first**, section 6.3);
  - and every third-party credential they could see.
- **Never:** `FIELD_ENCRYPTION_KEY` (section 6.2 explains why).
- **A leak:** revoke or rotate first, investigate afterwards.

## 13. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| The Environment page has no **Environment secrets** section, or asks you to upgrade | The repository is still private on GitHub Free. Section 4 |
| `ERROR: openssl not found` | You are in PowerShell or cmd. Open **Git Bash** |
| `bash: $'\r': command not found` | Windows line endings: the checkout predates `.gitattributes`. Clone again, or `sed -i 's/\r$//' scripts/*.sh` |
| `check-env.sh`: `docker: command not found` | Install Docker Desktop and open a new Git Bash window |
| Deploy: `ERROR: env/backend.env.example: not set for production: …` | Those names are missing from the Environment. Add them (sections 6, 7, 9; section 10.2 lists what is missing) |
| Deploy: `must not be set for production: OTP_DEV_ECHO_NUMBERS` | A staging-only variable is in the production Environment. Delete it there |
| Deploy: `value contains a single quote or a line break: …` | Retype the variable without quotes or line breaks; for a password, ask the provider for a new one without `'` |
| Backend stops: `Delivery settings when ENVIRONMENT=production: …` | A `prod-required` delivery setting or its secret is missing (Runbooks 2, 11, 12) |
| Backend stops: `Not allowed when ENVIRONMENT=…: …` | A development flag is set in the Environment. Delete it |
| AI service stops: `AI_SERVICE_TOKEN must be set` | The secret is missing from that Environment |
| Production deploy sits on "Waiting" | It needs approval: the run page in **Actions → Review deployments → production → Approve and deploy** |
| `gh secret set …`: `HTTP 404` | Wrong environment name (`staging` / `production`, lower case), or you are not a repository admin |
| Pull fails with `denied` / `unauthorized` | The package doesn't grant this repository read access (section 8) |
| weights-init fails with 401 or 404 | `WEIGHTS_READ_TOKEN` expired, was never approved by the organisation, or lacks access to `iltiam-ai-service` (`docs/secrets.md`, section 6.6) |
| Authenticator codes or old messages stop working after a deploy | `FIELD_ENCRYPTION_KEY` was changed or unset. Put the Bitwarden value back and redeploy |

## 14. Verification checklist

Every row must match before an environment is used. Record the result on the issue as pass or fail per row, **names only, never values**.

| # | Check | How | Expected |
|---|---|---|---|
| 1 | Repository public, history clean | section 4 | **Public** label; gitleaks `no leaks found` |
| 2 | Environments exist | Settings → Environments | `staging` and `production` |
| 3 | Production gate | Environments → production | Required reviewers: ben-fatah; admin bypass off; branches `main` and tags `v*` |
| 4 | Staging branches | Environments → staging | `main` only |
| 5 | Generated secrets, both environments | `gh secret list --env <ENV> -R iltiam/iltiam-deployment` | the 8 names from section 6 |
| 6 | Nothing required missing | section 10.2, both environments | both `comm` commands print nothing |
| 7 | Escrow | Bitwarden → ILTIAM escrow | both `FIELD_ENCRYPTION_KEY` items |
| 8 | Template checks | `bash scripts/check-env.sh` | `==> all checks passed` |
| 9 | CI | the PR's checks | `env-check` green (templates and gitleaks) |
| 10 | GHCR access | section 8 | `iltiam-deployment` has **Read** on each image package |
| 11 | VM files (after the first deploy) | section 10.3 | `700` directories, `600` env files, `644` only for the FCM file |

## 15. What comes next

- **[Runbook 2](02-cloudflare-dns-tls.md)** (DEP-01): the Turnstile keys now (section 10); the SMTP values once the provider is set up (section 11).
- **[Runbook 3](03-cloudflare-tunnels.md)** (#9): `CF_TUNNEL_TOKEN`, `NUM_PROXIES`, and later `SECURE_HSTS_SECONDS`.
- **[Runbook 5](05-compose-stack.md)** (#2): `compose.yml` reads these env files, and the deploy workflow (by hand) writes them to the VM.
- **[Runbook 8](08-object-storage.md)** (DEP-02): storage keys, the storage endpoint and bucket names.
- **Runbook 9** (DEP-03): starts the deploy workflow on its own for staging, then runs the smoke test.
- **Runbook 10** (DEP-04): the same for production, behind the reviewer.
- **Runbooks 11 and 12** (DEP-13, DEP-14): Firebase and Authentica.
- **Open items found here:** `docs/secrets.md`, section 8.
