# Password reset and change on the real backend

> **Plan ID:** MOB-06 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** S (≈1 day) · **Order:** #18 in Mohammad's list
> **Blocked by:** MOB-04
> **Blocks:** none
> **SRS:** FR-P-1.3, NFR-SEC-01

## Context

Mobile calls `/auth/password-reset/request|verify|confirm`; backend has `/api/auth/password/reset/request/`,
`/confirm/` (code + new password in one step) and `/password/change/`.

## Steps

- [ ] Map the two-step flow; live 5-rule checklist matches backend policy (incl. special character).
- [ ] Password change in profile.

## Acceptance criteria

- [ ] Reset works end to end on staging; policy errors show backend messages.

## Tests required

- Repository + widget tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
