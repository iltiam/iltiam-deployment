# Production container: static build on NGINX, runtime config, CSP

> **Plan ID:** WEB-03 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #3 in Ahmed's list
> **Blocked by:** DEP#1
> **Blocks:** WEB-33, DEP#2
> **SRS:** SRS §17 (Web Server), NFR-SEC

## Context

Deployment needs a web image; API base URL must be runtime config (same image for staging and production).

## Steps

- [ ] Multi-stage Dockerfile; nginx serving `dist` with SPA fallback and cache headers.
- [ ] `/config.js` generated from env at container start.
- [ ] CSP and security headers values handed to the proxy (deployment #9).
- [ ] Multi-arch image (`linux/arm64,linux/amd64`); the Vite build runs in the builder stage, nginx serves on arm64.

## Acceptance criteria

- [ ] Same image runs on staging and production with different API URLs.

## Tests required

- Container smoke in CI.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
