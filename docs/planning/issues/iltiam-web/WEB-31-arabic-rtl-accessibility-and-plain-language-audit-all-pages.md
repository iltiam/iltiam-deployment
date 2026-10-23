# Arabic/RTL, accessibility and plain-language audit (all pages)

> **Plan ID:** WEB-31 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** M (≈2 days) · **Order:** #19 in Mansour's list
> **Blocked by:** none
> **Blocks:** none
> **SRS:** NFR-USA-03, NFR-USA-04 (web equivalent), Test cases L

## Context

Final audit after wiring: every string through i18n, RTL layouts, error messages with corrective action,
Lighthouse accessibility >= 90.

## Steps

- [ ] Missing-key report (CI), RTL screenshots, axe/Lighthouse on key pages.

## Acceptance criteria

- [ ] No missing keys; Lighthouse a11y >= 90 on dashboard, patient profile, result, admin pages.

## Tests required

- CI missing-key check; Lighthouse CI.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
