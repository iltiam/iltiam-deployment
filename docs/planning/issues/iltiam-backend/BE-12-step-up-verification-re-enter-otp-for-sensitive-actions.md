# Step-up verification (re-enter OTP) for sensitive actions

> **Plan ID:** BE-12 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #16 in Omar's list
> **Blocked by:** none
> **Blocks:** BE-11a, BE-13, MOB-25
> **SRS:** FR-P-7.1, FR-D-5 (OTP confirmation), NFR-SEC

## Context

Mobile privacy screens call `/auth/step-up/otp` and `/verify` (missing in backend); FR-D-5 requires OTP to confirm a
threshold change. One generic mechanism: request a code, verify, get a short-lived step-up token (5 min) bound to
the session and an action scope.

## Steps

- [ ] `POST /api/auth/step-up/` {action} -> challenge; `POST /api/auth/step-up/verify/` -> step_up_token (scope, 5 min, single use).
- [ ] Decorator/permission `RequiresStepUp(scope)` for export, deletion request, consent withdrawal, threshold change, admin role changes.
- [ ] Audit both steps; reuse lockout rules.

## Acceptance criteria

- [ ] Export without a step-up token -> 403 STEP_UP_REQUIRED; with a valid one -> allowed once.

## Tests required

- API tests incl. expiry, reuse, wrong scope.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
