# Arabic/RTL, accessibility and plain-language audit of all new screens

> **Plan ID:** MOB-29 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** S (≈1 day) · **Order:** #26 in Mohammad's list
> **Blocked by:** none
> **Blocks:** none
> **SRS:** NFR-USA-01, NFR-USA-03, NFR-USA-04

## Context

Final audit after all wiring: every string localised, RTL layouts, large text, screen reader labels, error messages
with a corrective action.

## Steps

- [ ] Golden tests EN/AR for each new screen; TalkBack/VoiceOver pass.

## Acceptance criteria

- [ ] No untranslated or truncated strings; first-time patient finishes an upload in < 5 minutes (NFR-USA-01) in a hallway test.

## Tests required

- Golden tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
