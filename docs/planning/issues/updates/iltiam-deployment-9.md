# Runbook 3: Cloudflare Tunnels for staging and production, cache and security rules (no public web ports)

> **Plan ID:** DEP#9 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #8 in Thabit's list
> **Blocked by:** DEP#7, DEP-01, DEP#3
> **Blocks:** none
> **SRS:** SRS §17 (Web Server: NGINX; divergence recorded in DEP-12); NFR-SEC

## Context

Decision (ADR-0004): **Cloudflare Tunnel** instead of our own reverse proxy (free). One tunnel per environment, each a
`cloudflared` container in its Compose project, connecting **outbound**: no web ports, no certificates on the VM.
Staging: `staging-app.<DOMAIN>`, `staging-api.<DOMAIN>`; production: `app.<DOMAIN>`, `api.<DOMAIN>`. Nothing routes to
the AI service. Cloudflare must NOT cache API responses or health data, and photos/PDFs never pass through it (clients
download them by presigned OCI URLs). Uploads (<= 25 MB) are under the Free plan's 100 MB limit. Reassigned from Omar
to ben-fatah. Write it as a runbook a teammate with no cloud experience can follow: numbered steps, exact console menu names, commands to paste, what you should see, and what to do if it fails. Never paste a secret into the runbook.

## Steps

- [ ] Zero Trust -> Networks -> Tunnels: create `iltiam-staging` and `iltiam-prod`; tokens to the GitHub Environment secrets `CF_TUNNEL_TOKEN` (staging / production).
- [ ] Public hostnames per tunnel -> `http://web:8080` and `http://backend-web:8000` inside that project; catch-all 404.
- [ ] Cache Rules: bypass for `api.*` and `staging-api.*` (all paths); `app.*`: cache only `/assets/*`; bypass `/index.html`, `/config.js`.
- [ ] WAF: the Free-plan rate-limiting rule on `/api/auth/*`; Bot Fight Mode off; Rocket Loader and Email Obfuscation off on API hosts.
- [ ] Cloudflare Access (free) in front of `grafana.<DOMAIN>` and, optionally, the staging hosts.
- [ ] PDPL note for DEP#6: Cloudflare terminates TLS at its edge (in-Kingdom-only decryption needs the paid Data Localization Suite).
- [ ] Write `docs/runbooks/03-cloudflare-tunnel.md`.

## Acceptance criteria

- [ ] All four hostnames answer over HTTPS; a port scan of the VM shows only 22.
- [ ] API responses are never cached (`cf-cache-status` DYNAMIC/BYPASS).
- [ ] No hostname reaches the AI service.

## Tests required

- DEP-10 smoke checks headers, cache status and the upload limit.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
