# Real sign-in: password, OTP (SMS/email/authenticator), resend, CAPTCHA, lockout, timeout, role routing

> **Plan ID:** WEB-04 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #4 in Ahmed's list
> **Blocked by:** WEB-02, BE-31
> **Blocks:** WEB-05, WEB-14, WEB-19, WEB-20, WEB-24, WEB-23, WEB-25, WEB-27
> **SRS:** FR-SA-1, FR-SA-2, FR-SA-9, FR-CA-1, FR-D-1, NFR-SEC-02/03

## Context

Backend: `POST /api/auth/login/` -> challenge; `/login/verify/` (challenge_id, otp_code, method); `/login/resend/`;
CAPTCHA_REQUIRED (Turnstile) after 3 failures; lockout 10 min after 5; 15-min idle server sessions; role change ends
session (SESSION_EXPIRED).

## Steps

- [ ] Login + OTP screens on the API (method switch, "OTP delivery failed" prompt from BE-20).
- [ ] Session from `/api/auth/me/`; role routing; idle warning at 14 min aligned with server.
- [ ] Logout; refresh-once middleware (exists, tested).

## Acceptance criteria

- [ ] Doctor, Clinic Admin, Full and Read-only Super Admin seeded accounts sign in on staging and land on their home.

## Tests required

- Vitest for auth state; Playwright login journey (WEB-32).

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
