# Load and performance tests

How ILTIAM's performance requirements are measured without hurting the shared VM (issue #22; SRS NFR-PERF-01 to 04,
NFR-SCA-01 and 02). Staging and production share one 2-OCPU Ampere VM, which also runs the supervisor demo, so the full
tests run **on a laptop, against the local stack** ([local development](../dev-environment.md)). Staging only ever
gets the small read-only run of section 5, by hand, in a quiet window.

Results: [2026-11-23, local stack](2026-11-23-local.md).

## 1. What is measured

| Scenario | SRS | Load | Pass |
|---|---|---|---|
| `clinicians` | NFR-PERF-02, NFR-SCA-01/02 | 50 doctors browse for 3 minutes (patient list and record, wounds, visits, a visit, dashboard, needs attention, alerts, appointments, inbox), 1 to 3 s between pages, against 500 patients and 60,000 image records | Each page's API call p95 < 3 s; < 1 % failed; no 5xx |
| (same run) | NFR-PERF-04 | The progression of a wound with 50 analysed records, once per round | p95 < 5 s |
| `upload` | NFR-PERF-03 | 5 patients upload a 9.9 MB, 8.3-megapixel JPEG (random pixels: the worst case for compression) through a 4G-shaped link: 20 Mbit/s up by default, 40 ms latency (toxiproxy) | p95 < 5 s |
| `analysis` | NFR-PERF-01 | A patient upload every 5 s for 2 minutes; time from the start of the upload to a final result the patient sees | p95 < 10 s (target 4 s) |

Each page is one API call here; the web app makes one to three calls per screen, in parallel.

## 2. How it works

- [`scripts/loadtest.sh`](https://github.com/iltiam/iltiam-deployment/blob/main/scripts/loadtest.sh) runs
  [k6](https://k6.io) 1.3.0 ([`loadtest/k6/iltiam.js`](https://github.com/iltiam/iltiam-deployment/blob/main/loadtest/k6/iltiam.js))
  and toxiproxy 2.12.0 as containers **on the `iltiam-dev` Compose network**, targeting the service names. It has no
  option for another address.
- **Data:** `seed` runs iltiam-backend's `seed_load_test` (50 doctors, 500 patients, 4,000 visits, one 50-visit wound
  per doctor) and then [`loadtest/seed_bulk.py`](https://github.com/iltiam/iltiam-deployment/blob/main/loadtest/seed_bulk.py),
  which adds completed visits (metadata, no files) up to 60,000, spread over two years. About 70 s.
- **Sign-in:** the load-test accounts are outside the reserved numbers whose codes the staging settings echo, and each
  account may get 5 codes an hour, so [`loadtest/mint_tokens.py`](https://github.com/iltiam/iltiam-deployment/blob/main/loadtest/mint_tokens.py)
  opens a real session per user the way a sign-in does. Tokens live 15 minutes; the script mints fresh ones per run.
- **The model:** the local stack runs the fake segmentation model, so `analysis` measures everything except the
  model. The real model's time on the VM is known from iltiam-ai-service#142: an 8 MP photo p95 1.56 s.
- **The VM:** a laptop is much faster than 2 OCPUs. To get closer, cap the containers' CPU while a scenario runs
  (`docker update --cpus <n> iltiam-dev-<service>-1`; remove the caps with
  `scripts/dev.sh compose up -d --force-recreate <services>`: `docker update --cpus 0` does not remove them).

## 3. Run it

```bash
scripts/dev.sh up                                 # the local stack
scripts/loadtest.sh seed                          # once: 500 patients, 60,000 image records
scripts/loadtest.sh run clinicians                # 3 min
scripts/loadtest.sh run upload                    # 4G, 20 Mbit/s up; --uplink-kbit 8000 for a weak link, 0 unshaped
scripts/loadtest.sh run analysis                  # 2 min
scripts/loadtest.sh run all
scripts/dev.sh reset                              # afterwards: back to the demo data only
```

Each run prints p50, p95 and max per page and PASS or FAIL per threshold, and exits 1 when a threshold fails. The
full k6 summary is in `loadtest/.work/<scenario>-summary.json` (gitignored).

## 4. When

- After a change to a list, the dashboard, upload or the analysis pipeline, before publishing its image.
- Before go-live (#23), with the results added to a dated report in this folder.

## 5. A small run on staging, later, by hand

Not part of the scripts, on purpose. Only to check that staging on the real VM behaves like the capped local runs.

**When:** after the Dec 1 demo, in a quiet window agreed in the team chat (for example a Friday morning), with
automatic deploys frozen as in [Runbook 9](../runbooks/09-cd-staging.md), section 3. Never while production has
real users: at that point use the local stack only, or the split VM (#19).

**What:** the `clinicians` scenario only (it only reads), with **5 users for 2 minutes**, one staging test doctor
(`seed_staging`, iltiam-backend#63). No upload, no analysis, no ZAP.

1. Tell the team in the chat: start time, end time, who watches.
2. Open two terminals. In the first, watch the VM:
   `ssh iltiam`, then `docker stats` (CPU and memory per container) and, in a second SSH session,
   `scripts/compose.sh staging logs -f --since 1m backend-web`.
3. Sign in as the staging test doctor in the web portal and copy an access token from the browser's developer tools
   (Network → a request to `/api/` → `Authorization`). Put it in `loadtest/.work/tokens.json` as
   `{"doctors": [{"token": "<token>", "long_wound": "<a wound id of that doctor's patient>"}], "upload_patients": [], "analysis_patients": []}`.
   The token lives 15 minutes: start within that time.
4. Run k6 by hand (not through `scripts/loadtest.sh`):

    ```bash
    docker run --rm -v "$PWD/loadtest/k6:/scripts:ro" -v "$PWD/loadtest/.work:/work" \
      -e SCENARIO=clinicians -e VUS=5 -e DURATION=2m \
      -e BASE_URL=https://staging-api.iltiamcare.com -e HOST=staging-api.iltiamcare.com \
      grafana/k6:1.3.0 run /scripts/iltiam.js
    ```

5. **Stop at once** (Ctrl+C) if any of these happens: a 5xx or a 429 in the k6 output, a container restarts or goes
   unhealthy in `docker stats`, the VM's memory goes above 85 %, `https://staging-api.iltiamcare.com/api/ready/` stops
   answering `ready`, or anyone in the chat asks.
6. Afterwards: check `/api/ready/` and a sign-in on `https://staging-app.iltiamcare.com`; delete `tokens.json`; add
   the numbers (p95 per page, peak CPU and memory per container) to a dated report here.
