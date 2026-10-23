# Push notifications with FCM on Android (setup and device registration)

> **Plan ID:** MOB-11 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #10 in Mohammad's list
> **Blocked by:** MOB-02, BE-19, DEP-13
> **Blocks:** MOB-24, MOB-35
> **SRS:** FR-P-3.2, FR-D-11

## Context

Push is off (no Firebase files; `FCM_ENABLED`). ben-fatah creates the Firebase project (DEP-13); iOS push is v1.1 (MOB-35). Backend devices API: `POST /api/notifications/devices/`, `POST .../devices/unregister/`.

## Steps

- [ ] `google-services.json` per flavor injected in CI from secrets; `FCM_ENABLED` on in staging/prod flavors.
- [ ] Register token after login and on refresh; unregister on logout; Android 13 permission prompt (existing).
- [ ] Foreground/background handling with the existing presenter.

## Acceptance criteria

- [ ] Backend test push (BE-19) arrives on Android, foreground and background.

## Tests required

- Gateway tests with fake messaging.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
