# Clinician-corrected wound boundary (FR-D-7) with recomputed area

> **Plan ID:** BE-29 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P2 · **Size:** M (≈2 days) · **Order:** #26 in Ahmed's list
> **Blocked by:** BE-06
> **Blocks:** WEB-30
> **SRS:** FR-D-7 (corrected wound boundary)

## Context

Owned by Ahmed with WEB-30 (Omar reviews). FR-D-7 lists "corrected wound boundary (if applicable)". Accept a polygon in
image coordinates, rasterise, compute area with the analysis' calibration (px_per_cm in ai_result), store as part of
the ClinicalReview (append-only), never change the AI result.

## Steps

- [ ] Review payload accepts `corrected.boundary` (polygon, <= 500 points).
- [ ] Server computes area/perimeter with stored calibration; stores corrected mask file.
- [ ] Side-by-side data in VisitDetail.validated_result.

## Acceptance criteria

- [ ] Corrected area within 1 % of a reference computation on a fixture; AI result unchanged.

## Tests required

- Geometry unit tests; API test.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
