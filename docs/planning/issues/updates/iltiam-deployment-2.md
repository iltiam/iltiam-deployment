# Runbook 5: staging and production as two Compose projects on one ARM VM (memory budget, private AI)

> **Plan ID:** DEP#2 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** L (≈3 days) · **Order:** #13 in Thabit's list
> **Blocked by:** DEP#7, DEP#3, AI-12, BE-04, BE-02, WEB-03, AI-07
> **Blocks:** DEP#5, DEP#4, DEP#8, DEP#10, DEP-03
> **SRS:** SRS §17; NFR-AVA-01

## Context

Free-first (ADR-0004): Oracle **Always Free** in the Riyadh home region: one Ampere A1 (ARM, aarch64) VM with **2 OCPUs and 12 GB** (Oracle's current Always Free A1 allowance), 200 GB block storage in total, 20 GB object storage, software-protected Vault keys. Staging and production share this one VM as separate Compose projects. Reassigned from Omar to ben-fatah. Two Compose projects, `iltiam-staging` and `iltiam-prod`, from the same
`compose.yml` with per-environment env files: each has its own cloudflared (own tunnel and hostnames), web, backend
web/worker/beat, AI api/worker (+ beat), Postgres (own volume and databases `iltiam`, `iltiam_ai`) and Redis. Nothing is
shared except the read-only weights volume and the monitoring stack. Split to a second VM only when the triggers in
ADR-0004 fire. Write it as a runbook a teammate with no cloud experience can follow: numbered steps, exact console menu names, commands to paste, what you should see, and what to do if it fails. Never paste a secret into the runbook.

## Steps

- [ ] Memory budget (12 GB + 4 GB swap), per environment: AI api 1 gunicorn worker (~1.2 GB), AI worker concurrency 1 (~1.3 GB), backend web 2 workers (~0.4 GB), backend worker + beat (~0.4 GB), Postgres (~0.3 GB, `shared_buffers=128MB`), Redis (~0.1 GB, `maxmemory 128mb`), web nginx + cloudflared (~0.1 GB): about **3.8 GB**. Two environments ≈ 7.6 GB, monitoring ≈ 1 GB, OS ≈ 0.5 GB: **≈ 9 GB of 12**. Set `mem_limit` on every service.
- [ ] Production first: when memory is short, stop the staging AI worker (`docker compose -p iltiam-staging stop ai-worker`), never production's.
- [ ] Healthchecks (backend `/api/health/`, AI `/ready`, pg_isready, redis ping), `depends_on: service_healthy`, `restart: unless-stopped`; AI api command overridden to 1 worker (AI-07).
- [ ] Networks per project: `edge` (cloudflared, web, backend web) and `internal`; no host `ports:`; the AI service is unreachable outside its project.
- [ ] Data: `/srv/iltiam/<env>/{postgres,redis}`; image tags in `env/<env>.versions`; `scripts/deploy.sh <env>`: pull (arm64), migrate job, `up -d --wait`, print versions.
- [ ] Write `docs/runbooks/05-compose-stack.md` (logs, restart one service, roll back a tag, check memory with `docker stats`).

## Acceptance criteria

- [ ] Both projects healthy on `iltiam-1` at the same time; `docker stats` total under 10 GB at idle.
- [ ] Restarting or breaking staging does not affect production.
- [ ] Re-running a deploy with the same tags changes nothing.

## Tests required

- `docker compose config` per environment in CI; post-deploy smoke (DEP-10).

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
