# Incident response plan

What the team does when something goes wrong with security or patient data: who leads, how serious it is, what to
keep as evidence, and when the [72-hour breach runbook](breach-runbook.md) starts. Issue #21 (DEP-09); SRS FR-P-7.1,
NFR-SEC, NFR-MAI-02. The threats it answers are in the [threat model](threat-model.md).

> **This repository is public.** Never write incident details, patient names, phone numbers, IP addresses of
> suspects or any secret in a GitHub issue, PR or commit here. The incident record lives in the team's private
> folder (section 6). A public issue may only say "security work, see the incident record INC-YYYY-NNN".

## 1. Roles

| Role | Who | Does |
|---|---|---|
| **Incident lead** | Thabit (`ben-fatah`) | Declares the incident and its severity, decides containment, decides whether it is a notifiable breach, signs the record |
| Backup lead | Omar (`Omar-Nasri`) | Takes over when the lead cannot be reached in 1 hour; has the Cloudflare and mailbox access too ([secrets](../secrets.md), section 5) |
| Technical responders | Ahmed (`aalbabtain`), Mansour (`Mn9p`), the developer who owns the affected repository | Collect evidence, contain, fix, test the fix |
| Scribe | Whoever the lead names, never the lead | Writes the timeline as it happens (UTC and Riyadh time) |
| Communication | The incident lead | Clinics, patients (through the backend's breach notice), SDAIA when required |

One person can hold two roles in a small incident, except lead and scribe.

## 2. How an incident is reported

- **Inside the team:** the team's private group chat, then a phone call to the incident lead for SEV-1 and SEV-2.
- **From outside** (a clinic, a patient, a researcher): `security@iltiamcare.com` or `privacy@iltiamcare.com`. Both
  arrive in the team mailbox ([Runbook 2](../runbooks/02-cloudflare-dns-tls.md), section 11), read by the lead and
  the backup. Answer within one working day.
- **From the system:** monitoring alerts once #10 is live; until then, a failing `/api/ready/`, the deploy run, an
  OCI or Cloudflare email, a provider's alert (Authentica balance, Firebase).

Whoever notices writes down **when** they noticed. That time can start the 72-hour clock (section 4).

## 3. Severity

| Level | Examples | First response | Lead involved |
|---|---|---|---|
| **SEV-1** | Patient data read or changed by someone who should not have it; a production secret in the wrong hands; the VM compromised | Immediately, any hour | Always, by phone |
| **SEV-2** | A real vulnerability that exposes data but no sign it was used; production down more than 1 hour; a staff account taken over | Within 2 hours | Always |
| **SEV-3** | A vulnerability with no data exposure; a staging-only secret leaked; repeated attack traffic blocked by Cloudflare | Within 1 working day | Informed |
| **SEV-4** | A scan finding, a policy gap, a suspicious email with no click | Next planning | Through the normal issue |

When unsure, take the higher level. A SEV-1 or SEV-2 that touches personal data goes to section 4 as soon as it is
declared.

## 4. Is it a personal data breach?

A **personal data breach** is any access, disclosure, change, loss or destruction of personal data that was not
authorised, whether by an attacker or by mistake (a report sent to the wrong clinic, a public bucket, a lost laptop
with an export).

1. The lead decides within the first hours, with what is known, and writes the decision and the reason in the
   record. "We don't know yet" counts as **yes** for planning: start the runbook clock.
2. **The 72-hour clock starts at discovery**, the moment the team became aware (section 2), not when the
   investigation ends. The backend records it as `discovered_at` on the incident and computes the deadline.
3. If yes: follow the [breach runbook](breach-runbook.md): patients within 72 hours (FR-P-7.1, built into the backend)
   and SDAIA within 72 hours when the law requires it.
4. If no: keep the record with the reason; it is still evidence if the facts change.

## 5. Phases

| Phase | What to do | Done when |
|---|---|---|
| 1. Declare | Lead opens the record (`INC-YYYY-NNN`), names the roles, sets severity, notes discovery time | Record exists |
| 2. Preserve evidence | Section 7, **before** restarting or redeploying anything: restarts and rotations erase logs | Evidence copied to the private folder |
| 3. Contain | Section 8: stop the leak first (revoke, disable, take offline), then investigate | No further access possible |
| 4. Assess | What data, which patients, which clinics, since when, by whom. Use the audit log and storage access records | The scope is written down, with how sure we are |
| 5. Notify | Breach runbook, when section 4 says yes | Notices sent and recorded inside 72 h |
| 6. Eradicate and recover | Fix the cause (code fix through a normal PR with `scripts/ci-local.sh --full`), rotate what was exposed, deploy, verify with the read-only smoke | Service back, cause removed |
| 7. Review | Within 2 weeks: blameless review, findings filed as issues (without sensitive details), this plan updated | Review signed by the lead |

## 6. The incident record

One document per incident in the team's private folder (never this repository), named `INC-YYYY-NNN`. It holds:

- Reference, severity, lead, scribe, discovery time (Riyadh and UTC).
- Timeline: every action with time and who did it.
- Evidence list (section 7): what, where it is kept, its SHA-256.
- Decision on "personal data breach" (section 4) with the reason.
- Affected data categories, number of patients, clinics.
- Notifications sent: patients (the backend's notice export), clinics, SDAIA (reference number).
- Root cause, fixes (PR links), follow-up issues.
- Sign-off by the lead. Keep the record for as long as the breach records in the backend (retention: kept).

## 7. Evidence: where it is and how to keep it

| Source | How to read it | Kept for | Keep a copy by |
|---|---|---|---|
| Backend audit log (every sign-in, read of records, write, export, breach notice) | Super Admin: `GET /api/audit-logs/` with filters, or `GET /api/audit-logs/export/` (CSV) | Forever (append-only) | Exporting the incident's time window as CSV |
| Container logs (requests with `request_id`, errors) | On the VM: `scripts/compose.sh <env> logs --since <time> <service>` | **About 50 MB per container** (5 × 10 MB, `compose.yml`): a busy day can push older lines out | Saving them to a file at once, on the VM, then copying to the private folder |
| Central logs (Loki) | Grafana → **Explore → Loki**, once #10 is live ([Runbook 7](../runbooks/07-monitoring.md), section 17.2) | **7 days**, then deleted | Exporting the query result (**Inspect → Data → Download**) at once |
| Cloudflare: requests, firewall events, Access logins | Cloudflare dashboard → Security → Events; Zero Trust → Logs | Free plan: a short window (hours to days) | Screenshots or CSV export straight away |
| OCI: console logins, API calls, bucket access | OCI Console → Observability → Audit | 365 days | Export of the time window |
| GitHub: deploy runs, approvals, secret changes | Actions run logs; organisation audit log | Per GitHub plan | Saving the run log |
| Providers: SMS sent, push sent | Authentica dashboard; Firebase console | Provider's retention | Screenshots |
| Database state | A `pg_dump` taken at the time (`scripts/pre-deploy-backup.sh` pattern), kept in Riyadh | Until the review ends | The dump file's SHA-256 in the record |

Never copy patient data out of the Kingdom for an investigation. Work on the VM or a Riyadh backup
([restore location](../privacy/restore-location.md)).

## 8. Containment playbooks

| Situation | First actions |
|---|---|
| A secret leaked | [Secrets, section 7](../secrets.md): revoke or rotate first (section 6 per secret), then look for misuse. `FIELD_ENCRYPTION_KEY` is never rotated: if it leaked, treat every encrypted field as exposed and escalate to SEV-1 |
| A user account taken over | Shut the attacker out: a Super Admin account is deactivated by a Full Super Admin (ends its sessions); a doctor is deactivated by the clinic admin, who then reassigns the patients; a patient's password is reset (ends every session and revokes remembered devices). Then read that account's audit trail |
| A staff laptop or phone lost | Revoke its GitHub, Cloudflare and OCI sessions and SSH key; rotate any secret it held; if it had an export or a backup, treat as a breach |
| Data exposed by a bug (wrong scope, public link) | Turn off the feature (revert PR and deploy) or take the API offline (below); collect the audit trail of the affected endpoint |
| The VM or a container compromised | Take the environment off the internet: stop its tunnel (`scripts/compose.sh <env> stop cloudflared`, Runbook 5). Then snapshot the boot and block volumes in OCI before changing anything |
| Mass attack traffic | Cloudflare "Under Attack" mode or a WAF rule; backend throttles already apply |
| A provider breached (Authentica, Google, Oracle, Cloudflare) | Read their notice; rotate our key with them; assess what of ours they held (ROPA, [processors](../privacy/ropa.md)) |

Taking production offline is the lead's call. The staging environment used for the supervisor demo (2026-12-01) is
contained the same way.

## 9. Exercises

Run a tabletop at least once a year and after any SEV-1. Records:

- [2026-11-21: breach notification rehearsal](tabletop-2026-11-21.md)
