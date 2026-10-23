# Deep links, in-app notification centre and read state

> **Plan ID:** MOB-24 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #15 in Mohammad's list
> **Blocked by:** MOB-11
> **Blocks:** none
> **SRS:** FR-P-3.2 (deep link on every alert)

## Context

Every notification carries a deep link (backend catalog); the app needs routes for visit result, appointment,
prescription, care plan, message, alert, and an in-app list from `/api/notifications/` with read/read-all.

## Steps

- [ ] Route table matching backend deep-link format (BE-19 doc).
- [ ] Notification centre with unread badge.

## Acceptance criteria

- [ ] Tapping each notification type opens the right screen from cold start.

## Tests required

- Router tests per link type.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
