# Generated API client from the backend OpenAPI, data layer, mocks only in tests

> **Plan ID:** WEB-02 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #2 in Ahmed's list
> **Blocked by:** BE-01
> **Blocks:** WEB-04, WEB-06, WEB-08, WEB-11, WEB-13, WEB-09, WEB-12
> **SRS:** SRS §13.3.1

## Context

Every page reads the in-memory mock store (src/lib/store.tsx:2, mock data at :47-60); `src/api` is imported by no page,
and `web/openapi/iltiam-backend.openapi.json` is a hand-kept mirror with 8 of 89 paths and a wrong login shape.
Production builds must contain no mock.

## Steps

- [ ] `gen:api` from `iltiam-backend/docs/api/openapi.json` (pinned tag); delete the mirror; CI fails on stale types.
- [ ] Data layer (TanStack Query) with typed hooks per resource; error envelope -> UI messages (AR/EN from backend).
- [ ] MSW handlers generated/handwritten for unit tests and Storybook only; `src/lib/mock.ts` excluded from production bundle (build check).
- [ ] Vite dev proxy `/api` -> backend; `web/.env.example` (`VITE_API_URL`).

## Acceptance criteria

- [ ] `npm run build` contains no mock module (bundle check); pages can migrate one by one.

## Tests required

- Vitest for the client middleware (refresh once, session expiry) and error mapping.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
