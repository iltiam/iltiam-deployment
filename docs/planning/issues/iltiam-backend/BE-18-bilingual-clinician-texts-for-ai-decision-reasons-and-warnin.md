# Bilingual clinician texts for AI decision reasons and warnings

> **Plan ID:** BE-18 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P2 · **Size:** S (≈1 day) · **Order:** #29 in Omar's list
> **Blocked by:** BE#55
> **Blocks:** none
> **SRS:** NFR-USA-03, NFR-USA-04

## Context

Reason codes and AI warnings reach doctors in English only; `result.progression.warnings` (SEGMENTATION_MODEL_CHANGED)
should be stored and shown (#55 adds it).

## Steps

- [ ] Catalogue (ar/en) for the 10 Reason codes and known warning prefixes.
- [ ] Return `{code, text}` alongside codes in VisitDetail.

## Acceptance criteria

- [ ] Accept-Language ar returns Arabic text for every reason and known warning.

## Tests required

- Catalogue completeness test against the vendored Reason enum.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
