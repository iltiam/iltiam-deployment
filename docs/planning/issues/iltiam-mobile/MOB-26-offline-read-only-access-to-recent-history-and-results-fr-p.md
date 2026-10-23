# Offline read-only access to recent history and results (FR-P-7.2)

> **Plan ID:** MOB-26 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** M (≈2 days) · **Order:** #23 in Mohammad's list
> **Blocked by:** MOB-09, MOB-08
> **Blocks:** none
> **SRS:** FR-P-7.2, NFR-AVA-02

## Context

Read-only access to the most recent wound history and AI results while offline, with a clear offline indicator.

## Steps

- [ ] Encrypted cache of the last N results/history pages and thumbnails; stale markers; refresh on reconnect.

## Acceptance criteria

- [ ] Airplane mode shows the last results and history; no stale numbers after a doctor review once online.

## Tests required

- Cache tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
