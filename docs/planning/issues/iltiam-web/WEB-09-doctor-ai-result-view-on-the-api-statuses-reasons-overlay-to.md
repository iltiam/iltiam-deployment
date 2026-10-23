# Doctor: AI result view on the API (statuses, reasons, overlay toggle, measurement, risk, versions)

> **Plan ID:** WEB-09 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #6 in Ahmed's list
> **Blocked by:** WEB-02, BE-06
> **Blocks:** WEB-10
> **SRS:** FR-D-5, FR-D-12, UC-DR-02

## Context

Backend `GET /api/wounds/visits/{id}/`: 6 statuses, decision status + reasons (10 codes), images (BE-06), measurement,
confidence_pct, risk (tier, factor_details, factors_not_evaluated), tissue (hidden when class empty; NON_VIABLE),
versions (e.g. segformer-b2@2.0.0+postprocess@2.0.0), disclaimer. Mock says "segmentation (U-Net)"; real is SegFormer-B2.

## Steps

- [ ] Poll until final; render each status; reasons with AR/EN texts (backend BE-18 when available).
- [ ] Overlay toggle (mask over photo), area ± uncertainty, L/W/P, confidence, risk factors, model version + time, comparison with previous.
- [ ] "Pending clinician review" when progression/risk are null; CDS disclaimer from the API.

## Acceptance criteria

- [ ] Matches the API for ACCEPTED, MANUAL_REVIEW, INSUFFICIENT, RETAKE_REQUIRED, FAILED on staging.

## Tests required

- Component tests per status with MSW.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
