# Breach notification to affected patients within 72 hours

> **Plan ID:** BE-17 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #13 in Ahmed's list
> **Blocked by:** none
> **Blocks:** WEB-29
> **SRS:** FR-P-7.1 (breach notification within 72 h)

## Context

Owned by Ahmed with WEB-29 (Omar reviews). Supports the runbook in deployment DEP-09.

## Steps

- [ ] Super Admin records an incident (description AR/EN, discovered_at, affected scope: clinic/patients).
- [ ] Send notice by email + in-app + SMS in the patient's language; track delivery; 72 h countdown visible.
- [ ] Audit everything; export the notification record.

## Acceptance criteria

- [ ] Staging rehearsal notifies a selected set of test patients with delivery tracked.

## Tests required

- API + fan-out tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
