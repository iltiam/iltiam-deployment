# Doctor: patient list, search/filters, profile and register new patient

> **Plan ID:** MOB-12 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #11 in Mohammad's list
> **Blocked by:** MOB-04
> **Blocks:** MOB-13, MOB-19, MOB-31, MOB-32, MOB-33
> **SRS:** FR-D-2, FR-D-3

## Context

Doctor repositories call `/doctor/patients...`. Backend: `GET/POST /api/patients/`, `GET/PATCH /api/patients/{id}/`,
`GET /api/patients/{id}/wounds/`, visit list per wound (BE-07).

## Steps

- [ ] Map list (search name/ID/phone, risk filter, last-visit range), profile with wounds and visits, register patient (unique Saudi phone error).

## Acceptance criteria

- [ ] Doctor sees only own patients; registration sends the patient OTP (backend).

## Tests required

- Repository + widget tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
