# Security scanning in CI: images, dependencies, secrets, DAST baseline

> **Plan ID:** DEP-07 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #10 in Ahmed's list
> **Blocked by:** DEP#1, DEP-03
> **Blocks:** BE-24
> **SRS:** SRS §5.8 (OWASP ZAP), NFR-SEC

## Context

Owned by Ahmed; ben-fatah reviews. Scanning in the reusable workflows and a weekly DAST run against staging.

## Steps

- [ ] Trivy image scan (fail on CRITICAL with a fix) in `docker-publish.yml`.
- [ ] pip-audit (backend, AI), npm audit (web), `dart pub outdated` report (mobile); Dependabot in each repo.
- [ ] gitleaks on every PR in all repos.
- [ ] OWASP ZAP baseline against `staging-app.<DOMAIN>` and `staging-api.<DOMAIN>` weekly; findings filed to owners.
- [ ] Scan the arm64 image variants too.

## Acceptance criteria

- [ ] All five repos run secret scanning on PRs.
- [ ] First ZAP report triaged; no unresolved High.

## Tests required

- Workflows green.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
