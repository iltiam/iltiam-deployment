# FR-D-5: Super Admin changes the manual-review threshold (OTP, 40 % floor, audit, applied to analyses)

> **Plan ID:** BE-11a · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #20 in Omar's list
> **Blocked by:** BE-12, AI-02
> **Blocks:** BE-11b, WEB-26
> **SRS:** FR-D-5, UC-SA-03, NFR-MAI-02

## Context

In scope by owner decision. The threshold is configurable only by a Full Super Admin in the AI Model panel. Each change
needs OTP (step-up), a separate confirmation below 40 %, and an audit entry with previous/new value, time, admin id.
The backend sends the active threshold with each analysis (AI-02); null = AI default per model.

## Steps

- [ ] Model `AIThresholdSetting` (append-only history).
- [ ] `GET/POST /api/ai/model/threshold/` (Full SA; RequiresStepUp; `confirm_below_floor` required < 0.40).
- [ ] AI client sends `manual_review_threshold`; analyses store the applied value (already in result).
- [ ] Backend `LOW_CONFIDENCE_THRESHOLD` (0.60 constant) replaced by the active setting where used.

## Acceptance criteria

- [ ] Read-only SA gets 403; change without step-up 403; < 0.40 without confirmation 400; audit row has prev/new.

## Tests required

- API + audit tests; AI client payload test.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
