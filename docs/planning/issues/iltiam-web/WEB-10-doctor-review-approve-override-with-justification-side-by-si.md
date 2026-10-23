# Doctor: review (approve / override with justification), side-by-side, feedback consent

> **Plan ID:** WEB-10 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #7 in Mansour's list
> **Blocked by:** WEB-09
> **Blocks:** WEB-30, WEB-32
> **SRS:** FR-D-7, UC-DR-02

## Context

Backend `POST /api/wounds/visits/{id}/review/` (action, reason_category, justification, corrected).

## Steps

- [ ] Approve and override forms (reason dropdown + text, corrected area/risk), side-by-side after review.

## Acceptance criteria

- [ ] MANUAL_REVIEW -> COMPLETED with clinician-validated label; patient notified (backend).

## Tests required

- Form tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
