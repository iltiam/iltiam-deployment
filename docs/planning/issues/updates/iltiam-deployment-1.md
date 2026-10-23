# Reusable GitHub Actions workflows (python-ci, node-ci, flutter-ci, multi-arch docker build+push to GHCR)

> **Plan ID:** DEP#1 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #3 in Thabit's list
> **Blocked by:** none
> **Blocks:** DEP-07, BE-04, WEB-03, AI-07, DEP-03
> **SRS:** SRS §5.7, §5.8

## Context

Kept and updated. Each app repo calls the same CI building blocks; images go to GHCR. The server is ARM, so every image
must be built for **linux/arm64** (and amd64 for local x86 machines). Building arm64 under QEMU emulation on an x86 runner
is slow (torch); prefer the `ubuntu-24.04-arm` hosted runner, which GitHub's docs now list for private repositories
(it uses the account's free Actions minutes). Fallback: build on the VM itself (free ARM CPU).

## Steps

- [ ] `python-ci.yml`, `node-ci.yml`, `flutter-ci.yml` with `workflow_call` inputs.
- [ ] `docker-publish.yml`: buildx, `platforms` input (default `linux/arm64,linux/amd64`), native arm64 runner when available, registry cache, push `ghcr.io/iltiam/<image>:<sha>` and `:<semver>` on tags, SBOM + provenance.
- [ ] Build images only on merges to `main` and on tags (not on every PR) to save free minutes.
- [ ] Document inputs in `docs/ci.md`; adoption in BE-04, WEB-03, MOB-03, AI-07.

## Acceptance criteria

- [ ] All four app repos push arm64 images to GHCR on merge to main; `docker manifest inspect` shows arm64.

## Tests required

- A self-test job per reusable workflow.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
