# Sync vendored AI contract to the released version and use realistic fixtures

> **Plan ID:** BE-32 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #10 in Omar's list
> **Blocked by:** AI-10, BE#55, BE#57
> **Blocks:** BE-10
> **SRS:** NFR-MAI-04

## Context

The vendored schemas are at ai-service `3f2bb54`; HEAD adds 12 additive fields (include_overlay, segmentation_version,
region_count, segmentation_versions, n_unknown_segmentation_version, torchvision, overlay_png_b64, job
model_checksums/runtime_versions). `fixtures/capabilities.json` is invented (version "1.0.0", "sha256:" prefix).

## Steps

- [ ] Refresh all 11 schemas with the AI vendoring script (AI-10); update the README commit/tag.
- [ ] Replace fixtures with captures from a real AI run (staging), including FAILED with provenance.
- [ ] Contract tests stay green.

## Acceptance criteria

- [ ] Vendored schemas equal the AI contract release; fixtures validate and look like real responses.

## Tests required

- Existing contract tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
