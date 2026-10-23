# Existing open issues: keep, update or close

Read on 2026-10-23 with `gh issue list --state all`. Only two repos have open issues. iltiam-ai-service, iltiam-web and iltiam-mobile have none.

| Repo | # | Title today | Assignee today | Decision | New title / what changes | Milestone |
|---|---|---|---|---|---|---|
| backend | 55 | Send segmentation_version (ai-service #105) | Omar | **keep** | Body untouched (Omar finishes it 24 Oct); milestone set. | v1.0 |
| backend | 56 | A missed ALG-03 target disables ALG-03, not submissions | Omar | **keep** | Body untouched; the panel's tissue row (BE-10, WEB-26) follows it. | v1.0 |
| backend | 57 | Keep model_checksums / runtime_versions from failed jobs | — | **keep** | Body untouched. The full schema refresh and real fixtures are the follow-up BE-32. | v1.0 |
| deployment | 1 | Reusable GitHub Actions workflows | ben-fatah | **update** | Adds a multi-arch (linux/arm64 + amd64) docker publish to GHCR (SHA + semver, SBOM), versioned `@v1`. | v1.0 |
| deployment | 2 | compose/dev full stack | Omar → **ben-fatah** | **update** | "Runbook 5: staging and production as two Compose projects on one ARM VM": memory budget for 12 GB, private AI network, healthchecks, deploy script. The local stack moves to #5. | v1.0 |
| deployment | 3 | Env templates, secrets, bootstrap.sh | Omar → **ben-fatah** | **update** | "Runbook 4: secrets and environment files": GitHub Environments; the third-party keys (OCI, Cloudflare tunnel, Authentica, Firebase, SMTP, GHCR, weights, Play upload key). | v1.0 |
| deployment | 4 | System docs: C4, integration.md, ADRs | ben-fatah | **update** | Written from the system as built; last in Thabit's list (P2). | v1.0 |
| deployment | 5 | Demo laptop runbook | ben-fatah | **update (re-scope)** | "Local full-stack development environment": one command, seed, reset under 1 minute. | v1.0 |
| deployment | 6 | Security docs: PDPL mapping, threat model, retention, incident response | ben-fatah | **update** | ROPA (incl. Cloudflare, Authentica, FCM as processors), retention schedule (drives BE-22), consent texts, Play data-safety answers. The threat model and incident response move to DEP-09. | v1.0 |
| deployment | 7 | Staging deployment workflow and hosting decision | Omar → **ben-fatah** | **update** | "Runbook 1: Oracle Always Free account (Riyadh), $10 budget alert, one Ampere A1 VM with Docker", plus committing ADR-0004. The CD workflow moves to DEP-03. | v1.0 |
| deployment | 8 | Backup and restore scripts | Omar → **ben-fatah** | **update** | "Runbook 6: free backups and a weekly tested restore on the VM": within the 20 GB / 5-backup free limits; the restore test runs on the VM, not on GitHub. | v1.0 |
| deployment | 9 | Production reverse proxy: TLS, routing, rate limits | Omar → **ben-fatah** | **update** | "Runbook 3: Cloudflare Tunnels for staging and production, cache and security rules": no public web ports; one tunnel per environment; cache bypass for the API; the AI service unroutable. | v1.0 |
| deployment | 10 | Monitoring stack | ben-fatah | **update** | "Runbook 7: lightweight monitoring, logs, alerts and uptime" (about 1 GB on the free VM; Grafana behind Cloudflare Access). | v1.0 |

**Close as superseded: none.** Every open issue is kept or rewritten in place, so links and history survive. No new issue duplicates one of them.

**What the script changes on the deployment issues:**
- Removes `hackathon` from #1–#5.
- Replaces any superseded `priority:*` label.
- Removes Omar-Nasri as assignee from #2, #3, #7, #8 and #9.
- Sets milestone v1.0.

An optional, commented block closes the old milestones v0.1.0–v0.4.0.
