# Threshold re-evaluation report from stored validation predictions

> **Plan ID:** AI-03 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #17 in Thabit's list
> **Blocked by:** AI-02
> **Blocks:** BE-11b
> **SRS:** FR-D-5 (c) re-evaluation report within 24 h

## Context

FR-D-5 needs a re-evaluation report within 24 h of a threshold change. Store the clean **validation** split's
per-image confidence and Dice once (never the held-out test split) and compute, for any threshold, the share flagged
and the Dice of accepted vs flagged images.

## Steps

- [ ] Script producing `data/calibration/val_predictions.csv` for the shipped model (clean val only).
- [ ] `POST /v1/threshold-report {threshold}` -> flagged %, mean Dice accepted/flagged, ROC point, model version.
- [ ] Backend stores and shows it (BE-11b).

## Acceptance criteria

- [ ] Report for 0.94 reproduces the calibration in `docs/benchmarks/segmentation_v2.md`.

## Tests required

- Unit tests on a CSV fixture; contract test.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
