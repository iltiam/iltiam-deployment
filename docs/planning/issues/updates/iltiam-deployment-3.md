# Runbook 4: secrets and environment files (GitHub Environments, rotation, third-party keys)

> **Plan ID:** DEP#3 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #4 in Thabit's list
> **Blocked by:** none
> **Blocks:** BE-19, BE-20, DEP#2, DEP#9
> **SRS:** NFR-SEC-04

## Context

Reassigned from Omar to ben-fatah. Keep it simple: secrets live in **GitHub Environments** (`staging`,
`production`; production has required reviewers); the deploy workflow writes `.env` files on the VM
(`/srv/iltiam/env/*.env`, mode 600, owner deploy). Templates live in git without values. Write it as a runbook a teammate with no cloud experience can follow: numbered steps, exact console menu names, commands to paste, what you should see, and what to do if it fails. Never paste a secret into the runbook.

## Steps

- [ ] `env/backend.env.example`, `env/ai.env.example`, `env/web.env.example`, `env/infra.env.example`: every variable with a one-line comment.
- [ ] `scripts/bootstrap-secrets.sh`: prints fresh random values (Django SECRET_KEY, JWT key, FIELD_ENCRYPTION_KEY, AI_SERVICE_TOKEN, DB passwords) to paste into GitHub Environment secrets.
- [ ] Third-party secrets and where they come from: OCI S3 access/secret keys (DEP-02), `CF_TUNNEL_TOKEN` (DEP#9), `AUTHENTICA_API_KEY` + `AUTHENTICA_SENDER_NAME` (DEP-14), `FCM_SERVICE_ACCOUNT_JSON` and `google-services.json` per Android flavor (DEP-13), SMTP credentials (DEP-01), Turnstile secret, GHCR read token, weights read token (AI-07), Android upload keystore (MOB-28a).
- [ ] `docs/secrets.md`: owner, rotation steps and frequency (Vault key yearly; AI token, JWT key, DB passwords on staff change), how to revoke.
- [ ] Write `docs/runbooks/04-secrets.md`.

## Acceptance criteria

- [ ] A new environment can be created from the templates without reading code.
- [ ] gitleaks finds no secret in any repo (DEP-07).

## Tests required

- CI renders env files with dummy values and runs `docker compose config`.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
