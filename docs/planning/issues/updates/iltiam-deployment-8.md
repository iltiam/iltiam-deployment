# Runbook 6: free backups and a weekly tested restore on the VM (Postgres dumps, volume backups)

> **Plan ID:** DEP#8 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #19 in Thabit's list
> **Blocked by:** DEP#2, DEP-02
> **Blocks:** DEP-04
> **SRS:** NFR-REL-02, NFR-REL-04 (daily, RTO 4 h, weekly restore test)

## Context

Free-first (ADR-0004): Oracle **Always Free** in the Riyadh home region: one Ampere A1 (ARM, aarch64) VM with **2 OCPUs and 12 GB** (Oracle's current Always Free A1 allowance), 200 GB block storage in total, 20 GB object storage, software-protected Vault keys. Staging and production share this one VM as separate Compose projects. Always Free includes 5 volume backups in total and the 20 GB object storage, in the home region only. Keep
backups free and in the Kingdom: nightly encrypted `pg_dump` to the Riyadh backup bucket (Infrequent Access), plus
weekly volume backups within the 5 free. The restore test runs **on the VM** (production dumps never leave the
Kingdom; no restore on GitHub runners). A copy to Jeddah is optional and costs cents per month. Reassigned from Omar to
ben-fatah. Write it as a runbook a teammate with no cloud experience can follow: numbered steps, exact console menu names, commands to paste, what you should see, and what to do if it fails. Never paste a secret into the runbook.

## Steps

- [ ] `backup` service per environment (cron 02:30 Asia/Riyadh): `pg_dump -Fc` of both databases, encrypt with `age`, upload to `iltiam-<env>-backups`; keep 14 dailies + 8 weeklies; write a heartbeat for monitoring.
- [ ] Volume backup policy: block volume weekly, keep 2; boot volume monthly, keep 1 (stays within 5 free).
- [ ] Weekly restore test (cron on the VM): newest dump -> throwaway Postgres container -> `manage.py check` + row counts -> result to monitoring; delete the container.
- [ ] Timed rehearsal: restore staging onto a fresh volume with `docs/runbooks/06-restore.md`; record the time (target < 4 h).
- [ ] Optional: copy production dumps to a Jeddah bucket (paid, ~cents) once real patients exist.

## Acceptance criteria

- [ ] Two consecutive green weekly restore tests before go-live.
- [ ] Rehearsal under 4 h.
- [ ] A missing nightly backup raises an alert; billing still $0.

## Tests required

- The weekly restore job; alert test by disabling the cron once on staging.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
