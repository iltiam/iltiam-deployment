# Patient can cancel a pending deletion request

> **Plan ID:** BE-14 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #24 in Omar's list
> **Blocked by:** none
> **Blocks:** MOB-25
> **SRS:** FR-P-7.1

## Context

Mobile has a cancel action; backend has none.

## Steps

- [ ] `POST /api/patients/me/deletion-request/cancel/` while PENDING; audit; notify Super Admin queue.

## Acceptance criteria

- [ ] Cancelled request disappears from the SA queue; approved ones cannot be cancelled.

## Tests required

- API tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
