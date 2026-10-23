# Retention jobs from the PDPL retention schedule

> **Plan ID:** BE-22 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** M (≈2 days) · **Order:** #15 in Mansour's list
> **Blocked by:** DEP#6
> **Blocks:** none
> **SRS:** FR-SA-10 (>= 2 years), FR-D-13 (12 months), FR-P-7.1

## Context

Owned by Mansour (Omar reviews). Implement the schedule from deployment #6 as idempotent reminder rules
(`apps/notifications/reminders.py` pattern): archive/anonymise per data class, never hard-delete clinical records.

## Steps

- [ ] One rule per data class with dry-run; audit summary per run.
- [ ] Admin view of the last run results.

## Acceptance criteria

- [ ] Dry-run on staging lists exactly the rows the schedule predicts.

## Tests required

- Rule tests with frozen time.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
