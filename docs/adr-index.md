# ADR index (all repositories)

Every architecture decision record across ILTIAM, in one list. Each repository numbers its own ADRs, so a number is
only unique together with its repository. Smaller decisions are recorded in the issue that made them (each
repository's `docs/issues/` or `issues/` folder), and decisions that differ from the SRS are in
[SRS divergences](srs-divergences.md).

| Repository | ADR | Decision | Status | Date |
|---|---|---|---|---|
| iltiam-deployment | [ADR-0004](adr/0004-hosting.md) | Free-first hosting on Oracle Cloud (Riyadh), Cloudflare edge and Tunnel, phone codes through Authentica, email through OCI Email Delivery | Accepted | 2026-10-27 |
| iltiam-ai-service | [0001](https://github.com/iltiam/iltiam-ai-service/blob/main/docs/adr/0001-segformer-b2.md) | SegFormer-B2 for wound segmentation (ALG-02) | Accepted | 2026-09-16 |
| iltiam-ai-service | [0002](https://github.com/iltiam/iltiam-ai-service/blob/main/docs/adr/0002-aruco-marker.md) | ArUco marker calibration with homography rectification (ALG-01b) | Accepted | 2026-09-21 |
| iltiam-ai-service | [0003](https://github.com/iltiam/iltiam-ai-service/blob/main/docs/adr/0003-django-drf.md) | Django REST Framework for the AI API | Accepted | 2026-09-16 |
| iltiam-ai-service | [0004](https://github.com/iltiam/iltiam-ai-service/blob/main/docs/adr/0004-segmentation-input-size.md) | ALG-02 inference at 348 px, stretched, to match training | Accepted | 2026-09-21 |
| iltiam-ai-service | [0005](https://github.com/iltiam/iltiam-ai-service/blob/main/docs/adr/0005-relative-progression-thresholds.md) | ALG-04 trend on a relative healing rate (%/week) | Accepted | 2026-10-15 |
| iltiam-ai-service | [0006](https://github.com/iltiam/iltiam-ai-service/blob/main/docs/adr/0006-tissue-patch-classifier.md) | Tissue classification on 48 px patches, three classes, MIXED derived (ALG-03) | Accepted | see the ADR |
| iltiam-ai-service | [0007](https://github.com/iltiam/iltiam-ai-service/blob/main/docs/adr/0007-every-wound-in-the-photo.md) | One analysis measures every wound in the photo (post-processing 2.0.0) | Accepted | see the ADR |
| iltiam-ai-service | [0008](https://github.com/iltiam/iltiam-ai-service/blob/main/docs/adr/0008-alg03-acceptance-targets.md) | ALG-03 acceptance targets at wound level | Accepted (pre-registered) | see the ADR |
| iltiam-ai-service | [0009](https://github.com/iltiam/iltiam-ai-service/blob/main/docs/adr/0009-alg03-tissue-segmentation-cv.md) | ALG-03 v0.2.0: per-pixel tissue segmentation, patient-level cross-validation | Accepted (pre-registered) | see the ADR |

The iltiam-ai-service repository is private: its links need repository access. iltiam-backend, iltiam-web and
iltiam-mobile have no ADR files yet; their decisions are in their issue folders.

**Adding an ADR:** write it in the repository it belongs to (iltiam-ai-service has a `docs/adr/template.md`), then add
a row here.
