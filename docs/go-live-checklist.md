# Go-live checklist

The last gate before real patients use ILTIAM in production (issue #23, DEP-11). It uses Runbook 10 and
`scripts/smoke-readonly.sh` (#19), the load-test procedure (#22) and `scripts/check-env-differ.sh` (this issue). Every box is ticked, with its
evidence, before the launch; the launch itself is done by hand (section 6). **Thabit decides and signs.**

Ticking these boxes does not make ILTIAM legally approved or clinically validated: it means the items the team
committed to are done. Copy sections 1 to 5 into a comment on #23 and tick them there with a link or a date for each.

## 1. Legal and privacy (from #6, `docs/privacy/`)

- [ ] L1 Controller per clinic decided, and what each clinic signs ([privacy overview](privacy/index.md#legal-review-before-public-launch)).
- [ ] L2 SDAIA national register and data protection officer: done for whoever must register.
- [ ] L3 Processor terms in place: Oracle, Cloudflare, Authentica, Google.
- [ ] L4 Transfers outside the Kingdom accepted or removed (Cloudflare edge and Email Routing, Google FCM and mailbox).
- [ ] The breach runbook's interim rule replaced by the L1/L2 answer ([breach runbook](security/breach-runbook.md), section 2).

## 2. Product blockers (other repositories)

- [ ] iltiam/iltiam-backend#129: deletion anonymises as the privacy notice says.
- [ ] iltiam/iltiam-backend#128: no health data in push or SMS text.
- [ ] iltiam/iltiam-backend#130: the consent text version is stored.
- [ ] iltiam/iltiam-web#70: public `/privacy`, `/terms` and `/delete-account` with a working request without the app.
- [ ] iltiam/iltiam-web#29 and iltiam/iltiam-mobile#44: the apps show the texts and record acceptance.
- [ ] iltiam/iltiam-mobile#77 (bundled fonts) and iltiam/iltiam-mobile#76 (no unused media permissions).
- [ ] iltiam/iltiam-web#69: Super Admin screens for deletion requests and breaches, or the API procedure in the breach
      runbook accepted as the way.
- [ ] iltiam/iltiam-mobile#51 and iltiam/iltiam-web#54 (blockers named on #23).
- [ ] Play production access approved (#68); the store listing matches what the app does.

## 3. Production platform

| | Check | How | Evidence |
|---|---|---|---|
| [ ] | Production deployed and healthy (#36) | Runbook 5, section 8; `iltiam production ps` | All services healthy |
| [ ] | Released through Runbook 10 as v1.0.0 | [Runbook 10](runbooks/10-production-release.md), section 4 | The `prod-v1.0.0` tag, the release PR |
| [ ] | Read-only smoke passes | `scripts/smoke-readonly.sh production` | `Smoke: all checks passed.` |
| [ ] | Backups nightly, **restore tested** (#8) | [Runbook 6](runbooks/06-backups.md), section 11 for production; then two Friday restore tests in a row (section 14, row 8): `scripts/restore-test.sh production` restores last night's backup into a throwaway database and counts rows | The two dates and row counts. **No real patient data before this box** |
| [ ] | Monitoring and alerts tested (#10) | `MONITORED_ENVIRONMENTS` includes production ([Runbook 7](runbooks/07-monitoring.md), section 17.5); stop production's AI worker for 5 minutes on purpose: the `TargetDown` email and Discord message arrive | Time of the alert email |
| [ ] | External uptime probe and status page live | The free pinger on `app.` and `api.` health; the status page URL | URL |
| [ ] | Production secrets differ from staging | On the VM as `deploy`: `scripts/check-env-differ.sh` | `No secret is shared between staging and production.` |
| [ ] | Development switches off | Production settings refuse `DEBUG`, `OTP_DEV_ECHO`, `OTP_DEV_ECHO_NUMBERS`, `DEMO_SEED_ENABLED`, `LOAD_TEST_SEED_ENABLED` at start, so a running backend proves it; the smoke shows `/api/docs/` 404 | The smoke output |
| [ ] | Real delivery | Production SMS (Authentica with its sender name), FCM push, SMTP: a test sign-in code, a test push (`POST /api/notifications/devices/test/`), an invitation email to yourself | Each received |
| [ ] | `RETENTION_ENFORCE` on (#66) and the export clean-up rule (#65) | `GET /api/retention/` as Super Admin | Enforcing: yes |
| [ ] | HSTS on `app.` and `api.`; `/admin/` behind Cloudflare Access | The smoke; Runbook 3, row 16 | The smoke output |
| [ ] | Security scan clean | `scripts/security-scan.sh images deps secrets` on the release's tags | No fixable CRITICAL, no secret ([scanning](security/scanning.md)) |
| [ ] | Load: production behaves on the VM | The small read-only run of [the perf README](https://github.com/iltiam/iltiam-deployment/blob/main/docs/perf/README.md), section 5, against production **before** any real user, or against staging with production running | p95 per page, VM memory |
| [ ] | Memory headroom on the VM | `free -h` and Runbook 5, section 9.5, both projects idle | All containers under 10 GB; `MemAvailable` above 15 % during an analysis |
| [ ] | **$10 budget alert active, billing at $0** | OCI → Billing & Cost Management → Budgets: `iltiam-monthly-budget` with its alert rules (Runbook 1, section 4); Cost analysis for this month | Screenshot: $0.00 |

## 4. Accounts and data

- [ ] The first Full Super Admin bootstrapped in production, once:
      `iltiam production exec backend-web python manage.py bootstrap_superadmin --phone <+9665…> --email <…> --name <…>`,
      then the invitation completed (password, authenticator app, policies). iltiam-backend#63.
- [ ] A second Full Super Admin invited by the first (nobody is the only key holder).
- [ ] No demo, load-test or staging accounts in production (`seed_demo`, `seed_load_test` and `seed_staging` refuse
      to run there; `GET /api/patients/` as Super Admin lists none of the `+96659999…` numbers).
- [ ] The first clinic and its clinic admin created by the Super Admin; the clinic signed what L1 says.
- [ ] `FIELD_ENCRYPTION_KEY` of production escrowed in Bitwarden ([secrets](secrets.md), section 5).

## 5. People

- [ ] The incident roles of the [incident response plan](security/incident-response.md) confirmed by name and phone.
- [ ] The 48-hour watch rota of section 7 filled in.
- [ ] The clinics know how to reach the team (`security@`, `privacy@`, a phone number) and the support hours.

## 6. Launch day (by hand)

1. Not during clinic hours, not on a Thursday evening (nobody to watch the weekend). Tell the team the time.
2. Freeze staging deploys as before a demo ([Runbook 9](runbooks/09-cd-staging.md), section 3), so nothing else moves.
3. Release v1.0.0 (Runbook 10, section 4). Take the database backup of step 2 even though it is empty.
4. `scripts/smoke-readonly.sh production`. Then the first real sign-in: the Super Admin on `https://app.iltiamcare.com`.
5. The first clinic admin and doctor sign in; the doctor opens an empty patient list; a test patient account of the
   team uploads one photo on the production app and the doctor sees the result. Then archive that test patient.
6. Tell the clinic it may start. Start the watch (section 7).

## 7. Rollback criteria and the 48-hour watch

**Roll back** with [Runbook 10, section 5](runbooks/10-production-release.md) at once if any of its criteria is met.
For the launch, also: **take production offline** (stop its tunnel, Runbook 5) if patient data could be shown to
the wrong person, and start the incident response.

**Watch rota**, from the launch time. Each shift checks every 2 hours while awake: `scripts/smoke-readonly.sh
production`, the alert mailbox, `docker stats` on the VM, the 5xx count in `iltiam production logs --since 2h
backend-web`, and any message from the clinic. Write each check (time, OK or what was wrong) in the #23 comment.

| Shift (Riyadh time) | Watcher | Backup |
|---|---|---|
| Launch to +12 h | Thabit | Omar |
| +12 h to +24 h | Omar | Thabit |
| +24 h to +36 h | Ahmed | Thabit |
| +36 h to +48 h | Mansour | Omar |

The watcher escalates to the incident lead (Thabit) at once for anything SEV-2 or higher.

## 8. Sign-off

- [ ] Sections 1 to 5 ticked with evidence on #23.
- [ ] Launch done (section 6), watch done (section 7), no open SEV-1 or SEV-2.
- [ ] Signed in the #23 comment by Thabit, with the date. Then #23 is closed.
