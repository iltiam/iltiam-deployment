# System documentation: C4 context/container, integration guide, cross-repo ADR index

> **Plan ID:** DEP#4 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P2 · **Size:** M (≈2 days) · **Order:** #28 in Thabit's list
> **Blocked by:** DEP#2
> **Blocks:** none

## Context

Kept; written from the system as built: C4 diagrams (Mermaid), integration guide (backend<->AI, apps<->backend,
notifications), ADR index across repos.

## Steps

- [ ] Mermaid C4 diagrams
- [ ] `integration.md` with sequence diagrams for upload->analysis->result and review
- [ ] ADR index
- [ ] MkDocs strict build in CI

## Acceptance criteria

- [ ] Diagrams render on GitHub; MkDocs strict build green.

## Tests required

- Docs CI job.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
