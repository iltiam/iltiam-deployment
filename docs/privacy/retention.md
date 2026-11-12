# Retention schedule

- **Issue:** #6, acceptance criterion 1: **every row names a job or a documented manual process.**
- **Base:** iltiam-backend `docs/retention.md` (backend issue #86, PR #108), adopted here on 2026-11-09. Rows 1 to 12 are the backend's; rows 13 to 24 are added here.
- **Periods marked TO CONFIRM** wait for the review ([register](index.md#to-confirm-register)).

## How the backend job runs

- **`run_retention`:** the rule `retention` in the backend's reminder schedule (Celery beat, every 15 minutes) runs the rules once every 24 hours. By hand: `python manage.py run_retention --dry-run` (count only) or `--enforce`.
- **Dry run until signed off:** with `RETENTION_ENFORCE` false, each run only counts what is past its period. **Staging keeps it off until after the demo** (decision of 2026-11-09). Production turns it on once these documents are approved (#36).
- **Recorded:** each run writes one `RETENTION_RUN` audit entry with counts only, and the age of the oldest audit entry. Super Admins see it at `GET /api/retention/`.
- **Periods:** `RETENTION_DAYS` in the backend's `config/settings/base.py`.
- **On the VM** (after `ssh iltiam`): `cd /tmp && sudo -u deploy /srv/iltiam/repo/scripts/compose.sh staging exec -T backend-web python manage.py run_retention --dry-run`.

## The schedule

| # | Data | Kept for | Enforced by | Source |
|---|---|---|---|---|
| 1 | Clinical record: visits, wound photos and masks, analyses, reviews, SOAP notes, care plans, alerts, appointments | permanent (**TO CONFIRM, TC-9**) | **No deletion, by design.** A patient's approved deletion request **anonymises** them: Super Admin approval, `POST /api/data-requests/{id}/approve/` (backend issue #35) | SRS FR-P-7.1 |
| 2 | Prescriptions | permanent, immutable (**TO CONFIRM, TC-9**) | No deletion, by design; anonymised with the patient (row 1) | SRS FR-D-9 |
| 3 | Messages | 12 months, then archived, never deleted (**TO CONFIRM, TC-25**) | job `archive_old_messages` (backend reminder rule, `MESSAGE_RETENTION_DAYS` = 365) | SRS FR-D-13 |
| 4 | Audit log, sign-in records (`AuditLog`, `LoginAudit`) | at least 2 years; no end set (**TO CONFIRM, TC-10**) | Kept, append-only. `run_retention` reports the oldest entry's age each day. **Manual:** a yearly review, with the key rotation (Runbook 8, section 15), decides whether to remove entries older than the confirmed maximum | SRS FR-SA-10 |
| 5 | One-time codes | 30 days after the code expired | `run_retention`, rule `otp_codes` | backend |
| 6 | Sessions | 90 days after the end or the last activity; a session a prescription was signed in is kept | `run_retention`, rule `sessions` | backend, FR-D-9 |
| 7 | Trusted devices | 30 days after expiry or revocation, once no session points at them | `run_retention`, rule `trusted_devices` | backend, FR-P-1.1 |
| 8 | Account invitations | 90 days after use, or after the link expired | `run_retention`, rule `invitations` | backend |
| 9 | Push tokens | 30 days after revocation (signed out, or FCM said the token is dead) | `run_retention`, rule `push_devices` | backend |
| 10 | Notification delivery logs | 12 months | `run_retention`, rule `notification_deliveries` | backend |
| 11 | Upload idempotency keys | 24 hours | `run_retention`, rule `idempotency_records` (`IDEMPOTENCY_TTL_HOURS`) | backend |
| 12 | In-app notifications (the inbox) | not scheduled by the backend; proposed: 12 months, like row 10 (**TO CONFIRM, TC-27**) | **Manual until a backend rule exists:** none deleted by age. A patient's notifications, and any that name them, are deleted when they are anonymised (row 1). Backend follow-up: add a `notifications` rule to `run_retention` | backend: "not yet scheduled" |
| 13 | Accounts (identity, row 1 of the [ROPA](ropa.md)) | while the account exists. Patients: anonymised on an approved deletion request. **Doctors and other staff: never deleted, only deactivated**, so records keep their author (**TO CONFIRM, TC-17**) | Patients: deletion request approval (row 1). Staff: deactivation by a Clinic Admin or Super Admin, `POST /api/clinic/doctors/{id}/status/` | decision 2026-11-13 |
| 14 | Data export files (`exports/` in `iltiam-<SHORT>-reports`) | 7 days | The backend refuses a download after `EXPORT_TTL_DAYS` (7). **The file itself:** no lifecycle rule exists yet. **Manual until it does:** on the 1st of each month, an administrator deletes `exports/` objects older than 7 days in the OCI console (the backend's key can't delete). Follow-up: a lifecycle rule `delete-exports` (prefix `exports/`, 7 days) in Runbook 8, section 8 | backend issue #78 |
| 15 | AI service jobs (photo copy, result, mask) | 24 hours (at most 24 h 15 min) | AI service task `ai.cleanup_expired_jobs`, every 15 minutes (`AI_JOB_TTL_HOURS` = 24) | iltiam-ai-service README |
| 16 | Old object versions and unfinished uploads (the 10 versioned buckets) | previous versions 30 days; unfinished multipart uploads 1 day | OCI lifecycle rules `delete-old-versions` and `abort-unfinished-uploads` ([Runbook 8](../runbooks/08-object-storage.md), section 8) | Runbook 8 |
| 17 | Container logs on the VM | at most 5 files of 10 MB per container, oldest overwritten | Docker's `json-file` log rotation (`compose.yml`, `x-logging`) | `compose.yml` |
| 18 | Database dumps | **Pre-deploy dumps** (staging backend database, before each automatic backend deploy): the newest 5, on the VM in `/srv/iltiam/backups/pre-deploy/`. **Scheduled backups** to `iltiam-<SHORT>-backups`: set by Runbook 6 | Pre-deploy: `scripts/pre-deploy-backup.sh` keeps the newest 5 (`KEEP=5`) and deletes the older ones at each run ([Runbook 9](../runbooks/09-cd-staging.md)). Scheduled: the backup job of #8 (Runbook 6), **not built yet**; it must add a lifecycle rule on `-backups`. Both follow [restore-location.md](restore-location.md) | #16, #8 |
| 19 | Mail to `privacy@` and `security@` | proposed: 12 months after the request or report is closed (**TO CONFIRM, TC-28**) | **Manual:** each month the mailbox owner deletes threads closed more than 12 months ago | proposal |
| 20 | AI feedback dataset exports | **TO CONFIRM (TC-21)** | **Manual:** the Super Admin who ran `export_feedback_dataset` deletes the folder when the retraining it was made for is done, and records the date on the retraining issue | backend issue #90 |
| 21 | Authentica's message logs | Authentica's own period (**TO CONFIRM, TC-15**) | **Manual:** ask Authentica support for the period once, before production (#36); record it here | Runbook 12 |
| 22 | Cloudflare's request and email logs | Cloudflare's own period (**TO CONFIRM, TC-15**) | **Manual:** none to run: we export no Cloudflare logs. Confirm the period from Cloudflare's documentation before production | Runbooks 2, 3 |
| 23 | Firebase (FCM) delivery data | Google's own period (**TO CONFIRM, TC-15**) | **Manual:** none to run; a revoked token is deleted on our side (row 9). Confirm Google's period before production | Runbook 11 |
| 24 | OCI Email Delivery logs | Oracle's own period (**TO CONFIRM, TC-15**) | **Manual:** none to run; confirm the period before production | Runbook 2 |

Every deleted row is operational. The events those rows took part in (sign-ins, sessions ending, devices revoked, invitations used) stay in the audit log (row 4).

## Checking it

1. Leave `RETENTION_ENFORCE` unset and run `run_retention --dry-run` (command above).
2. Compare each count with this table for the data on staging.
3. When they match and these documents are approved: add `RETENTION_ENFORCE` to `env/backend.env.example` (a `var`; the deploy passes only listed names) and to `scripts/check-env.sh`, set the variable `RETENTION_ENFORCE=true` in the GitHub Environment, and deploy (production in #36).

## Changing a period

Change it here and in the backend's `RETENTION_DAYS` in the same review, update the [ROPA](ropa.md), and note the date in the [decisions](index.md#decisions).
