# Doctor dashboard summary endpoint (risk-ranked worklist)

> **Plan ID:** BE-37 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #19 in Omar's list
> **Blocked by:** none
> **Blocks:** MOB-18
> **SRS:** FR-D-3, NFR-USA-02, NFR-PERF-02

## Context

Web and mobile both compose the doctor dashboard client-side today (mock). NFR-USA-02: identify the highest-risk
patient within 15 s. One endpoint keeps both apps consistent and fast.

## Steps

- [ ] `GET /api/doctor/dashboard/`: counts (patients, needs review, failed, active alerts, today's appointments), top-N patients ranked by risk/alerts, recent activity.
- [ ] Cached per doctor 60 s; invalidated on new analysis/alert.

## Acceptance criteria

- [ ] Response < 300 ms on staging seed of 50 patients.

## Tests required

- API + ranking unit tests; RBAC.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
