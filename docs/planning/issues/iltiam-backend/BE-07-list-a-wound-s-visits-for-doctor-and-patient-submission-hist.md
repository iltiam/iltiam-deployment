# List a wound's visits for doctor and patient (submission history and image timeline)

> **Plan ID:** BE-07 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #12 in Omar's list
> **Blocked by:** none
> **Blocks:** MOB-09, WEB-07
> **SRS:** FR-D-3, FR-D-6, FR-P-2.3

## Context

Only `latest_visit_id` and the measured series exist; FR-D-6 needs a chronological image timeline and FR-P-2.3 a
history with thumbnails and filters (date, location, status).

## Steps

- [ ] `GET /api/wounds/{id}/visits/` (doctor, own patients): id, submission_id, created_at, status, area, decision status, thumbnail URL.
- [ ] `GET /api/wounds/mine/visits/` (patient, all wounds, filters date/location/status), numbers only when patient-visible (#18 rule).
- [ ] Pagination, RBAC matrix, docs.

## Acceptance criteria

- [ ] Patient never sees numbers of a result pending review; 50 records load < 1 s on staging data.

## Tests required

- API tests incl. RBAC; query-count test.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
