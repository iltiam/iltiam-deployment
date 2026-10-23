# Performance fixes from the staging load test

> **Plan ID:** BE-23 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** M (≈2 days) · **Order:** #18 in Mansour's list
> **Blocked by:** DEP-08
> **Blocks:** none
> **SRS:** NFR-PERF-02, NFR-PERF-04, NFR-SCA-01, NFR-SCA-02

## Context

Owned by Mansour (Omar reviews): fix what DEP-08 finds (indexes, N+1 queries, caching, pagination limits).

## Steps

- [ ] Address each failing NFR from the load report.
- [ ] Add query-count tests for the hot endpoints.

## Acceptance criteria

- [ ] Re-run of DEP-08 passes every NFR.

## Tests required

- Query-count tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
