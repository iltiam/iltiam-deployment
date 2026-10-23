# Push notifications in production: FCM (Android), device lifecycle, test push

> **Plan ID:** BE-19 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #17 in Omar's list
> **Blocked by:** DEP#3, DEP-13
> **Blocks:** MOB-11
> **SRS:** FR-P-3.2, FR-D-11

## Context

FCMPushBackend exists (#25). Production needs the service account from the Firebase project ben-fatah creates (DEP-13),
platform-tagged device tokens, invalid-token cleanup and a test push. Android in v1.0; iOS uses the same FCM path once
MOB-35 (v1.1) adds APNs.

## Steps

- [ ] Read credentials from a secret file path; refuse console backend in production.
- [ ] Device registration stores platform/app version; remove tokens FCM reports invalid.
- [ ] `POST /api/notifications/devices/test/` (own devices) for QA; document deep link payload format for MOB-24.

## Acceptance criteria

- [ ] Test push arrives on an Android phone running the staging build.

## Tests required

- Push backend tests with a fake FCM client.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
