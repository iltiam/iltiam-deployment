# Patient result screen on the real backend (5 states, tips, overlay, disclaimer)

> **Plan ID:** MOB-08 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #8 in Mohammad's list
> **Blocked by:** MOB-07, BE-39
> **Blocks:** MOB-26, MOB-27
> **SRS:** FR-P-3.1, UC-PT-02

## Context

The app polls `/v1/jobs/{id}` and ResultPayload throws when `risk` is missing (every first visit). Backend
`GET /api/wounds/mine/visits/{id}/` returns `state` READY | UNDER_REVIEW | PROCESSING | RETAKE_NEEDED | UNAVAILABLE,
headline, result (risk level may be null), tips, images {photo_url, outline_url}, disclaimer.

## Steps

- [ ] Poll the visit until a final state; render each state with backend headline/tips/disclaimer (already localised).
- [ ] Overlay `outline_url` on `photo_url` with a toggle; refresh URLs on expiry.
- [ ] Null risk -> "not enough information yet"; WOUND_NOT_FOUND -> retake + doctor-review sentence (BE-39).
- [ ] Saved copy for offline (existing cache).

## Acceptance criteria

- [ ] Each state reproduced on staging with the printed-wound photos; disclaimer always visible.

## Tests required

- Widget tests per state (EN/AR).

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
