# Production settings hardening, security headers, structured logs, request-id propagation

> **Plan ID:** BE-03 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #7 in Omar's list
> **Blocked by:** BE-04
> **Blocks:** none
> **SRS:** NFR-SEC, NFR-MAI-02

## Context

Prepare `config/settings/production.py` for the internet: strict hosts/CORS/CSRF trusted origins from env, secure
cookies, HSTS handled with the proxy, JSON logs with request id, and propagation of X-Request-ID to the AI service
so one id follows a request across services.

## Steps

- [ ] `ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS`, `CSRF_TRUSTED_ORIGINS` from env; refuse DEBUG/OTP echo/demo seed in production.
- [ ] JSON logging (python-json-logger) with request id, user id (no PII), route, status, duration.
- [ ] Send `X-Request-ID` to the AI client; store the AI request id already (exists).
- [ ] `manage.py check --deploy` clean.

## Acceptance criteria

- [ ] `check --deploy` has no warnings; logs are JSON on staging; one request id is visible in backend and AI logs for an analysis.

## Tests required

- Settings tests (prod refuses dev flags); client test asserts header sent.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
