# Doctor: review (approve / override with justification) and side-by-side

> **Plan ID:** MOB-16 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #14 in Mohammad's list
> **Blocked by:** MOB-15
> **Blocks:** MOB-27
> **SRS:** FR-D-7, UC-DR-02

## Context

`POST /api/wounds/visits/{id}/review/` (action, reason_category, justification, corrected{...}).

## Steps

- [ ] Approve; override with reason dropdown + free text + corrected values; feedback consent shown.
- [ ] Side-by-side AI vs clinician after review.

## Acceptance criteria

- [ ] A MANUAL_REVIEW visit becomes COMPLETED after review; patient is notified (backend).

## Tests required

- Form validation + repository tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
