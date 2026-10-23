# Doctor: AI result view (overlay toggle, area ± uncertainty, dimensions, confidence, risk factors, versions)

> **Plan ID:** MOB-15 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #13 in Mohammad's list
> **Blocked by:** MOB-13, BE-06
> **Blocks:** MOB-16
> **SRS:** FR-D-5, UC-DR-02

## Context

Backend VisitDetail with images and measurement (BE-06). Tissue hidden when ALG-03 is off (empty class); NON_VIABLE
supported; progression/risk null for MANUAL_REVIEW ("pending clinician review").

## Steps

- [ ] Result screen with overlay toggle, measurement block, confidence %, risk tier + factor details, model version + timestamp, CDS disclaimer (from `analysis.disclaimer`).
- [ ] Comparison with previous submission.

## Acceptance criteria

- [ ] Matches the web result view for the same visit.

## Tests required

- Widget tests incl. null tissue/risk.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
