# Doctor: dashboard and worklist (needs review, failed with retry)

> **Plan ID:** MOB-18 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #16 in Mohammad's list
> **Blocked by:** MOB-13, BE-37
> **Blocks:** none
> **SRS:** FR-D-3, FR-D-12, NFR-USA-02

## Context

Backend: `GET /api/doctor/dashboard/` (BE-37), `GET /api/wounds/visits/attention/`, `POST /api/wounds/visits/{id}/retry/`.

## Steps

- [ ] Dashboard tiles + risk-ranked list; worklist with retry; pull to refresh.

## Acceptance criteria

- [ ] Highest-risk patient visible on first screen; retry moves FAILED back to pending.

## Tests required

- Widget tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
