# Secrets: inventory, owners, rotation and revocation

- **Issue:** iltiam/iltiam-deployment#3 (DEP#3). **How to set them up:** [Runbook 4](runbooks/04-secrets.md).
- **Templates:** [`env/`](../env/): every variable name with a one-line comment, no values.
- **Owner of every secret:** ben-fatah. **Backup:** Omar-Nasri. The exception is the Android upload keystore (section 3).

> **This repository is public.** No secret value goes into it, into an issue, a PR, a commit message, a chat or an Actions log. Use placeholders (such as `<NAMESPACE>`) and secret **names** only.

## 1. Where secrets live

```
GitHub Environment "staging" / "production"        (Settings > Environments; write-only, can't be read back)
        │  deploy workflow .github/workflows/deploy.yml (by hand, Runbook 5; production waits for a reviewer;
        │  DEP-03 adds the automatic staging trigger, DEP-04 releases)
        ▼
scripts/render-deploy-env.sh → render-env.sh,      (names from env/*.env.example, values from the Environment)
on the runner
        │  scripts/remote-deploy.sh: SSH as deploy, files on stdin
        ▼
/srv/iltiam/env/<staging|production>/*.env         (on iltiam-1, read by docker compose through scripts/compose.sh)
        ▼
containers of the iltiam-staging / iltiam-prod Compose project
```

The workflow is the only way a value gets from GitHub to the VM: GitHub can't show a secret again, so nobody types one onto the VM. `backend.env` is written only while `env/<env>.versions` enables the backend; `web.env` joins with the web service (WEB-03).

**Bitwarden** (free organisation "ILTIAM", collection "ILTIAM escrow", members ben-fatah and Omar-Nasri) keeps a copy of what can never be regenerated: see section 5.

### Files on the VM

| Path | Mode | Owner | Read by |
|---|---|---|---|
| `/srv/iltiam/env/` and `/srv/iltiam/env/<env>/` | `700` | `deploy:deploy` | — |
| `<env>/backend.env`, `ai.env`, `web.env` | `600` | `deploy:deploy` | the `docker compose` client (`env_file:`), which hands the values to the containers |
| `<env>/infra.env` | `600` | `deploy:deploy` | the `docker compose` client (`--env-file`, interpolation only) |
| `<env>/fcm-service-account.json` | **`644`** | `deploy:deploy` | bind-mounted at `/run/secrets/fcm-service-account.json` into the backend containers |

**The one exception: `fcm-service-account.json` is `644`.** The backend container runs as uid 10001, not as `deploy`. Compose (outside Swarm) mounts a secret file as a plain bind mount: the file keeps its host owner and mode, and Compose ignores `uid`/`gid`/`mode` there. A `600` file owned by `deploy` would be unreadable inside the container, and the backend refuses to start. `644` is safe because the parent directory is `700`: no other user on the VM can reach the file, and inside the container only the backend sees it. Every other file stays `600`.

## 2. Secrets in the GitHub Environments of this repository

Each environment has **its own value** for every secret (run `scripts/bootstrap-secrets.sh` once per environment). "Staff change" means: someone who had access to these secrets, the VM or the accounts below leaves the team.

| Secret | Goes to | Where it comes from | Rotate | How to rotate | How to revoke on a leak |
|---|---|---|---|---|---|
| `SECRET_KEY` | backend.env | `bootstrap-secrets.sh` | staff change, leak | 6.1 | Rotate now |
| `JWT_SECRET_KEY` | backend.env | `bootstrap-secrets.sh` | staff change, leak | 6.1. Everyone (web and mobile) is signed out and signs in again with a code, which costs Authentica credits | Rotate now |
| `FIELD_ENCRYPTION_KEY` | backend.env | `bootstrap-secrets.sh`, **escrowed in Bitwarden** | **never** | 6.2 | Can't be revoked without losing data: see 6.2 |
| `AI_SERVICE_TOKEN` | backend.env **and** ai.env | `bootstrap-secrets.sh` | staff change, leak | 6.1, deploying backend and AI together | Rotate now (the AI service is never public, so a leak needs VM access too) |
| `DJANGO_SECRET_KEY` (AI service) | ai.env | `bootstrap-secrets.sh` | staff change, leak | 6.1 | Rotate now |
| `POSTGRES_PASSWORD` | infra.env | `bootstrap-secrets.sh` | staff change, leak | 6.3, role `postgres` | 6.3 |
| `BACKEND_DB_PASSWORD` | infra.env | `bootstrap-secrets.sh` | staff change, leak | 6.3, the backend's role | 6.3 |
| `AI_DB_PASSWORD` | infra.env | `bootstrap-secrets.sh` | staff change, leak | 6.3, the AI service's role | 6.3 |
| `STORAGE_ACCESS_KEY`, `STORAGE_SECRET_KEY` | backend.env | OCI Customer Secret Key of the environment's storage user (Runbook 8, DEP-02) | yearly, staff change | 6.4 | OCI console: delete the key (6.4 step 5) |
| `CF_TUNNEL_TOKEN` | infra.env | Cloudflare Zero Trust, the environment's tunnel `iltiam-staging` / `iltiam-prod` ([Runbook 3](runbooks/03-cloudflare-tunnels.md), section 3) | staff change, leak | **Networking → Tunnels →** the tunnel **→ Overview → Refresh token**, update the secret, redeploy (Runbook 3, section 12) | Refresh the token and redeploy at once: a refresh only blocks *new* connections, so the running connector must restart. Then check that the tunnel's only connector is ours |
| `AUTHENTICA_API_KEY` | backend.env | Authentica dashboard (Runbook 12, DEP-14) | staff change, leak | Create a new key in the dashboard (menu: Runbook 12), update the secret, redeploy, delete the old key | Delete the key in the dashboard; check the balance for misuse |
| `TURNSTILE_SECRET_KEY` | backend.env | Cloudflare dashboard → Turnstile → the environment's widget, `iltiam-staging` / `iltiam-prod` (Runbook 2, DEP-01) | staff change, leak | Turnstile → widget → **Rotate secret key** (keep the old key valid for a grace period), update the secret, redeploy | Rotate with immediate expiry |
| `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD` | backend.env | OCI Email Delivery SMTP credentials of the environment's own user, `iltiam-smtp-staging` / `iltiam-smtp-prod` (Runbook 2, section 11.5; **pending SMTP provider**) | yearly, staff change | OCI console → the user → **SMTP credentials → Generate credentials** (the old one keeps working meanwhile), update both secrets, redeploy, delete the old credential | OCI console → the user → **SMTP credentials** → delete it |
| `FCM_SERVICE_ACCOUNT_JSON` | file `fcm-service-account.json` (section 1) | Firebase → Project settings → Service accounts → Generate new private key (Runbook 11, DEP-13) | yearly, staff change | 6.5 | Google Cloud console → IAM & Admin → Service accounts → the Firebase account → **Keys** → delete the key |
| `WEIGHTS_READ_TOKEN` | infra.env (→ weights-init's `GITHUB_TOKEN`) | Fine-grained PAT, one **per environment**: resource owner `iltiam`, only `iltiam-ai-service`, **Contents: Read-only**, expiry **1 year** | yearly (it expires) | 6.6 | github.com → Settings → Developer settings → Personal access tokens → Fine-grained tokens → the token → **Delete** |
| `STAGING_TEST_PASSWORD` (staging only) | backend.env | Chosen by whoever runs `manage.py seed_staging`; must meet the password policy | staff change | Set a new one, update, run `seed_staging` again | Same |
| `DEPLOY_SSH_KEY` | the deploy workflow only (`~/.ssh/iltiam_deploy` on the runner) | `ssh-keygen -t ed25519`, **one key per environment**, no passphrase ([Runbook 5](runbooks/05-compose-stack.md), section 5.1) | staff change, leak | Runbook 5, section 5.1 with a new key, then delete the old line from `authorized_keys` | Remove its line from `/home/deploy/.ssh/authorized_keys` on the VM. A deploy key reaches Docker on the VM, which is as good as root: treat a leak as an incident (DEP-09) |
| `DEPLOY_SSH_KNOWN_HOSTS` | the deploy workflow only | the VM's host key line, checked against the VM's own fingerprint (Runbook 5, section 5.2) | when the VM is rebuilt | Runbook 5, section 5.2 | Not secret by itself; a secret only because it contains the VM's address |
| `DEPLOY_HOST` | the deploy workflow only | the VM's public IPv4 address (Runbook 1) | when the VM's address changes | Set the new address | Not a credential; a secret only so this public repository never shows the address |

Non-secret values (host names, bucket names, backends, `AUTHENTICA_SENDER_NAME`) are **Environment variables**, not secrets. The templates mark each one `var`.

**No registry token is stored.** The deploy job pulls images with its own short-lived `GITHUB_TOKEN` (`permissions: packages: read`): `docker login ghcr.io --password-stdin` on the VM, pull, `docker logout ghcr.io`, all inside the job. The token dies when the job ends. Each GHCR package must grant this repository read access once (Runbook 4, section 8).

## 3. Secrets kept outside this repository

| Secret | Lives in | Owner | Rotate | Notes |
|---|---|---|---|---|
| `google-services.json`, one per Android flavor (dev, staging, prod) | iltiam-mobile **repository secrets**, base64; names **TO CONFIRM** (MOB-02, MOB-03) | ben-fatah | not needed | Low sensitivity (the API key in it is restricted to the app), but never committed (DEP-13) |
| Android upload keystore, its store password, key alias and key password | iltiam-mobile repository secrets; names **TO CONFIRM** (MOB-03, MOB-28a). **Escrowed in Bitwarden** | **MYF25 (Mohammad), TO CONFIRM**; backup ben-fatah | never, unless lost or leaked | Lost or leaked: Play Console → the app → Setup → App signing → **Request upload key reset** (Play App Signing keeps the real signing key) |
| age backup key (private half) | **Bitwarden only** (#8 decides whether the VM's restore test holds a copy) | ben-fatah | never | Without it no backup can be restored. Only the public recipient key goes to the VM |
| OCI Vault master encryption key | OCI Vault `iltiam` (software-protected, DEP-02) | ben-fatah | **yearly** | OCI console → Vault → the key → **Rotate key**. Old versions stay for decryption, so nothing is lost |
| OCI console logins, Cloudflare, Authentica, Firebase, Play Console accounts | each provider, with MFA | ben-fatah (Play Console: Mohammad) | — | Remove a person's access on staff change. Cloudflare's second administrator is Omar-Nasri (Runbook 2); each person keeps their own 2FA recovery codes |
| Team mailbox behind `privacy@` and `security@iltiamcare.com`: its password and 2-Step Verification backup codes | Gmail, a dedicated team account with 2-Step Verification on. **Escrowed in Bitwarden** | ben-fatah (privacy contact); backup Omar-Nasri | staff change, leak | **Its address is never written in this repository**, an issue, a PR or a chat. To find it: Cloudflare → **Email Routing → Destination addresses** (both administrators see it). Patients' replies come from this address (Runbook 2, section 11.9). Leaked: change the password, sign out all sessions (**Google Account → Security → Your devices**), new backup codes, update the escrow item |

## 4. Rules

1. **Never print a secret in GitHub Actions.** This repository is public, so its logs are public:
   - no `set -x` / `bash -x` in a step that has secrets in its environment;
   - no `echo`, `cat` or `env` of a value or a rendered env file;
   - `docker compose config` only with `--quiet`; `docker login` only with `--password-stdin`;
   - gitleaks only with `--redact`;
   - GitHub masks registered secrets, but not values derived from them (base64, URLs). Mask a derived value with `echo "::add-mask::$VALUE"` before anything could print it.
2. **Never run a workflow on `pull_request_target` that checks out PR code.** In a public repository, forks' PRs would get the secrets. Plain `pull_request` workflows get none.
3. **Values reach scripts through environment variables, never arguments** (arguments show up in `ps` and in logs).
4. **Staging and production never share a value.**
5. **GitHub secrets are write-only.** Anything that can't be regenerated goes to Bitwarden too (section 5).
6. **One owner per secret** (above), who rotates it and knows how to revoke it.

## 5. Escrow (Bitwarden)

Bitwarden free organisation **"ILTIAM"**, collection **"ILTIAM escrow"**. Members: ben-fatah (owner) and Omar-Nasri. Both have two-step login on.

| Item (Secure Note) | Content |
|---|---|
| `FIELD_ENCRYPTION_KEY staging` | the staging value |
| `FIELD_ENCRYPTION_KEY production` | the production value |
| `Android upload keystore` | the keystore as base64 (`base64 -w0 upload-keystore.jks` in Git Bash; the free plan has no attachments), its store password, key alias and key password |
| `age backup key` | the private `AGE-SECRET-KEY-…` line (#8) |
| `Team mailbox (privacy@, security@)` | the Gmail login, its password and its 2-Step Verification backup codes, so the backup owner can read `privacy@` mail when the owner can't (Runbook 2, section 11.9) |

Never put anything else there that GitHub can hold: two copies means two places to rotate.

## 6. Rotation procedures

Rotate during a quiet hour, staging first. "Redeploy" means running the environment's deploy workflow ([Runbook 5](runbooks/05-compose-stack.md), section 6), which writes the env files again; Compose recreates every container whose environment changed.

### 6.1 A generated value (`SECRET_KEY`, `JWT_SECRET_KEY`, `AI_SERVICE_TOKEN`, `DJANGO_SECRET_KEY`)

1. In Git Bash, make a value and send it straight to GitHub, without showing it:
   ```bash
   openssl rand -hex 32 | gh secret set AI_SERVICE_TOKEN --env staging -R iltiam/iltiam-deployment
   ```
2. Redeploy the environment.
   - `AI_SERVICE_TOKEN`: the backend and the AI service must restart in the **same** deploy. Calls in flight in between get 401 and the backend retries them.
3. Check: the backend's `/api/ready/` answers 200 and an analysis goes through (DEP-10 smoke).

What each one breaks:
- **`SECRET_KEY`:** sessions and pending password-reset and activation links (people ask for a new one).
- **`JWT_SECRET_KEY`:** every sign-in.
- **`AI_SERVICE_TOKEN`, `DJANGO_SECRET_KEY`:** nothing visible.

Encrypted data is safe only because `FIELD_ENCRYPTION_KEY` is set. Without it, the backend derives the encryption key from `SECRET_KEY`.

### 6.2 `FIELD_ENCRYPTION_KEY`: never rotate, escrow it

The backend encrypts Super Admins' authenticator secrets and message bodies with **one** Fernet key (`apps/core/crypto.py`, no `MultiFernet`). A new key makes every stored authenticator secret and message unreadable. So:

- set it **once per environment, before the first deploy**, and copy it to Bitwarden the same minute;
- never change it, and never let it be unset (the key would silently fall back to one derived from `SECRET_KEY`);
- **if it leaks:** treat it as an incident (DEP-09). The data is only exposed together with a database dump, so protect the dumps (they are encrypted with age, #8). A clean rotation needs the backend follow-up (MultiFernet plus a re-encrypt command), which is listed in section 8.

### 6.3 Database passwords (`POSTGRES_PASSWORD`, `BACKEND_DB_PASSWORD`, `AI_DB_PASSWORD`)

Postgres reads `POSTGRES_PASSWORD` and the init scripts only when the data directory is empty, so changing the secret alone changes nothing. Change the role first, then the secret.

1. Make a new value and keep it on screen only while you need it: `openssl rand -hex 24`.
2. On the VM, as `deploy`, set it on the role. `\password` asks for it without echo and keeps it out of the shell history:
   ```bash
   bash /srv/iltiam/repo/scripts/compose.sh staging exec postgres psql -U postgres -c '\password <ROLE>'
   ```
   `<ROLE>`: `postgres` for `POSTGRES_PASSWORD`, `iltiam` for `BACKEND_DB_PASSWORD`, `iltiam_ai` for `AI_DB_PASSWORD` (`postgres/initdb/10-iltiam.sh`).
3. **Right away**, update the GitHub secret (`gh secret set BACKEND_DB_PASSWORD --env staging -R iltiam/iltiam-deployment`, paste, Enter) and redeploy. Open connections keep working; new ones fail until the redeploy.
4. Check: `/api/ready/` 200 and the AI `/ready` 200. Then run `clear`.

### 6.4 OCI object storage keys (`STORAGE_ACCESS_KEY`, `STORAGE_SECRET_KEY`)

OCI allows two Customer Secret Keys per user, so the old one keeps working until the new one is in place.

1. OCI console → **Identity & Security → Domains → Default domain → User management** → the environment's storage user → **Customer secret keys → Generate secret key**. Name it with the date.
2. Copy the **secret** (shown only once) into the GitHub secret `STORAGE_SECRET_KEY`, and the **Access key** into `STORAGE_ACCESS_KEY`.
3. Redeploy.
4. Check: open a wound photo in the web app (it is served by a presigned link).
5. Delete the old key on the same page.

### 6.5 Firebase service account (`FCM_SERVICE_ACCOUNT_JSON`)

1. Firebase console → **Project settings → Service accounts → Generate new private key**. A JSON file downloads.
2. Put it in the secret: `gh secret set FCM_SERVICE_ACCOUNT_JSON --env staging -R iltiam/iltiam-deployment < <FILE>.json`. Then delete the file from Downloads and empty the recycle bin.
3. Redeploy, and send a test push (backend issue #73).
4. Google Cloud console → **IAM & Admin → Service accounts** → the `firebase-adminsdk-…` account → **Keys** → delete the old key.

### 6.6 Weights read token (`WEIGHTS_READ_TOKEN`, one per environment)

1. github.com → your picture → **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token**.
   - Name: `iltiam-weights-staging` (or `-production`).
   - Expiration: **1 year** (custom date).
   - Resource owner: **iltiam**.
   - Repository access: **Only select repositories → iltiam-ai-service**.
   - Permissions → Repository permissions → **Contents: Read-only**. Nothing else.
2. If the organisation requires approval, an org owner approves it: **iltiam → Settings → Personal access tokens → Pending requests**.
3. `gh secret set WEIGHTS_READ_TOKEN --env staging -R iltiam/iltiam-deployment`, paste, Enter.
4. Delete the old token. Put a calendar reminder **two weeks before** the new expiry.

## 7. If a secret leaks

1. **Revoke or rotate first** (the table's last column), then investigate.
2. If it was pasted into an issue, PR or commit: deleting or editing the text is **not** enough, because it stays in history, notifications and caches. The rotation is what fixes it.
3. Check for misuse: the provider's logs or balance (Authentica, OCI audit, Cloudflare), and the backend's audit log.
4. If patient data could have been reached, follow the incident and breach process (DEP-09, the 72-hour notification).
5. Write down what happened, without the value, in the incident record.

## 8. Open items for #2 / DEP-02 / backend

Found while writing the templates (issue #3). Each one belongs to the issue named.

**For #2 (Runbook 5, compose.yml): all resolved by #2.**
1. ~~Redis databases collide.~~ **Resolved:** backend `0` (broker and results) and `2` (cache); AI `3` (broker), `4` (results), `5` (cache), set in `compose.yml`.
2. ~~Database roles.~~ **Resolved:** role and database `iltiam` for the backend, `iltiam_ai` for the AI service (`postgres/initdb/10-iltiam.sh`); neither role can connect to the other's database.
3. ~~Constants compose.yml sets.~~ **Resolved:** all of them are in `compose.yml`; `scripts/check-compose.sh` checks that each secret of `infra.env` reaches only the containers that need it.
4. ~~The FCM file.~~ **Resolved:** `compose.fcm.yml` mounts it read-only into the four backend roles, added only when the file exists.
5. ~~Replace the CI stub.~~ **Resolved:** `scripts/check-env.sh` uses `compose.yml`; `ci/env-check.compose.yml` is gone.

**For DEP-02 (Runbook 8, object storage). The backend's bucket settings are the source of truth:**

6. **Bucket names.** The backend reads `STORAGE_BUCKET_WOUND_IMAGES`, `_WOUND_MASKS`, `_REPORTS`, `_PRESCRIPTIONS` and `_PROFILE_PHOTOS`. Create `iltiam-<env>-wound-images`, `-wound-masks`, `-reports`, `-prescriptions`, `-profile-photos` (`<env>` = `staging` / `prod`, TO CONFIRM).
   - DEP-02's `-masks` becomes `-wound-masks`.
   - The backend has no `exports` bucket setting. Drop it, or add the setting in the backend first (BE-13).
   - `-backups` is #8's, not the backend's.

**For the backend (Omar-Nasri):**

7. ~~Health check vs `ALLOWED_HOSTS`.~~ **Worked around in #2, confirmed:** the image's own check gets `400` under production settings (and would get a redirect to https after that). `compose.yml` overrides the `backend-web` health check to send the first `ALLOWED_HOSTS` name as `Host` and `X-Forwarded-Proto: https`, which answers `200`. No backend change is needed; exempting the probe in the backend would let compose drop the override.
8. **`FIELD_ENCRYPTION_KEY` rotation:** follow-up issue (MultiFernet plus a re-encrypt command), section 6.2.
9. **`STAGING_TEST_PASSWORD`:** document the password policy, so the value can be generated.

**Still TO CONFIRM:**

10. **Web runtime config names** (`API_BASE_URL`, `TURNSTILE_SITE_KEY`): WEB-03.
11. **iltiam-mobile secret names** (google-services per flavor, upload keystore): MOB-02, MOB-03, MOB-28a. Keystore owner MYF25.
12. **SMTP provider:** decided, OCI Email Delivery (ADR-0004 Decision 6), pending confirmation that it is offered in Riyadh. Set up with Runbook 2, section 11; Resend is the fallback.
13. **Values and menus:**
    - `ALLOW_SYNC=0` and `AI_MASK_UPLOAD_ENABLED=True`;
    - the activation link path (WEB-05);
    - the SSH deploy key's secret name (DEP-03);
    - Authentica's exact menu names for key rotation (Runbook 12).

    Settled by Runbook 3 (#9): `NUM_PROXIES=1` and the tunnel token rotation menu (section 2). Settled by #2: `FORWARDED_ALLOW_IPS=*` in `compose.yml` (Runbook 3, section 8), and the SSH deploy key's secret names (`DEPLOY_SSH_KEY`, `DEPLOY_SSH_KNOWN_HOSTS`, `DEPLOY_HOST`, section 2).
14. ~~AI torch threads.~~ **Resolved:** iltiam-ai-service#158 added `ILTIAM_TORCH_THREADS`; `compose.yml` sets it and `OMP_NUM_THREADS` to `2` as constants (not in `ai.env`). It takes effect with an AI image built from that change (`sha-0d1861e` or later; `env/<env>.versions`).
