# Green CI on main and repo hygiene

> **Plan ID:** WEB-01 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #1 in Ahmed's list
> **Blocked by:** none
> **Blocks:** none

## Context

web-ci has failed on main since 2026-10-19: ESLint `fmtDate` unused (src/pages/public/Landing.tsx:9) and `themeMode`
unused (src/pages/public/Login.tsx:208), so the Playwright job is skipped. The repo root tracks
`node_modules/.package-lock.json`, `node_modules/.vite/...` and an empty `package-lock.json`.

## Steps

- [ ] Fix both lint errors.
- [ ] `git rm --cached` root `node_modules/` and `package-lock.json`; add a root `.gitignore`.
- [ ] Adopt the reusable node CI (deployment #1).

## Acceptance criteria

- [ ] web-ci green on main; clean clone builds.

## Tests required

- CI.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
