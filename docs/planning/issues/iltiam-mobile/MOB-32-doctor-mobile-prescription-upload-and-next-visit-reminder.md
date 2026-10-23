# Doctor (mobile): prescription upload and next-visit reminder

> **Plan ID:** MOB-32 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P2 · **Size:** M (≈2 days) · **Order:** #29 in Ahmed's list
> **Blocked by:** MOB-12, BE-15
> **Blocks:** none
> **SRS:** FR-D-9, FR-D-10

## Context

Built by Ahmed in Flutter (he owns the same feature on the web); Mohammad reviews. Backend: `/api/patients/{id}/prescriptions/` (signed PDF, expiry, refill eligibility), `/api/patients/{id}/next-visit/`.

## Steps

- [ ] Pick PDF from files, metadata fields, upload; schedule/cancel next visit.

## Acceptance criteria

- [ ] Patient receives the prescription notification.

## Tests required

- Repository tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
