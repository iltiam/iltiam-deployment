# Phone codes through Authentica, email provider, and the OTP fallback prompt

> **Plan ID:** BE-20 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #18 in Omar's list
> **Blocked by:** DEP#3, DEP-01, DEP-14
> **Blocks:** none
> **SRS:** FR-SA-9 (SMS timeout 30 s, fallback), FR-D-1, FR-P-1.3

## Context

Decision (ADR-0004): the backend keeps its own codes (hashed, `apps/accounts/otp.py`), lockout, CAPTCHA, remember-device
and step-up; only delivery changes. A new `AuthenticaSMSBackend` in `apps/notifications/sms.py` (the only module allowed
to talk to an SMS provider) calls `POST https://api.authentica.sa/api/v2/send-sms` (header `X-Authorization`, body
`phone` in E.164, our bilingual `message`, approved `sender_name`). Twilio stays as an alternative backend. Authentica
documents no delivery webhook, so FR-SA-9's 30-second rule lives in the login flow.

## Steps

- [ ] `AuthenticaSMSBackend`: timeouts, retry on 5xx/429, `SMSDeliveryError` on failure, never logs the code.
- [ ] Settings `SMS_BACKEND`, `AUTHENTICA_API_KEY`, `AUTHENTICA_SENDER_NAME`; production refuses the console backend.
- [ ] Login step: after 30 s without a verify, or on a provider error, show "OTP delivery failed. Please select an alternative method.": email code, authenticator app (staff), or WhatsApp code through Authentica.
- [ ] Email via the verified domain (DEP-01) with bilingual templates (OTP, invitation, activation, breach).

## Acceptance criteria

- [ ] On staging a real code arrives by SMS from the sender name; a forced provider error shows the fallback prompt; email OTP works.

## Tests required

- Fake HTTP adapter tests (success, 401, 429, 5xx, timeout); a test that the code never appears in logs.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
