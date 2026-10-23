# Sign-in on the real backend: phone + password + OTP (SMS/email/authenticator), tokens, refresh, role routing

> **Plan ID:** MOB-04 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #4 in Mohammad's list
> **Blocked by:** MOB-01, BE-31
> **Blocks:** MOB-05, MOB-06, MOB-07, MOB-09, MOB-12, MOB-14, MOB-17, MOB-20, MOB-21, MOB-22, MOB-23
> **SRS:** FR-P-1.1, FR-D-1; SRS divergence recorded: password step kept

## Context

AuthRepository is always MockAuthRepository (lib/providers.dart:15-17). Backend: `POST /api/auth/login/` (phone,
password) -> challenge; `POST /api/auth/login/verify/` (challenge_id, otp_code, method, remember_device) -> tokens,
user, device_token; `/login/resend/`; `/token/refresh/`; `/logout/`. Owner decision: keep password + code; record the
divergence from FR-P-1.1's wording in the SRS divergences.

## Steps

- [ ] DioAuthRepository; sign-in screen gains the password field; OTP screen supports method switch and resend.
- [ ] Tokens in secure storage; role from `user.role` routes to patient or doctor shell; other roles refused with a message.
- [ ] Logout blacklists refresh token.

## Acceptance criteria

- [ ] Seeded patient and doctor accounts sign in on a real phone against staging; wrong code/lockout messages come from the backend in AR/EN.

## Tests required

- Repository + controller tests with a fake HTTP adapter; widget tests for both screens.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
