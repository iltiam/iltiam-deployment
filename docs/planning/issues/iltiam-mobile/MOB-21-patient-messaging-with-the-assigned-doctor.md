# Patient messaging with the assigned doctor

> **Plan ID:** MOB-21 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** M (≈2 days) · **Order:** #22 in Ahmed's list
> **Blocked by:** MOB-04
> **Blocks:** none
> **SRS:** FR-P-6.1

## Context

Built by Ahmed in Flutter (he owns the same feature on the web); Mohammad reviews. Backend: `/api/messages/mine/` (GET/POST), `/api/messages/mine/read/`; attachment = a visit id from history; auto-reply
when the doctor is unavailable.

## Steps

- [ ] Map thread, statuses, attachment picker from history, offline outbox, push on doctor reply.

## Acceptance criteria

- [ ] Round-trip with doctor web/mobile.

## Tests required

- Repository + outbox tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
