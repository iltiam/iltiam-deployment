# Doctor: care plan editor and shared notes control

> **Plan ID:** WEB-17 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** M (≈2 days) · **Order:** #13 in Mansour's list
> **Blocked by:** WEB-07
> **Blocks:** none
> **SRS:** FR-P-5.2

## Context

Backend: `/api/patients/{id}/care-plan/` (versions, both languages, acknowledgement status).

## Steps

- [ ] Versioned editor AR/EN; publish; acknowledgement status; history.

## Acceptance criteria

- [ ] Patient acknowledgement visible to the doctor.

## Tests required

- Component tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
