# Super Admin: cross-clinic doctors (create, deactivate, archive, soft delete)

> **Plan ID:** WEB-24 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** S (≈1 day) · **Order:** #18 in Ahmed's list
> **Blocked by:** WEB-04, BE-25
> **Blocks:** none
> **SRS:** FR-SA-6, Table 11, Table 15

## Context

Backend: `/api/clinics/{id}/doctors/` and the SA status endpoint (BE-25). Read-only SA sees no write actions.

## Steps

- [ ] Doctor directory across clinics; actions per role; confirmations.

## Acceptance criteria

- [ ] Read-only SA cannot see or call write actions.

## Tests required

- Component tests per sub-role.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
