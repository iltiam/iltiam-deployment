# ADR-0004: Free-first hosting, edge (Cloudflare), phone-code and email delivery

- **Status:** Accepted (2026-10-27, DEP#7). AI-12 measured 2026-10-27: GO. ben-fatah's decisions of 2026-10-23, revised the same day for cost. Decision 4 updated and Decision 6 added on 2026-10-28 (DEP-01); Decision 6 is pending confirmation that OCI Email Delivery is offered in Riyadh.
- **Deciders:** ben-fatah (deployment owner, account holder, pays by card), Omar-Nasri (backend).
- **Repo:** iltiam-deployment, `docs/adr/0004-hosting.md`.
- **Related:**
  - deployment issues: #1, #2, #3, #6, #7, #8, #9, #10, DEP-01, DEP-02, DEP-03, DEP-04, DEP-08, DEP-11, DEP-13, DEP-14;
  - AI-07, **AI-12 (ARM go/no-go)**, BE-04, BE-20, BE-21, WEB-03;
  - SRS §17; NFR-PERF-01, NFR-REL-01/02/04, NFR-SEC-04, NFR-MAI-01; FR-SA-9; FR-P-7.1.

## Context

ILTIAM v1.0 goes live before 2026-12-01. It is a graduation project paid from a personal card, so **about $300 a month is not acceptable**. The target is **$0 a month**, with a small, known paid step only if the free path fails.

The data is identifiable health data (sensitive under the PDPL), so it stays in Saudi Arabia.

**Workloads, measured:**
- AI compute per analysis on a 4-thread **x86** laptop CPU: 0.68 s p50 with ALG-03 off, 1.46 s with it on (`iltiam-ai-service/docs/benchmarks/tissue_classifier.md`).
- AI compute on the **Ampere A1** VM (`iltiam-1`, 2 OCPU) with 2 threads, on an 8 MP synthetic scene, measured 2026-10-27 (AI-12, iltiam/iltiam-ai-service#142): whole analysis 1,548 / 1,560 ms p50 / p95 with ALG-03 off, 2,765 / 2,789 ms with it on; ALG-02 alone 1,133 / 1,166 ms (`iltiam-ai-service/docs/benchmarks/segmentation_latency.md`, "By host (issue #142, ARM go/no-go)").
- Model load: 8–15 s per worker, about 1.2 GB of memory per worker process.
- Budgets: the owner's 4 s target, and NFR-PERF-01's 10 s.

## Decision 1: Oracle Cloud Always Free, Riyadh home region, Ampere A1 (ARM)

**What Always Free gives us** (Oracle docs, read 2026-10-23: [Always Free resources](https://docs.oracle.com/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)):

| Resource | Always Free limit | Our use |
|---|---|---|
| Ampere A1 compute (`VM.Standard.A1.Flex`, ARM) | **1,500 OCPU-hours and 9,000 GB-hours a month, "equivalent to 2 OCPUs and 12 GB of memory"**; one VM or two 1-OCPU VMs | One VM, 2 OCPU / 12 GB, for staging **and** production |
| AMD micro | 2 × VM.Standard.E2.1.Micro (1/8 OCPU, 1 GB) | Not used (too small) |
| Block volume | **200 GB total** (boot + block) and **5 volume backups**, home region only | 100 GB boot + 100 GB data (`/srv/iltiam`); 3 backups |
| Object storage | **20 GB**. A free-only account gets 20 GB across all tiers; an upgraded account gets 10 GB Standard + 10 GB Infrequent Access + 10 GB Archive. Plus 50,000 API requests a month. | Photos, masks, PDFs, exports, encrypted DB dumps |
| Outbound data | 10 TB a month | Plenty |
| Vault | **Software-protected master keys free**; 20 free HSM key versions; 150 secrets | Software keys: AES-256 and rotatable, which meets NFR-SEC-04 |
| Monitoring / Notifications / Email | 500 M ingestion points; 1,000 email notifications; 3,000 emails a month | Instance-state alarms; transactional email (Decision 6) |

**Note on the A1 allowance:** Oracle's A1 pricing page still says "the first 3K OCPU-hrs and 18K GB-hrs each month is free" ([Ampere A1 pricing](https://www.oracle.com/cloud/compute/arm/pricing)), which is 4 OCPU / 24 GB. The Always Free documentation now says 2 OCPU / 12 GB. **We plan for 2 OCPU / 12 GB**, the documented figure. Do not create a larger A1 shape on the free account: the console accepts 4 OCPU / 24 GB, but usage above 1,500 OCPU-hours / 9,000 GB-hours is not Always Free, and when the 30-day trial ends an over-limit A1 instance is disabled. Runbook 1 (`docs/runbooks/01-oci-account-and-vm.md`) shows how to shrink one with Edit shape.

**Is it available in Riyadh?**
- "You must create the Always Free compute instances in your home region."
- A1 is available "in any availability domain, except South Korea North (Chuncheon)", so Riyadh qualifies.
- **Sign up with Saudi Arabia Central (Riyadh) as the home region.** It cannot be changed later ([Free Tier overview](https://docs.oracle.com/iaas/Content/FreeTier/freetier.htm)).

**"Out of host capacity" risk:** Oracle's wording is that it "indicates a temporary lack of Always Free shapes in your home region. Try creating the instance in a different availability domain, or wait a while, then try to create the instance again. You can also choose to upgrade your account to Pay as You Go" (same doc).

Riyadh has a single availability domain. **Our workaround, in order:**
1. Retry over a few days. The community-proven OCI CLI retry loop launches every 60 s ([example](https://tpmullan.com/?p=77)).
2. **Upgrade to Pay As You Go.** "Oracle doesn't charge for Always Free resources after you upgrade, and will only charge you for resource usage above the Always Free limits" (Oracle doc). Community reports say PAYG accounts get capacity more easily; that is anecdotal, not in Oracle's docs.
3. The **$10 budget alert** catches any accidental paid resource.

**Idle reclamation:**
- Oracle may reclaim an Always Free instance that is idle for 7 days: CPU p95, network and (A1) memory all under 20 %.
- Two running environments keep memory well above 20 %.
- DEP#10 alerts if the instance stops.

**Budget alert (DEP#7):**
- An OCI Budget of **$10 a month** on the root compartment.
- Alert rules on ACTUAL spend at **50 %, 80 % and 100 %**, plus one FORECAST at 100 %.
- Emailed to ben-fatah and a teammate. Any charge shows up within a day ([OCI CLI alert-rule reference](https://docs.oracle.com/iaas/tools/oci-cli/latest/oci_cli_docs/cmdref/budgets/alert-rule/create.html)).

**Fallback** if OCI sign-up itself fails: AWS Bahrain with synthetic data only. Production waits for an in-Kingdom account.

## Decision 2: the stack on ARM (aarch64): check and risks

**Packages and images, checked 2026-10-23** (PyPI JSON API, the PyTorch CPU index, Docker Hub tags):

| Component | aarch64 build | Evidence |
|---|---|---|
| torch, torchvision (CPU) | yes | PyPI `torch-2.14.1-cp311-…manylinux_2_28_aarch64`; CPU index has `+cpu` aarch64 wheels for cp311 (used by the AI Dockerfile) |
| opencv-contrib-python-headless (pinned `<5`) | yes | `4.14.0.94` has `manylinux2014_aarch64` and `manylinux_2_28_aarch64` wheels |
| numpy, pillow, pydantic-core, pyyaml | yes | cp311 and cp313 aarch64 wheels |
| transformers' native deps: tokenizers, safetensors, hf-xet | yes | abi3 aarch64 wheels |
| psycopg-binary (AI), psycopg2-binary (backend, cp313) | yes | aarch64 wheels |
| cryptography, grpcio (firebase-admin), uharfbuzz (PDF Arabic), charset-normalizer | yes | aarch64 wheels |
| Django, DRF, Celery, boto3, fpdf2, pypdf, pyotp, phonenumbers | pure Python | — |
| Images: python 3.11/3.13-slim, postgres:16-alpine, redis:7-alpine, nginx, node:22-alpine, cloudflare/cloudflared, prometheus, grafana, loki, promtail, node-exporter | yes (arm64) | Docker Hub manifests |
| Web build (Vite) | runs anywhere | builder stage of the web image |

**No package in the service images lacks an ARM build.** The AI repo's `train` extras (onnxruntime, albumentations, timm) are not in the service image and were not checked.

**Risks on ARM, and what we do:**
1. **Speed on 2 Ampere cores: GO, no mitigation step needed** (AI-12, 2026-10-27). The whole analysis at 8 MP with ALG-03 off has a p95 of 1.56 s against the 4 s target; 10 s is the hard limit. The fallback ladder (tune threads, keep ALG-03 off, add 2 A1 OCPUs, move to x86) is not needed.
   - With ALG-03 on, the p95 is 2.79 s. That leaves about 1.2 s for upload, decode, Celery and Redis, so **ALG-03 stays off by default** until DEP#2 measures through the stack.
   - Torch 2.14.1+cpu on aarch64 has oneDNN but no ACL. That did not affect the verdict.
2. **Images must be built for linux/arm64.**
   - Under QEMU emulation on an x86 runner the torch layer builds slowly and burns free minutes.
   - GitHub's docs now list the `ubuntu-24.04-arm` runner for private repositories, using the account's free minutes ([GitHub docs](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)). The August 2025 changelog said it was public-only ([changelog](https://github.blog/changelog/2025-08-07-arm64-hosted-runners-for-public-repositories-are-now-generally-available/)).
   - **Fallback: build on the VM.** Images are published only on merges to `main` and tags (DEP#1).
3. **Memory:** 12 GB for two environments. DEP#2 sets the budget: about 3.8 GB per environment, about 1 GB for monitoring, about 9 GB in total, plus 4 GB swap, with `mem_limit` on every service. The staging AI worker is the first thing stopped under pressure.
4. **Numbers can differ slightly from x86.** Floating-point order on ARM kernels can move a mask boundary pixel. NFR-MAI-03 (identical results) holds per deployment configuration, which is still true.
   - The golden regression suite and its baseline stay on x86 CI.
   - AI-12 measured the area at 25.66 cm² on `good_marker.jpg` and 25.27 cm² on the 8 MP scene, identical on A1 and x86.
5. **Capacity and reclamation:** see Decision 1.

**Requirement for DEP#2 (from AI-12):** run the AI worker with **2 torch threads** (2 beat the shipped 4 by about 6 % on the 2-core VM), `OMP_NUM_THREADS=2`, and worker concurrency 1 per environment. The shipped config has `torch_threads: 4` (`segmentation.yaml`, `tissue.yaml`) and no environment override yet; the override is planned in iltiam/iltiam-ai-service#143.

## Decision 3: one VM for staging and production, split only when needed

- **One machine:** `iltiam-1` (A1, 2 OCPU / 12 GB) runs two Compose projects, **`iltiam-staging` and `iltiam-prod`**.
- **Separate per environment:** env files and secrets (GitHub Environments), Postgres container and databases (`iltiam`, `iltiam_ai`), Redis, buckets, Cloudflare Tunnel and hostnames, backups.
- **Shared:** the read-only weights volume and the monitoring stack.
- **Deploys:** staging deploys automatically (DEP-03), and the script refuses to touch production. Production deploys only with approval (DEP-04).
- **Split triggers** (production moves to its own VM, paid):
  - memory above 85 % for a week;
  - production analysis p95 above 4 s because of staging load;
  - a clinic contract that requires isolation;
  - growth that makes object storage the larger part of the bill anyway.
- **Load tests (DEP-08)** run before production has real users, or in an agreed quiet window.
- **Restore tests run on the VM**, so production dumps never leave the Kingdom.

## Decision 4: Cloudflare (free) for DNS, TLS, DDoS, connected by Cloudflare Tunnel

- **Domain:** `iltiamcare.com`, registered on Cloudflare Registrar on 2026-10-28 (auto-renew, WHOIS privacy, DNSSEC). Set up in Runbook 2 (`docs/runbooks/02-cloudflare-dns-tls.md`).
- **Tunnels:** one per environment (`staging-app.`/`staging-api.iltiamcare.com`, `app.`/`api.iltiamcare.com`), remotely managed, each run by the `cloudflared` container of its own Compose project. Set up in Runbook 3 (`docs/runbooks/03-cloudflare-tunnels.md`, DEP#9).
- **Why Tunnel over Caddy:** no inbound web ports, no certificates on the VM, one container, free. Caddy remains the exit if we ever leave Cloudflare. The SRS (§17) names NGINX; DEP-12 records the divergence. nginx still serves the SPA inside the web image.
- **What Cloudflare must not do:**
  - **Cache:** no cache for API hosts or any health data; only `/assets/*` on `app.` is cached.
  - **Files:** photos, masks and PDFs never pass through Cloudflare; clients use presigned OCI URLs (≤ 15 min).
  - **Uploads:** they stay under the Free plan's **100 MB** request limit ([Cloudflare limits](https://developers.cloudflare.com/workers/platform/limits/)); ours are capped at 25 MB.
  - **Response rewriting:** Rocket Loader and Email Obfuscation are off for the whole zone, because they inject inline scripts that the web app's content security policy forbids (WEB-33). A Configuration Rule keeps them off on the API hosts too.
  - **Bot Fight Mode:** off. It may challenge API and mobile traffic, and on the Free plan it can't be skipped per hostname.
  - **AI service:** no route to it.
- **Security Level:** Cloudflare no longer has graded levels (low, medium, high). The threat score they were based on is always 0. In the new dashboard, Security Level only turns Under Attack mode on or off ([Cloudflare](https://developers.cloudflare.com/waf/tools/security-level/), updated 2026-04-16). So DEP-01's "Security Level medium" has nothing to set.
- **Cache design (Runbook 3):** three non-overlapping Cache Rules: bypass the API hosts entirely; on the app hosts, bypass everything except `/assets/*` (so `/index.html` and `/config.js` are never cached); cache `/assets/*` by the origin's `Cache-Control`. Nothing a signed-in user receives is cached, because every API call goes to an API host.
- **Rate limit:** the Free plan's single rate limiting rule can only match the URL path, so one rule covers the sign-in and password paths of both environments (10 requests per 10 s per IP). It is a coarse outer limit; the backend keeps its own stricter per-IP limit. Two custom rules block scanner paths and any write method on the app hosts.
- **Cloudflare Access (free, email one-time PIN)** in front of `grafana.` and the backend's `/admin` on both API hosts, for the named administrators only. The staging hosts stay open, because the mobile staging builds call them.
- **Security headers:** the web image's nginx sends the content security policy and the other security headers (WEB-03); Cloudflare adds none and injects no scripts.
- **SSH stays on public port 22 for v1.0** (key-only, no root, fail2ban). SSH through a tunnel would need a host-level `cloudflared` outside Compose and an Access service token for the deploy runners; it is a later hardening step.
- **Under Attack mode** is the manual switch for an HTTP flood. Its challenge page stops the mobile app and API calls, so it is turned on with a Configuration Rule for the web hosts only. The whole zone is a last resort (Runbook 2, section 9.3).
- **PDPL:** TLS is decrypted at Cloudflare's edge. In-Kingdom-only decryption (Regional Services, which includes Saudi Arabia) is part of the paid Data Localization Suite ([Cloudflare](https://developers.cloudflare.com/data-localization/region-support/)). This is recorded in the ROPA (DEP#6).

## Decision 5: phone codes through Authentica (recommended)

**What the backend does now:**
- Neither Authentica nor Firebase Auth.
- Its own hashed codes, lockout, CAPTCHA, remember-device, step-up, and email and authenticator fallbacks.
- SMS goes through a pluggable backend (Console, LocMem, Twilio). Twilio is coded but unconfigured.

**Recommendation:**
- Add `AuthenticaSMSBackend`, which calls `POST https://api.authentica.sa/api/v2/send-sms` with `X-Authorization`, `phone`, `message` and `sender_name` ([Authentica README](https://github.com/AuthenticaSA/Authentica)) (BE-20, DEP-14).
- It's a Saudi provider, 100 free credits, and about **0.12 SAR per code** on the smallest package ([pricing](https://authentica.sa/en/pricing-en/)). Email codes are free.
- **Firebase Phone Auth is rejected:** it would rewrite sign-in in all apps, Google bills per SMS on the Blaze plan, and phone numbers would go to Google. Firebase stays for FCM push, which is free.

## Decision 6: transactional email through OCI Email Delivery (Riyadh)

- **Status: decided, pending confirmation** that Email Delivery is offered in Saudi Arabia Central (Riyadh) for our tenancy (Runbook 2, section 11.2). Not set up yet.
- **What we send:**
  - invitations and activation links;
  - email sign-in codes (the fallback when an SMS doesn't arrive);
  - breach notices (FR-P-7.1).

  That is tens of emails a day at most. All go from `no-reply@iltiamcare.com`.

**Why OCI Email Delivery:**
- **Free:** 3,000 emails a month on Always Free ([Oracle](https://docs.oracle.com/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)).
- **In the Kingdom:** the same tenancy and region as everything else, so names, email addresses and codes are processed in Riyadh.
- **Fits the backend:** SMTP on port 587 with STARTTLS, which the backend uses (`EMAIL_USE_TLS`).
- **Separate credentials:** one SMTP user per environment, so staging and production never share a credential.
- **Authentication:** DKIM by CNAME and a custom return path, so SPF and DKIM both align for DMARC.

**Alternatives:**

| Provider | Free tier | Why not first |
|---|---|---|
| Resend (**fallback**) | 3,000 a month, 100 a day, SMTP included ([pricing](https://resend.com/pricing)) | Processed outside the Kingdom; needs a PDPL record (DEP#6) before use |
| Brevo | 300 a day | Processed in the EU; built for marketing email |

**DMARC now:** `p=quarantine` is published before any mail is sent (Runbook 2, section 11.1). The domain sends nothing yet, so nothing legitimate can be quarantined, and spoofing is blocked from day one. Reports go to Cloudflare DMARC Management (free).

**If Riyadh has no Email Delivery:** use Resend, after the DEP#6 record and the owner's approval, and update this decision.

## Cost table

### Monthly, free-first (expected)

| Item | Free allowance | Our expected use | Cost |
|---|---|---|---|
| OCI A1 VM | 2 OCPU / 12 GB | 2 OCPU / 12 GB, both environments | **$0** |
| OCI block storage | 200 GB, 5 backups | 200 GB, 3 backups | **$0** |
| OCI object storage | 20 GB (10 Std + 10 IA + 10 Archive after upgrade) | < 15 GB at launch | **$0** |
| OCI Vault | software keys free | 1–2 keys | **$0** |
| OCI egress | 10 TB | ≪ 1 TB | **$0** |
| Cloudflare (DNS, TLS, DDoS, Tunnel, Access ≤ 50 users) | Free plan | 4 hostnames, 2 tunnels | **$0** |
| OCI Email Delivery (Decision 6) | 3,000 emails a month | invitations, codes, notices | **$0** |
| Firebase Cloud Messaging | free | Android push | **$0** |
| GitHub Actions | account's free minutes | images only on `main` and tags | **$0** (watch minutes) |
| Uptime probe | free tier of a hosted pinger | 2 checks | **$0** |
| **Total infrastructure** | | | **$0 / month** |
| Authentica codes (usage) | 100 free credits | e.g. 300 SMS codes a month ≈ 36 SAR (≈ $10); email codes free | usage-based |

### Smallest paid fallback, if free fails (per month, list prices)

| Situation | Change | Cost / month |
|---|---|---|
| ARM too slow (AI-12). **Not needed:** AI-12 GO, 2026-10-27 | Add 2 A1 OCPUs (4 OCPU / 12 GB): 2 × $0.01 × 730 h ([Oracle A1 pricing](https://www.oracle.com/cloud/compute/arm/pricing)) | **≈ $15** |
| Also short of memory | 4 OCPU / 24 GB A1: + 12 GB × $0.0015 × 730 h | **≈ $28** |
| No A1 capacity at all, even after PAYG | x86 `VM.Standard.E5.Flex` 1 OCPU (2 vCPU) / 12 GB: $0.039318 × 730 + 12 × $0.0026212 × 730 ([Oracle compute pricing](https://www.oracle.com/cloud/compute/pricing)); block storage stays inside the free 200 GB | **≈ $52** |
| Object storage beyond 20 GB | ≈ $0.0255 / GB-month ([Oracle storage pricing](https://www.oracle.com/cloud/storage/pricing)) | e.g. +50 GB ≈ **$1.3** |
| Optional backup copy in Jeddah | same rate, about 1 GB of dumps | **≈ $0.03** |
| Production split to its own VM (later) | second A1 4 OCPU / 24 GB (all paid) | **≈ $55** |

### One-time and yearly

| Item | Cost |
|---|---|
| Domain `.com` on Cloudflare Registrar (at cost, yearly) | **≈ $10.46 / year** ([CostGoat, checked 2026-10-20](https://costgoat.com/pricing/cloudflare-domains); [DomainOffer](https://domainoffer.net/tld/com/cloudflare)) |
| Google Play developer registration (one-time) | **$25** ([Play Console Help](https://support.google.com/googleplay/android-developer/answer/6112435?hl=en)) |
| Authentica | 100 free credits; then packages from **240 SAR / 2,000 credits ≈ 0.12 SAR (≈ $0.03) per SMS/WhatsApp code**; email free |
| Apple Developer Program | v1.1 only, not needed for v1.0 |

**First-year total for v1.0: about $35 plus codes,** with $0 a month of infrastructure if the free path holds.

## Consequences

- The deployment issues are runbooks sized for the free VM: #7 (account, $10 budget, A1 VM), #2 (two Compose projects with a memory budget), #9 (two tunnels), #8 (free backups, restore on the VM), #10 (about 1 GB monitoring), DEP-02 (20 GB storage, software keys), DEP-03 (staging only), DEP-04 (production project and split triggers), DEP-08 (load tests that spare production), DEP-11.
- AI-12 (2026-10-27) confirmed we stay on ARM.
- Images are multi-arch (DEP#1, AI-07, BE-04, WEB-03).
- **Revisit when money or load changes:** AWS or Azure Saudi regions, managed Postgres, Cloudflare Data Localization Suite, a production split.
