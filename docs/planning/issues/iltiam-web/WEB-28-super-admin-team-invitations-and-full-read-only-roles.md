# Super Admin: team invitations and Full/Read-only roles

> **Plan ID:** WEB-28 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** S (≈1 day) · **Order:** #24 in Ahmed's list
> **Blocked by:** WEB-05
> **Blocks:** none
> **SRS:** FR-SA-3, FR-SA-11

## Context

Backend: `/api/admins/` (GET/POST), `/{id}/access/`, `/{id}/status/`, `/{id}/resend-invitation/`.

## Steps

- [ ] Team page; invite; change access (step-up); deactivate; resend.

## Acceptance criteria

- [ ] Role change ends the target session (backend).

## Tests required

- Component tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
