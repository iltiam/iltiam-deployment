# Build flavors and platform config: dev/staging/prod, network security, no mock in production

> **Plan ID:** MOB-02 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #2 in Mohammad's list
> **Blocked by:** none
> **Blocks:** MOB-03, MOB-11, MOB-30, MOB-34
> **SRS:** NFR-POR-01, NFR-SEC

## Context

`MOCK_BACKEND` and `DEMO_MODE` default to true; the main AndroidManifest has no INTERNET permission and no cleartext
rule, so release builds cannot reach any backend.

## Steps

- [ ] Flavors (Android productFlavors / iOS schemes) dev, staging, prod with app id suffixes, names, icons, API base URLs (`https://staging-api.<DOMAIN>/api`, `https://api.<DOMAIN>/api`).
- [ ] INTERNET in the main manifest; cleartext allowed only in the dev flavor (network_security_config) for LAN/10.0.2.2; iOS ATS exceptions only in dev.
- [ ] Prod flavor asserts `MOCK_BACKEND=false` and `DEMO_MODE=false` at startup.
- [ ] Firebase config files per flavor from secrets (not committed), per deployment `docs/third-parties.md`.

## Acceptance criteria

- [ ] Prod build cannot start in mock/demo mode; staging build talks to staging over HTTPS.

## Tests required

- Unit test of the startup guard; CI builds all flavors.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
