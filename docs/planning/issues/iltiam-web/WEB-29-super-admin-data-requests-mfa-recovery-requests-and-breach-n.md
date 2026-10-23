# Super Admin: data requests, MFA recovery requests and breach notification console

> **Plan ID:** WEB-29 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** M (≈2 days) · **Order:** #25 in Ahmed's list
> **Blocked by:** BE-16, BE-17
> **Blocks:** none
> **SRS:** FR-P-7.1, FR-SA-9

## Context

Backend: `/api/data-requests/` (approve/reject), recovery requests (BE-16), breach incidents (BE-17).

## Steps

- [ ] Deletion request queue with 30-day due dates; recovery queue; breach console with 72 h countdown and delivery status.

## Acceptance criteria

- [ ] Each queue processes a request end to end on staging.

## Tests required

- Component tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
