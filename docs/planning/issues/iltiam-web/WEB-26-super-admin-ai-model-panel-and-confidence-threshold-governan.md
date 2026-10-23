# Super Admin: AI model panel and confidence-threshold governance

> **Plan ID:** WEB-26 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** M (≈2 days) · **Order:** #23 in Ahmed's list
> **Blocked by:** BE-10, BE-11a, BE-11b
> **Blocks:** none
> **SRS:** FR-SA-8, FR-D-5, UC-SA-03

## Context

Backend: `/api/ai/model/`, `/versions/`, threshold endpoints (BE-11a/b) with step-up OTP and 40 % floor confirmation.
Tissue row per backend #56 ("experimental, off" / "not reported").

## Steps

- [ ] Panel: version, deployment date, Dice, IoU, classification accuracy or "not reported", override rate, history.
- [ ] Threshold change: step-up OTP, second confirmation below 40 %, history with re-evaluation reports.

## Acceptance criteria

- [ ] Full SA changes the threshold; Read-only SA sees it only; audit visible in WEB-27.

## Tests required

- Component tests incl. floor confirmation.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
