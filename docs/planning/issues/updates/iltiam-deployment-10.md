# Runbook 7: lightweight monitoring, logs, alerts and uptime (fits the free VM)

> **Plan ID:** DEP#10 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** L (≈3 days) · **Order:** #22 in Thabit's list
> **Blocked by:** DEP#2, BE-27, AI-04
> **Blocks:** AI-06
> **SRS:** NFR-REL-01 (97 %), NFR-MAI-02, SRS §5.6.3

## Context

Free-first (ADR-0004): Oracle **Always Free** in the Riyadh home region: one Ampere A1 (ARM, aarch64) VM with **2 OCPUs and 12 GB** (Oracle's current Always Free A1 allowance), 200 GB block storage in total, 20 GB object storage, software-protected Vault keys. Staging and production share this one VM as separate Compose projects. One monitoring stack for both environments, sized for about 1 GB: Prometheus (7-day retention), Grafana, Loki
(7 days), promtail, node-exporter, cAdvisor. Grafana sits behind Cloudflare Access. OCI's own free Monitoring and
Notifications cover instance state. Write it as a runbook a teammate with no cloud experience can follow: numbered steps, exact console menu names, commands to paste, what you should see, and what to do if it fails. Never paste a secret into the runbook.

## Steps

- [ ] `compose.monitoring.yml` (project `iltiam-monitoring`) with `mem_limit`s; scrape both environments' backend and AI `/metrics` over a shared internal network.
- [ ] Dashboards: per-environment latency p50/p95, upload->result time, AI queue and job time, errors, host memory/CPU/disk, backup age, object-storage used vs 20 GB.
- [ ] Alerts (email + team chat webhook): readiness failing 2 min, 5xx rate, AI job failures, memory > 85 %, disk > 80 %, object storage > 70 % of free, backup older than 26 h, instance stopped/reclaimed (OCI alarm).
- [ ] External uptime probe (free hosted pinger) on `app.` and `api.` health; status page.
- [ ] Write `docs/runbooks/07-monitoring.md`.

## Acceptance criteria

- [ ] Each alert fires in a staged failure on staging.
- [ ] Monitoring uses <= 1.2 GB (`docker stats`).

## Tests required

- `promtool test rules` in CI.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
