# Patient data export as background jobs (JSON/PDF) with status and download

> **Plan ID:** BE-13 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #21 in Omar's list
> **Blocked by:** BE-12
> **Blocks:** MOB-25
> **SRS:** FR-P-7.1

## Context

Export is synchronous (`GET /api/patients/me/export/`); mobile expects jobs (`/patients/me/exports`, status,
download URL). Large histories (images) need a background job and a presigned download.

## Steps

- [ ] `POST /api/patients/me/exports/` {format} (step-up) -> job; `GET` list/detail with status; `GET .../download/` presigned (15 min).
- [ ] Celery task builds JSON or PDF (bilingual), zips images optionally; expires after 7 days.
- [ ] Notify patient when ready; audit.

## Acceptance criteria

- [ ] Export of a 50-visit patient completes and downloads; expired link refused.

## Tests required

- Task + API tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
