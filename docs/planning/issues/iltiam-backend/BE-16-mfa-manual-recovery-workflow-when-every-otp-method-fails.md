# MFA manual recovery workflow when every OTP method fails

> **Plan ID:** BE-16 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #11 in Ahmed's list
> **Blocked by:** none
> **Blocks:** WEB-29
> **SRS:** FR-SA-9 (fallback 3: manual recovery)

## Context

Owned by Ahmed with WEB-29 (Omar reviews). FR-SA-9: if SMS, email and authenticator all fail, the user can start a
manual recovery handled by authorised support; the request is logged and a security notification generated.

## Steps

- [ ] `POST /api/auth/recovery-requests/` (phone + password verified, rate limited).
- [ ] Super Admin queue: verify identity out of band, approve -> reset MFA factors and force re-enrolment; reject with reason.
- [ ] Security notification to the account owner; audit every step.

## Acceptance criteria

- [ ] Full lifecycle on staging; a recovered account must re-enrol MFA at next login.

## Tests required

- API tests incl. throttling and audit.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
