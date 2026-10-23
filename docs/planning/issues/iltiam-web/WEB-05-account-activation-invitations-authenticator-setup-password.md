# Account activation, invitations, authenticator setup, password reset and change

> **Plan ID:** WEB-05 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #5 in Ahmed's list
> **Blocked by:** WEB-04
> **Blocks:** WEB-28
> **SRS:** FR-SA-3, FR-SA-4, FR-SA-6, FR-CA-3, NFR-SEC-01

## Context

Backend: `/api/auth/activate/` (token from email/SMS), `/activate/authenticator/`, `/password/reset/request|confirm/`,
`/password/change/`; Super Admin invitations (#29) require password + MFA + policy acceptance.

## Steps

- [ ] Activation page (`/activate?token=`), invitation acceptance with policies (texts from deployment #6), authenticator QR enrolment.
- [ ] Password reset/change with the 5-rule checklist.

## Acceptance criteria

- [ ] A newly created doctor and an invited Super Admin activate on staging end to end.

## Tests required

- Component tests; Playwright activation journey.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
