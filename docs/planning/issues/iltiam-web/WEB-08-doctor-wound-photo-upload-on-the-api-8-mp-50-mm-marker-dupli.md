# Doctor: wound photo upload on the API (8 MP, 50 mm marker, duplicate confirm, queue position)

> **Plan ID:** WEB-08 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #2 in Mansour's list
> **Blocked by:** WEB-02
> **Blocks:** none
> **SRS:** FR-D-4, UC-DR-01

## Context

Backend: `POST /api/wounds/upload/` (patient_id, image, anatomical_location, marker_confirmed, clinical_notes,
confirm_duplicate) -> 201 {visit, warnings}; 409 DUPLICATE_SUBMISSION. UI text says "1 cm reference marker"; the real
marker is a printed 50 mm ArUco square (DICT_4X4_50 id 7).

## Steps

- [ ] Wire the form; keep the 8 MP and type checks; 409 -> confirm dialog -> resend.
- [ ] Fix marker texts (AR/EN) and link to the printable marker PDF.
- [ ] After upload, go to the visit page with queue position.

## Acceptance criteria

- [ ] Upload on staging starts an analysis; duplicate flow works.

## Tests required

- Component tests incl. 409.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
