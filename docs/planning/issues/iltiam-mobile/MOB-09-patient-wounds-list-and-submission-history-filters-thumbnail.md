# Patient wounds list and submission history (filters, thumbnails, AI summary)

> **Plan ID:** MOB-09 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #9 in Mohammad's list
> **Blocked by:** BE-07, MOB-04
> **Blocks:** MOB-10, MOB-26
> **SRS:** FR-P-2.3, NFR-PERF-04

## Context

WoundRepository is always mock. Backend: `GET /api/wounds/` (latest_visit_id, progression_color),
`GET /api/wounds/mine/visits/` (BE-07, filters date/location/status).

## Steps

- [ ] Dio repositories; Active/History toggle; filters; pagination; thumbnails via presigned URLs.
- [ ] Status colour from the 5 ALG-04 statuses + grey (see MOB-10).

## Acceptance criteria

- [ ] 50 records load < 5 s on 4G profile; no numbers for results pending review.

## Tests required

- Repository + widget tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
