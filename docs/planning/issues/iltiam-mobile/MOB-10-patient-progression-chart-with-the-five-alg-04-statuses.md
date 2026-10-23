# Patient progression chart with the five ALG-04 statuses

> **Plan ID:** MOB-10 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** S (≈1 day) · **Order:** #19 in Mohammad's list
> **Blocked by:** MOB-09, BE-09
> **Blocks:** none
> **SRS:** FR-P-2.3, FR-D-6 colours

## Context

`HealingTrend` has 3 values (lib/data/models/wound.dart:6); FR-P-2.3 uses IMPROVING (green), SLOWING (amber), STALLED
(amber), DETERIORATING (red), INSUFFICIENT_DATA (grey). Backend: `GET /api/wounds/{id}/progression/` (patient view).

## Steps

- [ ] Enum and colours; chart from the patient-visible series; trend label in plain language AR/EN.

## Acceptance criteria

- [ ] Seeded series (BE-09) shows the correct status and colour.

## Tests required

- Unit tests for mapping; golden test of the chart.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
