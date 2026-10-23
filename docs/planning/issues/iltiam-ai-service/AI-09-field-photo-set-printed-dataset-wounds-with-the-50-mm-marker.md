# Field photo set: printed dataset wounds with the 50 mm marker photographed by phones

> **Plan ID:** AI-09 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** S (≈1 day) · **Order:** #21 in Thabit's list
> **Blocked by:** none
> **Blocks:** none
> **SRS:** FR-D-4, FR-P-2.1, NFR-ACC-01

## Context

Decision: test photos are printed dataset wounds with a printed 50 mm ArUco marker, photographed with a phone. Use
TRAINING or clean VALIDATION images only, never the held-out test split. A 2-hour team session: print at known scale
so the true area is known, photograph with 2-3 Android phones under varied light.

## Steps

- [ ] Pick 20 wounds (train/val only) across sizes; print at known scale with the marker sheet.
- [ ] Capture with the Android app (>= 8 MP), several angles and lights; record true areas.
- [ ] Report area error, decision mix, failure reasons; publish the set as a private release for DEP-10 and QA.

## Acceptance criteria

- [ ] Report in `docs/benchmarks/field_printed.md`; photo set released.

## Tests required

- Script that recomputes the report from the release.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
