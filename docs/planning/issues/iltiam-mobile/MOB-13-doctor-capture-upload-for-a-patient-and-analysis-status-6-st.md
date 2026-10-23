# Doctor: capture/upload for a patient and analysis status (6 statuses, 10 reasons)

> **Plan ID:** MOB-13 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #12 in Mohammad's list
> **Blocked by:** MOB-12, BE-06
> **Blocks:** MOB-15, MOB-18
> **SRS:** FR-D-4, FR-D-12, UC-DR-01

## Context

Doctor upload goes to `POST /api/wounds/upload/` (patient_id, image, anatomical_location, marker_confirmed,
clinical_notes, confirm_duplicate); status from `GET /api/wounds/visits/{id}/` (ANALYSIS_PENDING with queue_position,
PROCESSING, COMPLETED, MANUAL_REVIEW, RETAKE_REQUIRED, FAILED). RetakeReason lacks MARKER_SKEWED, WOUND_NOT_FOUND,
WOUND_TOO_SMALL, LOW_SEGMENTATION_CONFIDENCE.

## Steps

- [ ] Reuse the guided capture; patient-targeted upload; queue position display.
- [ ] All Reason codes with AR/EN texts (prefer backend texts from BE-18 when available).

## Acceptance criteria

- [ ] Each status reproduced on staging; FAILED shows retry (MOB-18).

## Tests required

- Status parsing tests for all statuses/reasons.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
