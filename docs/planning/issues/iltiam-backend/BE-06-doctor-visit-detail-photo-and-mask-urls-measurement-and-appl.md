# Doctor visit detail: photo and mask URLs, measurement and applied threshold

> **Plan ID:** BE-06 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #11 in Omar's list
> **Blocked by:** BE-05
> **Blocks:** BE-29, MOB-13, MOB-15, WEB-09
> **SRS:** FR-D-5, UC-DR-02

## Context

FR-D-5 needs a segmentation overlay with a toggle, area ± uncertainty, length/width/perimeter and model version.
`VisitDetailSerializer` (apps/wounds/serializers.py:156) has no image URL; dimensions exist only inside raw `result`.

## Steps

- [ ] `images: {photo_url, mask_url}` (presigned <= 15 min) on VisitDetail.
- [ ] `measurement: {area_cm2, uncertainty_cm2, length_cm, width_cm, perimeter_cm, region_count}` and `decision.manual_review_threshold` on AnalysisResult.
- [ ] Regenerate OpenAPI; update docs/api/analysis-status.md (MANUAL_REVIEW wording: "below the configured threshold", not 60 %).

## Acceptance criteria

- [ ] COMPLETED visit returns both URLs and measurement; RETAKE_REQUIRED returns photo_url and mask_url null; another doctor gets 404.

## Tests required

- Serializer + API tests; OpenAPI contract test validates the response.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
