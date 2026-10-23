# Contract release process: versioned schemas/OpenAPI artifacts and a vendoring script

> **Plan ID:** AI-10 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #7 in Thabit's list
> **Blocked by:** none
> **Blocks:** BE-32
> **SRS:** NFR-MAI-04

## Context

The backend vendors `docs/api/schemas/*` by hand and is 12 additive fields behind HEAD. Make contract versions explicit.

## Steps

- [ ] Tag `contract-vX.Y.Z` when schemas change; attach schemas + openapi.json as release assets.
- [ ] CHANGELOG "Contract" section; `contract` label on PRs touching schemas.
- [ ] `scripts/vendor_contract.py` usable from the backend repo (download, verify, write README commit line).

## Acceptance criteria

- [ ] The backend refreshes its copy with one command (BE-32).

## Tests required

- Unit test of the vendoring script on a local release fixture.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
