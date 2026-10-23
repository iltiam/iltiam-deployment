# Doctor: corrected wound boundary editor (FR-D-7)

> **Plan ID:** WEB-30 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P2 · **Size:** M (≈2 days) · **Order:** #27 in Ahmed's list
> **Blocked by:** WEB-10, BE-29
> **Blocks:** none
> **SRS:** FR-D-7

## Context

Draw/adjust a polygon over the photo starting from the AI mask; backend computes area (BE-29).

## Steps

- [ ] Canvas editor (add/move/delete points), preview of recomputed area from the API, save as part of override.

## Acceptance criteria

- [ ] Corrected boundary saved and shown side-by-side with the AI mask.

## Tests required

- Component tests for the editor model.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
