# Runbook 2: Cloudflare account, DNS for <DOMAIN>, SSL/TLS and email records

> **Plan ID:** DEP-01 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #5 in Thabit's list
> **Blocked by:** none
> **Blocks:** BE-20, DEP#9
> **SRS:** SRS §17 (TLS 1.3); FR-P-6.1

## Context

Decision: the domain is registered on Cloudflare (name decided later, written `<DOMAIN>` everywhere). Cloudflare
provides DNS, TLS and DDoS protection. Hostnames: `app.<DOMAIN>` (web), `api.<DOMAIN>` (backend; mobile base URL
`https://api.<DOMAIN>/api`), `staging-app.<DOMAIN>`, `staging-api.<DOMAIN>`, `grafana.<DOMAIN>` (protected by
Cloudflare Access), `status.<DOMAIN>` (uptime page). The AI service never gets a hostname. Write it as a runbook a teammate with no cloud experience can follow: numbered steps, exact console menu names, commands to paste, what you should see, and what to do if it fails. Never paste a secret into the runbook.

## Steps

- [ ] Cloudflare account owned by ben-fatah, 2FA on; invite one teammate as Administrator (2FA required).
- [ ] Register `<DOMAIN>` in Cloudflare Registrar; auto-renew and DNSSEC on.
- [ ] SSL/TLS: mode **Full (strict)**; Edge Certificates: Always Use HTTPS on, Minimum TLS 1.2, TLS 1.3 on, Automatic HTTPS Rewrites on; enable HSTS (6 months, include subdomains) only after the site works over HTTPS.
- [ ] For `api.*`: Rocket Loader off and Email Obfuscation off (they rewrite responses).
- [ ] Security: Bot Fight Mode **off** (it blocks mobile API clients); Security Level medium; document "Under Attack" mode as the DDoS switch.
- [ ] Email: add the SMTP provider's SPF, DKIM and DMARC (`p=quarantine`) records for invitations, activation, OTP fallback and breach notices.
- [ ] Write `docs/runbooks/02-cloudflare-dns-tls.md`.

## Acceptance criteria

- [ ] `dig` shows the records; mail-tester score >= 9/10; SSL Labs grade A on `staging-app.<DOMAIN>` once DEP#9 is up.

## Tests required

- Checklist results pasted in the issue.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
