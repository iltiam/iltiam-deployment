# Patient photo upload on the real backend (fields, duplicate 409, idempotency, offline queue)

> **Plan ID:** MOB-07 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #7 in Mohammad's list
> **Blocked by:** MOB-04
> **Blocks:** MOB-08
> **SRS:** FR-P-2.1, FR-P-2.2, UC-PT-01, NFR-PERF-03

## Context

DioUploadGateway posts `photo` + `metadata` JSON to `/images/upload`. Backend: `POST /api/wounds/mine/upload/`
multipart `image`, `anatomical_location` (codes), `marker_confirmed=true`, `notes`, structured notes (BE-42),
`confirm_duplicate`; 201 `{visit, warnings}`; 409 DUPLICATE_SUBMISSION with previous visit details.

## Steps

- [ ] Map fields and location codes; send `Idempotency-Key` (honoured once BE-34 lands).
- [ ] 409 -> existing duplicate dialog -> resend with `confirm_duplicate=true`.
- [ ] Keep the 8 MP check and ~4 MB compression; queue up to 10 offline (FR-P-7.2).
- [ ] Show `LOW_RESOLUTION` warning if returned.

## Acceptance criteria

- [ ] A photo taken on a phone reaches staging and starts an analysis; airplane-mode capture uploads once on reconnect.

## Tests required

- Gateway tests with fake adapter (201, 409, 5xx retry); queue restart test (existing harness).

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
