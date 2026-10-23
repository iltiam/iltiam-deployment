# Load and performance tests (NFR-PERF, NFR-SCA) without hurting production on the shared VM

> **Plan ID:** DEP-08 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #17 in Mansour's list
> **Blocked by:** DEP-03
> **Blocks:** BE-23, DEP-11
> **Do after:** all P0/P1 v1.0 issues in iltiam-backend (load test the finished API)
> **SRS:** NFR-PERF-01, NFR-PERF-02, NFR-PERF-03, NFR-PERF-04, NFR-SCA-01, NFR-SCA-02

## Context

Owned by Mansour; ben-fatah reviews. Staging and production share one 2-OCPU VM, so load tests run **before production has
real users** (or in an agreed quiet window with the staging AI worker the only one under load). Use the backend Locust
harness (`iltiam-backend/loadtest/`) against staging.

## Steps

- [ ] Seed staging with 500 patients and 60,000 image records (metadata; a sample of real files within the free storage).
- [ ] Scenarios: 50 clinicians (< 3 s per page), analysis end to end (< 10 s, target 4 s), 10 MB upload on a 4G-shaped link (< 5 s), progression with 50 records (< 5 s).
- [ ] Watch production health during the run; stop at the first production alert.
- [ ] Report p50/p95 and bottlenecks; file issues to owners.

## Acceptance criteria

- [ ] Report in `docs/perf/` with pass/fail per NFR; no production alert during the run.

## Tests required

- Locust/k6 scripts runnable manually.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
