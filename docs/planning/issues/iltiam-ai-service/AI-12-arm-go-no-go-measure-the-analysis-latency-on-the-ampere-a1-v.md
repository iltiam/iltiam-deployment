# ARM go/no-go: measure the analysis latency on the Ampere A1 VM against the 4 s budget

> **Plan ID:** AI-12 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #2 in Thabit's list
> **Blocked by:** DEP#7
> **Blocks:** AI-07, DEP#2
> **SRS:** NFR-PERF-01 (10 s); owner target 4 s; ADR-0004

## Context

The free server is ARM (aarch64) with 2 OCPUs. Every Python dependency has a Linux aarch64 wheel (checked on PyPI and
the PyTorch CPU index on 2026-10-23), but the speed is unknown: the published numbers are from an x86 laptop with 4
threads (0.68 s compute with ALG-03 off). Measure on the real VM before building everything on it. Weights come
from the private release (read-only token; never commit them). Run on training/validation fixtures only.

## Steps

- [ ] On `iltiam-1`: `git clone` iltiam-ai-service; `python3.11 -m venv .venv && . .venv/bin/activate`; `pip install --index-url https://download.pytorch.org/whl/cpu torch torchvision && pip install -e ".[service]"`; `GITHUB_TOKEN=... python scripts/download_weights.py --model segformer_b2_wound`.
- [ ] ALG-02 at 8 MP, 2 threads: `python scripts/benchmark_segmentation.py --runs 30 --warmup 5 --size 3264x2448 --threads 2 --full`.
- [ ] Whole analysis, 2 threads: `GITHUB_TOKEN=... python scripts/download_weights.py --model mobilenetv3_large_tissue`, then `python scripts/benchmark_tissue.py --runs 30 --warmup 5 --threads 2 --end-to-end`. It reports the ALG-03 stage and `Pipeline.analyze` on the fixture photo with ALG-03 off and on (p50/p95).
- [ ] Check that torch uses the ARM kernels: `python -c "import torch; print(torch.__config__.show())"` (look for oneDNN / ACL) and that `torch.get_num_threads()` is 2.
- [ ] Record the results in `docs/benchmarks/segmentation_latency.md` (new row "Ampere A1, 2 OCPU") and in ADR-0004; after DEP#2, repeat through the stack: 20 uploads of 8 MP photos through staging, upload->result p95.
- [ ] **If p95 > 4 s (ALG-03 off)**, in this order:
- [ ] (1) set `torch` threads = OCPUs and `OMP_NUM_THREADS`, AI worker concurrency 1 per environment, stop the staging AI worker while production is busy;
- [ ] (2) keep ALG-03 off (the default);
- [ ] (3) grow the A1 VM to 4 OCPUs: the 2 extra OCPUs cost about $15/month ($0.01/OCPU-hour), memory stays 12 GB;
- [ ] (4) if ARM is still too slow, the x86 fallback in ADR-0004 (about $52/month) and rebuild the images for amd64 only;
- [ ] The 10 s NFR-PERF-01 is the hard limit; 4 s is the owner's target. Write down which step was needed.

## Acceptance criteria

- [ ] p50/p95 for ALG-02 and for the whole analysis (ALG-03 off and on) on the A1 VM are committed.
- [ ] A go/no-go decision for ARM is written in ADR-0004 before DEP#2 starts.

## Tests required

- The two benchmark scripts; the through-stack measurement after DEP#2.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
