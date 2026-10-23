# iOS push notifications: APNs key in Firebase, capabilities, permission flow

> **Plan ID:** MOB-35 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.1 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #31 in Mohammad's list
> **Blocked by:** MOB-34, MOB-11
> **Blocks:** MOB-36
> **SRS:** FR-P-3.2, FR-D-11

## Context

v1.1. FCM delivers to iOS through APNs: upload the APNs auth key to the Firebase project (DEP-13), add `GoogleService-Info.plist` per flavor, enable Push and Background Modes.

## Steps

- [ ] APNs key upload in Firebase.
- [ ] Capabilities and permission prompt; token registration reuses MOB-11.

## Acceptance criteria

- [ ] Backend test push arrives on an iPhone, foreground and background.

## Tests required

- Gateway tests (existing).

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
