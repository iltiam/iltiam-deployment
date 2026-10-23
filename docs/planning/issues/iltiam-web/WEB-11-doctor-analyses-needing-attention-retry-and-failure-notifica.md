# Doctor: analyses needing attention, retry, and failure notifications

> **Plan ID:** WEB-11 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #3 in Mansour's list
> **Blocked by:** WEB-02
> **Blocks:** none
> **SRS:** FR-D-12

## Context

Backend: `GET /api/wounds/visits/attention/` (FAILED + MANUAL_REVIEW unreviewed), `POST /api/wounds/visits/{id}/retry/`,
ANALYSIS_FAILED notifications.

## Steps

- [ ] Attention list with error code meaning (AR/EN), retry button and states.

## Acceptance criteria

- [ ] A failed analysis (AI stopped on staging) can be retried to COMPLETED.

## Tests required

- Component tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
