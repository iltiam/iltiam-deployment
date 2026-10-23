# Doctor: prescriptions upload and list (expiry, completed, refill requests)

> **Plan ID:** WEB-16 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** M (≈2 days) · **Order:** #16 in Ahmed's list
> **Blocked by:** WEB-07
> **Blocks:** none
> **SRS:** FR-D-9, FR-P-5.1

## Context

Backend: `/api/patients/{id}/prescriptions/` (signed PDF, medication fields, expiry), refill requests (BE-15).

## Steps

- [ ] Upload form with validation errors from backend; list Active/Completed/Expired; refill eligibility flag; refill request handling when BE-15 lands.

## Acceptance criteria

- [ ] Patient app receives the prescription; refill approve/reject round-trip.

## Tests required

- Component tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
