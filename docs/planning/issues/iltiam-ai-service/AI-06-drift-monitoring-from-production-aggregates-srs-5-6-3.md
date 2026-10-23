# Drift monitoring from production aggregates (SRS 5.6.3)

> **Plan ID:** AI-06 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P2 · **Size:** M (≈2 days) · **Order:** #27 in Thabit's list
> **Blocked by:** AI-04, DEP#10
> **Blocks:** none
> **SRS:** SRS §5.6.3

## Context

Watch for drift without storing patient data in the AI service: weekly confidence, decision mix, quality metrics and area distributions from AI-04 metrics.

## Steps

- [ ] Weekly drift dashboard and alert on distribution shift.
- [ ] Doc: from a drift alert to re-evaluation and a model-change issue.

## Acceptance criteria

- [ ] Dashboard live; synthetic drift triggers the alert.

## Tests required

- Alert rule test.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
