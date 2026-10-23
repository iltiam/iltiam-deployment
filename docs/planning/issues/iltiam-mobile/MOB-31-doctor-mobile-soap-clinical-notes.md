# Doctor (mobile): SOAP clinical notes

> **Plan ID:** MOB-31 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P2 · **Size:** M (≈2 days) · **Order:** #28 in Ahmed's list
> **Blocked by:** MOB-12
> **Blocks:** none
> **SRS:** FR-D-8

## Context

Built by Ahmed in Flutter (he owns the same feature on the web); Mohammad reviews. Backend: `/api/patients/{id}/notes/`, `/api/notes/{id}/` (draft autosave, sign, addenda, share).

## Steps

- [ ] Notes list, editor with structured fields and tags, sign, addendum, share toggle.

## Acceptance criteria

- [ ] Note signed on mobile is visible and immutable on web.

## Tests required

- Repository + form tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
