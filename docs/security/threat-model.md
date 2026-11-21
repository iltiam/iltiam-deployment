# Threat model (STRIDE)

The deployed system as [the architecture](../architecture.md) describes it, checked element by element with STRIDE:
**S**poofing, **T**ampering, **R**epudiation, **I**nformation disclosure, **D**enial of service, **E**levation of
privilege. Each threat names the mitigation that exists today (with the issue or file that built it) or the open issue
that will. Issue #21 (DEP-09); SRS NFR-SEC, FR-P-7.1. Last reviewed 2026-11-21 by Thabit.

What happens when a threat comes true: [incident response](incident-response.md) and the
[72-hour breach runbook](breach-runbook.md).

## 1. What we protect

| Asset | Where | Why it matters |
|---|---|---|
| Wound photos, masks, measurements, notes, messages, prescriptions | Postgres `iltiam`, OCI Object Storage (private buckets) | Health data: PDPL sensitive data; a leak is a notifiable breach |
| Identities: names, phone numbers, emails, national IDs where entered | Postgres `iltiam` | Personal data; phone numbers are also the sign-in name |
| Credentials: password hashes, sign-in codes (hashed), JWTs, authenticator secrets (encrypted) | Postgres, Redis (session cache) | Account takeover |
| Deployment secrets: `SECRET_KEY`, `JWT_SECRET_KEY`, `FIELD_ENCRYPTION_KEY`, DB passwords, storage keys, Authentica key, FCM file, tunnel tokens | GitHub Environments, `/srv/iltiam/env/<env>/` on the VM, Bitwarden escrow ([secrets](../secrets.md)) | Each one opens a whole layer |
| The audit log | Postgres, append-only (a trigger refuses UPDATE and DELETE) | Evidence for incidents and for patients' rights |
| Availability of the analysis | AI service, queue | Clinicians rely on results; staging and production share one VM |

## 2. Trust boundaries

1. **Internet → Cloudflare edge.** Every request; TLS ends here (Cloudflare sees traffic in clear, legal item L4).
2. **Cloudflare → VM** through the tunnel only. No port listens on the VM's public address; only `web` and
   `backend-web` are on the `edge` network ([Runbook 3](../runbooks/03-cloudflare-tunnels.md)).
3. **Backend → AI service** on the `internal` network (no route out), with a shared service token.
4. **Containers → the internet** through `egress` only, for those that must (storage, Authentica, FCM, SMTP, weights).
5. **Team → VM and accounts:** SSH as `ubuntu`, OCI and Cloudflare consoles, GitHub (deploy workflow, Environments).

## 3. STRIDE per element

Status: **M** mitigated (built and tested), **P** partly, **O** open (issue named).

### 3.1 Android app and browser (clients)

| | Threat | Mitigation | Status |
|---|---|---|---|
| S | Someone signs in as a patient with a stolen password | Two-step sign-in (password + 6-digit code by SMS), lockout 10 min after 5 failures, Turnstile CAPTCHA after 3 (iltiam-backend #16, #17, #28) | M |
| S | Phishing SMS asking for the code | Code texts and breach notices say "we never ask for your code" (backend `notifications/breach.py`) | P |
| T | A modified app calls the API with forged fields | Server-side validation and per-object scoping (`for_user`, `get_scoped_object_or_404`), RBAC matrix test (backend `tests/test_rbac_matrix.py`) | M |
| I | Health data on the lock screen | Push and SMS carry generic text only (iltiam-backend#128) | M |
| I | Data on a lost phone | Encrypted local database (sqlcipher), 15-minute server session, remembered devices revoked on password change (mobile #22, backend #17) | P |
| I | Script injection in the web portal steals tokens | Strict CSP written at container start, `script-src 'self'` (iltiam-web#25), no inline scripts | M |
| E | A patient reaches doctor or admin endpoints | `permission_classes` on every view, RBAC matrix test; admins refused in the app (`WEB_PORTAL_ONLY`, backend #106) | M |

### 3.2 Cloudflare edge and tunnel

| | Threat | Mitigation | Status |
|---|---|---|---|
| S | DNS or domain hijack | Cloudflare account with 2FA (Runbook 2, row 2) | P: row 2 2FA for both admins still to confirm |
| T | Downgrade to HTTP | Always HTTPS, HSTS (`SECURE_HSTS_SECONDS`, Runbook 2 section 12) | M on staging, production in #36 |
| I | Cloudflare decrypts traffic outside the Kingdom | Recorded as legal item L4; Data Localization Suite is paid ([ADR-0004](../adr/0004-hosting.md), Decision 4) | O: #23 (L4) |
| D | Flood of requests | Cloudflare's free DDoS protection and rules, per-IP and per-user throttles in the backend (backend #34) | P: load limits measured in #22 |
| E | The Django admin reached from the internet | `/admin/` behind Cloudflare Access (Runbook 3, row 16) | M on staging |

### 3.3 `web` (nginx + SPA)

| | Threat | Mitigation | Status |
|---|---|---|---|
| T | A malicious `API_BASE_URL` or `IMAGE_ORIGINS` value injects script or a header | The entrypoint accepts URL characters only and stops the container otherwise (iltiam-web `docker/40-iltiam-runtime.sh`) | M |
| I | Directory listing, source maps, version headers | nginx serves `dist` only, as user 101, read-only root filesystem | M |
| E | Container breakout | Non-root, `cap_drop: [ALL]`, `no-new-privileges`, read-only, 64 MB limit (`compose.yml`) | M |

### 3.4 `backend-web`, `backend-worker`, `backend-beat`

| | Threat | Mitigation | Status |
|---|---|---|---|
| S | Forged or replayed JWT | Signed with `JWT_SECRET_KEY`; every token carries a session id checked on each request; 15-minute idle timeout (NFR-SEC-02) | M |
| S | Forged request from the AI service | The backend calls the AI service; the AI service never calls the backend | M |
| T | Changing an AI result or a signed note | AI fields never rewritten; reviews append-only; signed notes and prescriptions immutable in the model | M |
| R | A user denies an action | Global append-only audit log (`AuditLog`, PostgreSQL trigger), every write audited (`AuditWriteMiddleware`) | M |
| I | One doctor reads another clinic's patients | Scoped querysets only, never filters in views; RBAC matrix test | M |
| I | Presigned file links leak | At most 15 minutes, private buckets, downloads audited (backend `apps/storage`) | M |
| I | Secrets or codes in logs | Codes never logged outside dev echo; logs print names, not values; this repository's CI prints names only | M |
| I | Photo metadata reveals a patient's location | EXIF/GPS stripped at upload (backend #69) | M |
| D | Expensive endpoints exhausted | Throttles per scope, upload size limit 10 MB, Celery queues | P: #22 measures |
| E | A read-only Super Admin writes | `IsSuperAdmin` refuses writes for READ_ONLY (backend #29) | M |
| E | Sensitive action with a stolen session | Step-up code for exports, threshold changes and similar (backend #71) | M |
| E | A vulnerable dependency | `pip-audit --strict` in the backend's CI (backend #87) | P: images, web, AI and mobile in #18 |

### 3.5 AI service (`ai-api`, `ai-worker`, `ai-beat`)

| | Threat | Mitigation | Status |
|---|---|---|---|
| S | Anyone calling the AI API | Not routed by the tunnel, `internal` network only, service token required | M |
| T | Mask uploaded to an attacker's URL | `MASK_UPLOAD_ALLOWED_HOSTS` allowlist, HTTPS only | M |
| T | Tampered model weights | Weights downloaded by SHA-256 from the release registry (`weights-init`); checksums recorded with each result | M |
| I | Jobs keep photos forever | Jobs, images and masks deleted after `AI_JOB_TTL_HOURS` (24 h) by `ai-beat` | M |
| D | A malformed image hangs a worker | Soft and hard time limits (30 s / 40 s), memory limits | M |

### 3.6 Postgres and Redis

| | Threat | Mitigation | Status |
|---|---|---|---|
| S | Another container uses the backend's database | Separate roles and databases (`iltiam`, `iltiam_ai`), `REVOKE ALL ... FROM PUBLIC` (`postgres/initdb`) | M |
| T | Audit rows edited | PostgreSQL trigger refuses UPDATE and DELETE on the audit table | M |
| I | Data read from a stolen disk | OCI block volumes encrypted at rest by Oracle; message bodies and authenticator secrets field-encrypted (`FIELD_ENCRYPTION_KEY`) | P: clinical rows are not field-encrypted |
| D | Redis full drops jobs | `noeviction`, append-only file, 128 MB limit (`compose.yml`) | M |
| D | Lost database | `pg_dump` before every backend deploy (`scripts/pre-deploy-backup.sh`); restore stays in Riyadh ([restore location](../privacy/restore-location.md)) | P: scheduled backups and a restore test are go-live items (#23) |

### 3.7 Object storage (OCI)

| | Threat | Mitigation | Status |
|---|---|---|---|
| S | Leaked storage key | One user per environment, policy on its five buckets only, no delete permission ([Runbook 8](../runbooks/08-object-storage.md)) | M |
| I | Public bucket | Buckets private, anonymous access refused, checked by `manage.py check_storage` | M |
| T | Files overwritten or deleted | The app never deletes; versioning on the buckets | M |

### 3.8 Deployment pipeline and the VM

| | Threat | Mitigation | Status |
|---|---|---|---|
| S | Someone deploys their own image | Deploys only through the `deploy` workflow, started by hand, held for approval, with the Environment's secrets ([AGENTS.md](https://github.com/iltiam/iltiam-deployment/blob/main/AGENTS.md)); images pinned by tag in a reviewed PR | M |
| T | A secret committed to this public repository | gitleaks over the full history in `scripts/ci-local.sh`, `.gitignore` for key files | M |
| T | A vulnerable or tampered base image | Pinned tags; image scanning | O: #18 |
| R | Who changed production? | Every change is a PR; the deploy run log names the approver | M |
| I | SSH key or console account stolen | SSH keys only, OCI and Cloudflare accounts with 2FA, Bitwarden escrow ([secrets](../secrets.md)) | P |
| D | Staging load starves production on the shared VM | Memory limits per container, split triggers | O: #19 |
| E | Root on the VM | Containers non-root with no capabilities; host patched by unattended upgrades ([Runbook 1](../runbooks/01-oci-account-and-vm.md)) | P |

### 3.9 Third parties (Authentica, Firebase, OCI Email, Google mailbox)

| | Threat | Mitigation | Status |
|---|---|---|---|
| I | A provider stores our messages | Messages carry codes or generic text, never health data (#128); processor contracts are legal item L3 | P: #23 (L3) |
| D | SMS provider down | Codes fall back SMS → WhatsApp → email; FR-SA-9 manual recovery (backend #74, #79) | P: WhatsApp in #61 |

## 4. Data flows that cross a boundary

| Flow | Boundary | Protection |
|---|---|---|
| App or browser → API (photos, records) | 1, 2 | TLS to Cloudflare, tunnel to the VM, JWT + session |
| API → presigned link → storage | 1 | Signed, 15 minutes, one object |
| Worker → AI service (photo bytes, prior measurements) | 3 | Internal network, service token; AI keeps it 24 h |
| AI worker → storage (mask upload) | 4 | Presigned PUT on allowlisted host |
| Worker → Authentica, FCM, SMTP | 4 | API keys from the Environment; no health data in the text |
| Team → deploy workflow → VM | 5 | GitHub 2FA, approval, SSH key held by GitHub Environment only |

## 5. Open items (all tracked)

| Item | Issue |
|---|---|
| Image scanning, dependency audits for web, AI and mobile, secret scanning in every repository, DAST | #18 |
| Monitoring, alerts and central logs (Loki): today evidence is `docker logs` capped at 50 MB per container | #10 |
| Load limits on the shared VM, split triggers | #22, #19 |
| Scheduled backups and a restore test before go-live; legal items L1 to L4 | #23 |
| Super Admin screens for breaches and deletion requests (today the API procedure in the runbook) | iltiam/iltiam-web#69 |
| A recorded breach incident cannot be corrected before notifying (tabletop finding F2) | see the [tabletop record](tabletop-2026-11-21.md) |
