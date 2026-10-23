# OpenAPI as the single API contract: versioning, breaking-change check, published artifact

> **Plan ID:** BE-01 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #4 in Omar's list
> **Blocked by:** none
> **Blocks:** MOB-01, WEB-02
> **SRS:** NFR-USA-03; SRS §13.3.2

## Context

Web and mobile will generate their clients from `docs/api/openapi.json` (WEB-02, MOB-01). Today the web keeps a
hand-written mirror (8 of 89 paths) and mobile guessed ~30 paths. Make the backend contract the one source of truth
and protect clients from silent breaks.

## Steps

- [ ] Keep `docs/api/openapi.json` generated in CI (already); add `oasdiff breaking` against `main` on every PR; a breaking change needs the `breaking-api` label and a note to web/mobile.
- [ ] Publish the spec as a CI artifact and on each release tag (`api-vX.Y.Z`); expose `/api/schema/` on staging only.
- [ ] Document conventions in `docs/api/README.md`: error envelope, pagination, enum casing, date/time (ISO 8601, Asia/Riyadh), file URLs (presigned, 15 min), idempotency, deep links.
- [ ] Add operationIds/tags review so generated client method names are stable.

## Acceptance criteria

- [ ] A PR that removes a field fails CI unless labelled.
- [ ] Web and mobile can download the spec for a given tag.

## Tests required

- CI job; unit test that every view has an operationId.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
