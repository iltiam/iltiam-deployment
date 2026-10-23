# Per-request manual-review threshold for FR-D-5 governance

> **Plan ID:** AI-02 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #14 in Thabit's list
> **Blocked by:** none
> **Blocks:** AI-03, BE-11a
> **SRS:** FR-D-5, FR-AI-05

## Context

The Super Admin changes the confidence threshold in the backend (BE-11a). The AI service stays stateless: the backend
sends the active threshold with each analysis; the service validates it, applies it and echoes it in
`decision.manual_review_threshold`. Default stays the per-model value from config.

## Steps

- [ ] AnalyzeRequest: optional `manual_review_threshold` (0 < t < 1); 400 outside the range.
- [ ] Pipeline uses it instead of the per-version default; trace notes the source.
- [ ] Contract docs + release (AI-10).

## Acceptance criteria

- [ ] A request with 0.80 accepts a 0.85-confidence result and flags a 0.79 one; no field = config default.

## Tests required

- Unit + contract tests; golden decision tests unchanged without the field.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
