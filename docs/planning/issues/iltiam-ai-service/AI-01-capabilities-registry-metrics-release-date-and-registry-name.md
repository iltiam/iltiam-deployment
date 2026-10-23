# /capabilities: registry metrics, release date and registry name of the loaded model

> **Plan ID:** AI-01 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #12 in Thabit's list
> **Blocked by:** none
> **Blocks:** BE-10
> **SRS:** FR-SA-8, UC-SA-03

## Context

The backend change request `iltiam-backend/docs/issues/issue-28/ai-change-request.md` was never actioned. RegistryModel
(src/iltiam_ai/schemas/ops.py:39-44) has only name/version/sha256, and `models.segmentation` reports
`name: segformer-b2, version: segformer-b2@2.0.0+postprocess@2.0.0`, which the backend cannot join to the registry
entry `segformer_b2_wound 2.0.0`, so FR-SA-8 shows no Dice/IoU/date.

## Steps

- [ ] `models/registry.yaml`: `released_at` per entry.
- [ ] RegistryEntry/RegistryModel: `metrics`, `released_at`.
- [ ] ModelInfo: `registry_name` from `config.model.registry_name`.
- [ ] Regenerate schemas/openapi; contracts.md note (additive); contract release (AI-10).

## Acceptance criteria

- [ ] `/capabilities` returns val_dice 0.8896, val_iou 0.8177 and released_at for segformer_b2_wound 2.0.0, plus registry_name.

## Tests required

- Contract snapshot test; ops endpoint test.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
