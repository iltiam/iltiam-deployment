# Wound images: strip EXIF (GPS) and normalise orientation on upload

> **Plan ID:** BE-08 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #14 in Omar's list
> **Blocked by:** none
> **Blocks:** none
> **SRS:** FR-P-7.1 (PDPL), FR-D-4

## Context

Wound photos are stored with their EXIF (phones add GPS location and device data); profile photos already strip it.
Orientation should be applied once so the AI mask and the displayed photo always align.

## Steps

- [ ] On upload: apply EXIF orientation, drop all EXIF, keep ICC profile; store the normalised image (the AI receives the same bytes).
- [ ] Record original dimensions/orientation in metadata.

## Acceptance criteria

- [ ] A rotated phone photo with GPS uploads, shows upright, has no EXIF, and its mask overlays correctly.

## Tests required

- Image-processing tests with rotated + GPS fixtures.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
