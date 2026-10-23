# Observability: Prometheus /metrics, JSON logs, job timing histograms

> **Plan ID:** AI-04 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #15 in Thabit's list
> **Blocked by:** AI-07
> **Blocks:** AI-06, DEP#10
> **SRS:** NFR-REL-01, NFR-REL-03, SRS §5.6.3

## Context

Monitoring (DEP#10) needs AI metrics: request rates, per-stage durations, queue wait, failures by reason, decision mix.

## Steps

- [ ] `/metrics` on the api (internal network only) and a worker exporter.
- [ ] Histograms: job time, per-stage time (ALG-01..05), queue wait; counters: decisions by status, failures by error prefix.
- [ ] `AI_LOG_FORMAT=json` keeping request_id.

## Acceptance criteria

- [ ] Grafana shows p95 job time and decision mix on staging.

## Tests required

- Metric registration unit tests; integration test scrapes /metrics.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
