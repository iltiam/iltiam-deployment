# Sign-in security: CAPTCHA after 3 failures, remember device 30 days, biometric unlock, 15-min timeout

> **Plan ID:** MOB-05 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #5 in Mohammad's list
> **Blocked by:** MOB-04
> **Blocks:** none
> **SRS:** FR-P-1.1, NFR-SEC-02, NFR-SEC-03

## Context

Backend returns CAPTCHA_REQUIRED after 3 failures (Turnstile token), honours `device_token` for 30 days, ends sessions
after 15 minutes idle (server-side `sid`).

## Steps

- [ ] Turnstile widget (webview) when CAPTCHA_REQUIRED.
- [ ] Store and send `device_token`; biometric only unlocks a stored session (never a factor alone).
- [ ] Idle timer aligned with server SESSION_EXPIRED handling.

## Acceptance criteria

- [ ] All four behaviours demonstrable on staging; biometric never logs in after server session expiry without OTP.

## Tests required

- Controller tests for each path.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
