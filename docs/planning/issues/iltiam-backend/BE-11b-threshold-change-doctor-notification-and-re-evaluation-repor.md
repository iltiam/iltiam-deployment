# Threshold change: doctor notification and re-evaluation report

> **Plan ID:** BE-11b · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #23 in Omar's list
> **Blocked by:** BE-11a, AI-03
> **Blocks:** WEB-26
> **SRS:** FR-D-5 (c), (d)

## Context

After a threshold change: (c) an automated re-evaluation report within 24 h, (d) a system-wide notification to all active
doctors.

## Steps

- [ ] Celery task calls AI `POST /v1/threshold-report` and stores the report with the setting.
- [ ] `GET /api/ai/model/threshold/history/` returns changes with reports.
- [ ] Notify all active doctors (in-app + push) in their language.

## Acceptance criteria

- [ ] Change on staging produces a stored report within minutes and notifications to every active doctor.

## Tests required

- Task tests with fake AI; notification fan-out test.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
