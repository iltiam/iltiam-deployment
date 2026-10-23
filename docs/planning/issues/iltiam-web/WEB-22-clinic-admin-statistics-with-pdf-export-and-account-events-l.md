# Clinic Admin: statistics with PDF export and account events log

> **Plan ID:** WEB-22 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** M (≈2 days) · **Order:** #14 in Mansour's list
> **Blocked by:** WEB-20, BE-26
> **Blocks:** none
> **SRS:** FR-CA-4, FR-CA-5, UC-CA-03

## Context

Backend: `/api/clinic/stats/`, `/api/clinic/stats/export/`, clinic-scoped events (BE-26).

## Steps

- [ ] Stats page with date filter and export; events log with type/date filters.

## Acceptance criteria

- [ ] No patient-identifiable data shown.

## Tests required

- Component tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
