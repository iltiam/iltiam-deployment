# Generated API client from the backend OpenAPI; replace guessed Dio paths

> **Plan ID:** MOB-01 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #1 in Mohammad's list
> **Blocked by:** BE-01
> **Blocks:** MOB-04
> **SRS:** SRS §13.3.1

## Context

With `MOCK_BACKEND=false` the Dio repositories call ~30 paths that do not exist (`/doctor/*`, `/v1/jobs/{id}`,
`/images/upload`, `/care-plans`, `/health`, ...) and the base URL has no `/api`. Generate a typed client from
`iltiam-backend/docs/api/openapi.json` and make every repository use it.

## Steps

- [ ] Generator (openapi-generator `dart-dio` or `swagger_parser`) pinned; `tool/gen_api.dart` downloads the spec for a backend tag.
- [ ] Generated code in `lib/data/api/` (committed or generated in CI, pick one and document).
- [ ] ApiClient: base URL from flavor (MOB-02), `Accept-Language`, auth interceptor with one refresh on 401 SESSION_EXPIRED then sign-out.
- [ ] Error envelope -> domain exceptions with the backend's Arabic/English message and action (NFR-USA-03).
- [ ] Adopt the reusable flutter CI (deployment #1); CI fails if the generated client is stale.

## Acceptance criteria

- [ ] No repository builds a path by hand; `flutter analyze` and tests green.

## Tests required

- Unit tests for the interceptor (refresh once, sign-out on second 401) and error mapping.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
