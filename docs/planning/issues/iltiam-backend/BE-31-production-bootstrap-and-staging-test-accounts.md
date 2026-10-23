# Production bootstrap and staging test accounts

> **Plan ID:** BE-31 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #9 in Omar's list
> **Blocked by:** none
> **Blocks:** MOB-04, WEB-04
> **SRS:** FR-SA-3

## Context

A fresh production needs its first Full Super Admin without public sign-up; staging needs fixed test accounts whose
OTP can be read by automated smoke tests, without enabling OTP echo for real users.

## Steps

- [ ] `manage.py bootstrap_superadmin --phone --email` (one-time, refuses if any Super Admin exists; sends invitation).
- [ ] `OTP_DEV_ECHO_NUMBERS` allowlist (reserved +96659999xxxx range) honoured only when `ENVIRONMENT=staging`.
- [ ] `manage.py seed_staging` (clinic, admins, doctors, patients; idempotent).

## Acceptance criteria

- [ ] Production refuses OTP echo for any number; staging smoke logs in with test accounts.

## Tests required

- Unit tests for both commands and the allowlist guard.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
