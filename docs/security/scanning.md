# Security scanning

How ILTIAM's code, dependencies, images and running stack are scanned, on a laptop (issue #18, SRS section 5.8,
NFR-SEC). GitHub Actions is turned off for the organisation, so the scans the issue planned as workflow jobs run from
one script instead: [`scripts/security-scan.sh`](https://github.com/iltiam/iltiam-deployment/blob/main/scripts/security-scan.sh).

## 1. What runs

| Scan | Tool (pinned Docker image) | Over | Fails the run when |
|---|---|---|---|
| `secrets` | gitleaks 8.30.1 | The full git history of all five repositories, redacted | Any finding not in the repository's `.gitleaksignore` or `security/gitleaks-accepted.txt` |
| `images` | Trivy 0.67.2 | The backend, web, AI api and AI worker images the local stack runs (`.dev/images.env`, else staging's tags) | A CRITICAL vulnerability that has a fixed version |
| `images --platform linux/arm64` | Trivy | The same tags' arm64 variants from GHCR (what the VM runs) | Same |
| `deps` | pip-audit 2.10.0 | The exact Python packages inside the backend and AI images (`pip list` from the image) | Any known vulnerability |
| | npm audit (Node 22) | iltiam-web's runtime dependencies (`--omit=dev`); dev tools reported | High or critical in runtime dependencies |
| | osv-scanner 2.2.4 | iltiam-mobile's `pubspec.lock` | Any known vulnerability |
| | `flutter pub outdated` | iltiam-mobile | Never: a report for the owner |
| `dast` | OWASP ZAP 2.16.1 baseline | The **local** stack only: the web app (spider + passive rules) and the API from its own OpenAPI document in safe mode (`-S`, no attack payloads) | A High alert |

The DAST scan joins the `iltiam-dev` Compose network and targets `http://web:8080` and `http://backend-web:8000`.
There is no option to give it another address: **never scan staging or production** (they share one small VM with the
supervisor demo, and Cloudflare would treat it as an attack). It sends unauthenticated requests to every API
operation, so afterwards run `scripts/dev.sh reset` if you want clean demo data.

## 2. How to run it

Needs Docker and the sibling clones (`SCAN_SRC_ROOT`, default `..`). For `images` and `dast`, start the local stack
first ([local development](../dev-environment.md)).

```bash
scripts/dev.sh up                         # the stack the image scan and DAST use
scripts/security-scan.sh                  # everything (about 8 minutes the first time, Trivy downloads its database)
scripts/security-scan.sh secrets deps     # only some scans
scripts/security-scan.sh images --platform linux/arm64   # the VM's variants; needs docker login ghcr.io
```

It ends with a table (PASS, FAIL, SKIPPED per scan) and exits 1 if any gate fails. Reports go to
`security-reports/<date>/` (JSON and the ZAP HTML reports). That folder is gitignored: reports name versions and
weaknesses, and this repository is public. Never paste a report into a public issue; issues say which package and
which version fixes it, nothing more.

**When:** every Monday (the weekly run the issue asked for), before every image is published
(`scripts/publish-image.sh`, AGENTS.md "Deploying staging" step 1), and before go-live (#23). The owner of each
repository fixes its findings.

## 3. Triage

| Finding | Owner | What to do |
|---|---|---|
| A secret | Whoever committed it | Rotate it first ([secrets, section 7](../secrets.md)); then remove it. A false positive goes in `security/gitleaks-accepted.txt` with its reason |
| An image CVE with a fix | The repository's owner | Bump the base image or `apk`/`apt` upgrade in its Dockerfile, rebuild, publish, deploy |
| A Python, npm or pub vulnerability | The repository's owner | Upgrade within the allowed range; if it cannot be fixed yet, accept it (section 4) |
| A ZAP High or Medium | The repository's owner | Fix (usually a header) or accept with the reason |

## 4. Accepting a finding

Only when it does not apply or cannot be fixed yet. Add a line, in a reviewed PR:

- `security/accepted.txt`: `<CVE, PYSEC or GHSA id>  # package, why, Thabit, look again on <date>` (Trivy and
  pip-audit read it).
- `security/gitleaks-accepted.txt`: `<repository> <gitleaks fingerprint>  # why it is not a secret`.

## 5. First run, 2026-11-21

Run on Windows 11 with Docker Desktop 29.8.0, against the local stack (backend built from iltiam-backend `main`; web
`sha-aa7deb6` and AI `sha-a11a24d`, the tags staging runs).

| Scan | Result | Findings |
|---|---|---|
| secrets | PASS after triage | 5 gitleaks hits, all test fixtures (idempotency-key UUIDs and a test string in iltiam-backend and iltiam-mobile tests), accepted in `security/gitleaks-accepted.txt` |
| images | **FAIL** | **Web image `sha-aa7deb6`: 5 CRITICAL with a fix** (nginx 1.30.6 → 1.30.7, brotli-libs 1.2.0 → 1.2.1, from the `nginxinc/nginx-unprivileged:1.30.6-alpine` base). Backend 0, AI api 0, AI worker 0 critical. HIGH, all OS packages of the Debian or Alpine base (util-linux, ncurses, openssl, libexpat ...): backend 56, AI 53 each, web 15 |
| deps | **FAIL** | AI image: `pip` 24.0 (6 advisories, fixed in 26.2) and `setuptools` 79.0.1 (2 advisories, fixed in 84.1.0), build tools left in the runtime image. Backend: none. Web: 0 high or critical in runtime dependencies; 12 in dev tools (5 high, all through `@lhci/cli`'s proxy chain). Mobile: none in 178 packages; `flutter pub outdated` report for the owner |
| dast | PASS | Web: 0 High, 0 Medium. API: 0 High, 1 Medium: no `Content-Security-Policy` header on API responses (12 URLs); Lows: no `Permissions-Policy`, Spectre site isolation headers |
| arm64 images | not run | Needs `docker login ghcr.io`; same tags, other architecture |

Findings for the owners (to file in each repository, without the report contents):

1. **iltiam-web:** bump the runtime base to nginx 1.30.7 (or `apk upgrade` in the image), rebuild, publish, deploy to
   staging. Then run `images` again.
2. **iltiam-ai-service:** upgrade or remove `pip` and `setuptools` in the runtime stage of the Dockerfile.
3. **iltiam-backend:** add `Content-Security-Policy: default-src 'none'; frame-ancestors 'none'` (and
   `Permissions-Policy`) to API responses; `/api/docs/` needs its own policy for Swagger UI.
4. **iltiam-web:** update `@lhci/cli` (dev only, no runtime impact).

## 6. What is not covered here

- **Dependabot:** its alerts come from GitHub's dependency graph and need no Actions; its update pull requests run
  on Actions runners, which are off for the organisation. Turning alerts on in each repository is a manual step
  on #18 (Settings → Code security).
- **Authenticated DAST** (a ZAP context signed in as a doctor) and an active scan: later, on the local stack only.
