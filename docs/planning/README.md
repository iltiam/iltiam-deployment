# ILTIAM v1.0: plan and issue set (index)

Read-only planning output (2026-10-23, revised free-first the same day). Nothing was created or changed in any repo or on GitHub, and the script was not run.

**Free-first revision:** the issues rewritten for the free plan are listed in `tools/data_free.py` (the REPLACED set, plus small patches to BE-04, WEB-03, DEP#6 and DEP-07).

| File | What |
|---|---|
| `plan.md` | Rules, the ordering and priority rules, Ahmed's Flutter help, the two fixed clocks, **per-person ordered lists**, the P0 chain, the **cross-repo dependency graph** (Mermaid) and every cross-repo edge. |
| `issue_index.md` | All 142 items by owner and order: repo, priority, size, milestone, blocked by, blocks, action. |
| `issues/<repo>/<ID>-<slug>.md` | 129 new issue bodies: owner, reviewer, milestone, priority, size, order, blocked-by/blocks, SRS refs, context, steps, acceptance criteria, tests, definition of done. |
| `issues/updates/iltiam-deployment-<n>.md` | New bodies for deployment #1–#10 (runbooks). |
| `issues/create-issues.ps1` | Creates milestones **v1.0** (due 2026-11-30) and **v1.1** in all five repos, then creates new issues and updates existing ones in dependency order, then rewrites plan IDs into cross-repo links. Supports `-DryRun`; re-runnable through `created-map.json`. |
| `adr-0004-hosting.md` | **Free-first** hosting: Oracle Always Free Ampere A1 (ARM) in Riyadh, one VM for staging + production, the $10 budget alert, the ARM package and image check, Cloudflare Tunnel, phone codes (Authentica), and the **cost table** (free, paid fallbacks, one-time), with cited sources. |
| `gap-list.md` | Every use case, FR and NFR of the SRS: status per layer and the issues that close it. |
| `existing-issues.md` | Keep backend #55, #56, #57; update deployment #1–#10; close none. |
| `tools/` | Data files + `generate.py`. Edit the data, then run `python -I -X utf8 tools/generate.py`; it rebuilds `issues/`, `issue_index.md` and `plan.md`. |
| `project-audit.md` | The first audit (superseded by the files above; kept for reference). |

**Milestones:**
- **v1.0:** 139 issues.
- **v1.1:** 3 issues, the iOS work (MOB-34 builds/TestFlight, MOB-35 iOS push, MOB-36 App Store).

**Issues per person:**

| Person | Issues | Of which |
|---|---|---|
| Thabit | 28 | 10 updated + 18 new |
| Omar | 29 | 3 kept + 26 new |
| Mohammad | 32 | |
| Mansour | 23 | |
| Ahmed | 30 | includes 5 Flutter issues |
