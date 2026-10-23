# Runbook 11: Firebase project for FCM push on Android (service account and app configs)

> **Plan ID:** DEP-13 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #10 in Thabit's list
> **Blocked by:** none
> **Blocks:** BE-19, MOB-11
> **SRS:** FR-P-3.2, FR-D-11

## Context

Decision: ben-fatah creates the Firebase project; FCM push on Android ships in v1.0 (iOS/APNs in v1.1, MOB-35).
The backend sends through FCM HTTP v1 with a service account; the Android app needs `google-services.json` per
flavor. Firebase is used for push only, not for phone sign-in (ADR-0004, DEP-14). Write it as a runbook a teammate with no cloud experience can follow: numbered steps, exact console menu names, commands to paste, what you should see, and what to do if it fails. Never paste a secret into the runbook.

## Steps

- [ ] console.firebase.google.com -> Add project `iltiam` (Analytics off).
- [ ] Add an Android app for each flavor package id (dev, staging, prod from MOB-02); download each `google-services.json` -> iltiam-mobile repository secrets (base64), never committed.
- [ ] Project settings -> Service accounts -> Generate new private key -> GitHub Environment secret `FCM_SERVICE_ACCOUNT_JSON`.
- [ ] Check that Cloud Messaging API (V1) is enabled.
- [ ] Write `docs/runbooks/11-firebase.md`; add entries to `docs/secrets.md`.

## Acceptance criteria

- [ ] Backend test push (BE-19) reaches a staging Android build.

## Tests required

- Manual test push recorded in the issue.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
