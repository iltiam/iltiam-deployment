# Notification centre with deep links (all roles)

> **Plan ID:** WEB-14 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** S (≈1 day) · **Order:** #15 in Ahmed's list
> **Blocked by:** WEB-04
> **Blocks:** none
> **SRS:** FR-D-10, FR-D-11, FR-D-12

## Context

Backend `/api/notifications/` (list, read, read-all, preferences).

## Steps

- [ ] Bell with unread count; list; open target route from the deep link.

## Acceptance criteria

- [ ] ANALYSIS_FAILED and alert notifications open the right page.

## Tests required

- Component tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
