# Backend metrics endpoint (django-prometheus, Celery queue metrics)

> **Plan ID:** BE-27 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #8 in Ahmed's list
> **Blocked by:** none
> **Blocks:** DEP#10
> **SRS:** NFR-REL-01, NFR-PERF-02

## Context

Owned by Ahmed (Omar reviews). Needed by deployment #10 dashboards.

## Steps

- [ ] django-prometheus middleware + DB metrics; `/metrics` only on the internal network.
- [ ] Celery queue depth and task duration (exporter or custom collector).

## Acceptance criteria

- [ ] Grafana shows request rate/latency and queue depth on staging.

## Tests required

- Test that /metrics is not routed publicly (proxy rule) and returns metrics.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
