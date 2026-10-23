# Doctor: progression timeline on the API (chart, healing rate, colours, alerts, model-change warning)

> **Plan ID:** WEB-12 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #7 in Ahmed's list
> **Blocked by:** WEB-02, BE-09
> **Blocks:** none
> **SRS:** FR-D-6, UC-DR-03, NFR-PERF-04

## Context

Backend `GET /api/wounds/{id}/progression/` (series, trend, color, healing_rate, expected_area, deviation, risk,
status PENDING/CURRENT, active_alerts, disclaimer). #55 adds SEGMENTATION_MODEL_CHANGED.

## Steps

- [ ] Chart and table from the API; date filter; 5 trends + grey; show model-change warning when present.

## Acceptance criteria

- [ ] Seeded series (BE-09) renders with the right colour < 5 s.

## Tests required

- Component tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
