# Doctor: alerts panel, acknowledge with justification, risk-ranked dashboard

> **Plan ID:** WEB-13 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #4 in Mansour's list
> **Blocked by:** WEB-02
> **Blocks:** none
> **SRS:** FR-D-11, NFR-USA-02

## Context

Backend: `GET /api/alerts/`, `POST /api/alerts/{id}/acknowledge/`; dashboard summary `GET /api/doctor/dashboard/`
(BE-37) - compose from patients/alerts/attention until it lands, then switch.

## Steps

- [ ] Alerts list with priority, acknowledge modal; dashboard tiles and worklist.

## Acceptance criteria

- [ ] Highest-risk patient identifiable within 15 s of login (NFR-USA-02) in a hallway test.

## Tests required

- Component tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
