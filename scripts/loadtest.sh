#!/usr/bin/env bash
# Load and performance tests against the LOCAL stack only (issue #22, docs/perf/README.md).
#
#   scripts/loadtest.sh seed                         500 patients, 60,000 image records (once; minutes)
#   scripts/loadtest.sh run <clinicians|upload|analysis|all> [--uplink-kbit <n>]
#   scripts/loadtest.sh clean                        stop the helper containers
#
#   --uplink-kbit   the upload scenario's simulated 4G uplink in kbit/s (default 20000, a good 4G uplink; 8000 is a
#                   typical one; 0 sends unshaped, to measure the server alone). The download side is not limited.
#
# It runs k6 (and toxiproxy for the 4G link) as containers on the iltiam-dev Compose network and targets the
# Compose service names. There is no option for another address, on purpose: staging and production share one small
# VM (and the supervisor demo), so never load test them from here. docs/perf/README.md, section 5, is the procedure
# for a small staging run in a quiet window, done by hand.
#
# Start the stack first: scripts/dev.sh up. Results: loadtest/.work/<scenario>-summary.json (gitignored).
set -euo pipefail
cd "$(dirname "$0")/.." || exit 2

K6_IMAGE="grafana/k6:1.3.0"
TOXIPROXY_IMAGE="ghcr.io/shopify/toxiproxy:2.12.0"
NETWORK="iltiam-dev_default"
PROXY="iltiam-loadtest-toxiproxy"
WORK="loadtest/.work"
UPLINK_KBIT=20000

die() { printf 'loadtest.sh: %s\n' "$*" >&2; exit 1; }
say() { printf '\n== %s\n' "$*"; }
host_path() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$(cd "$1" && pwd)"; else (cd "$1" && pwd); fi; }
dc() { MSYS_NO_PATHCONV=1 docker compose -p iltiam-dev "$@"; }

need_stack() {
  docker info >/dev/null 2>&1 || die "the Docker daemon is not running"
  dc ps --status running --services 2>/dev/null | grep -qx backend-web \
    || die "the local stack is not running: scripts/dev.sh up"
  mkdir -p "$WORK"
}

cmd_seed() {
  need_stack
  say "seed_load_test (iltiam-backend): 50 doctors, 500 patients, 4,000 visits"
  # The production settings allow this switch on ENVIRONMENT=staging, which the local stack is.
  dc exec -T -e LOAD_TEST_SEED_ENABLED=True backend-web python manage.py seed_load_test
  say "Bulk image records up to 60,000 (loadtest/seed_bulk.py)"
  dc exec -T backend-web python manage.py shell <loadtest/seed_bulk.py
}

make_photo() {
  [ -s "$WORK/photo-10mb.jpg" ] && return 0
  say "Making a ~10 MB, 8.3-megapixel test photo"
  # Noise does not compress: the largest JPEG quality that stays at or under 10,000,000 bytes (the upload limit).
  dc exec -T backend-web python -c '
import io, random, sys
from PIL import Image, ImageDraw
random.seed(22)
w, h = 3504, 2368
img = Image.frombytes("RGB", (w, h), random.randbytes(w * h * 3))
ImageDraw.Draw(img).ellipse((1300, 800, 2200, 1600), fill=(150, 40, 40))
for q in range(100, 50, -1):
    buf = io.BytesIO(); img.save(buf, "JPEG", quality=q)
    if buf.tell() <= 10_000_000:
        break
sys.stdout.buffer.write(buf.getvalue())' >"$WORK/photo-10mb.jpg"
  echo "$(wc -c <"$WORK/photo-10mb.jpg") bytes"
}

mint_tokens() {
  # Tokens live 15 minutes: fresh ones for every run.
  dc exec -T backend-web python manage.py shell <loadtest/mint_tokens.py | tail -n 1 >"$WORK/tokens.json"
  jq -e '.doctors | length == 50' "$WORK/tokens.json" >/dev/null || die "could not mint tokens: run scripts/loadtest.sh seed first"
}

start_proxy() {  # --uplink-kbit 0: no shaping, to measure the server's own time
  local kbyte=$((UPLINK_KBIT / 8))
  docker rm -f "$PROXY" >/dev/null 2>&1 || true
  MSYS_NO_PATHCONV=1 docker run -d --rm --name "$PROXY" --network "$NETWORK" "$TOXIPROXY_IMAGE" >/dev/null
  sleep 2
  MSYS_NO_PATHCONV=1 docker exec "$PROXY" /toxiproxy-cli create -l 0.0.0.0:18000 -u backend-web:8000 api >/dev/null
  # Upstream = phone to server. 4G also adds latency: 40 ms each way.
  if [ "$UPLINK_KBIT" = 0 ]; then echo "Link: not shaped"; return; fi
  MSYS_NO_PATHCONV=1 docker exec "$PROXY" /toxiproxy-cli toxic add -t bandwidth -u -a "rate=$kbyte" api >/dev/null
  MSYS_NO_PATHCONV=1 docker exec "$PROXY" /toxiproxy-cli toxic add -t latency -a latency=40 api >/dev/null
  echo "4G link: uplink $UPLINK_KBIT kbit/s ($kbyte KB/s), 40 ms latency"
}

run_k6() {  # run_k6 <scenario> <base url>
  local scenario="$1" base="$2" rc=0
  MSYS_NO_PATHCONV=1 docker run --rm --network "$NETWORK" \
    -v "$(host_path loadtest/k6):/scripts:ro" -v "$(host_path "$WORK"):/work" \
    -e SCENARIO="$scenario" -e BASE_URL="$base" -e HOST=backend-web \
    "$K6_IMAGE" run --quiet /scripts/iltiam.js >"$WORK/$scenario.log" 2>&1 || rc=$?
  summarise "$scenario"
  return $rc
}

summarise() {  # one line per tagged trend, then the thresholds
  local f="$WORK/$1-summary.json"
  [ -s "$f" ] || { echo "no summary: see $WORK/$1.log"; tail -n 20 "$WORK/$1.log"; return; }
  jq -r '
    .metrics | to_entries[]
    | select(.key | test("^(http_req_duration\\{|analysis_end_to_end$)"))
    | "  \(.key): p50 \(.value.values.med | floor) ms, p95 \(.value.values["p(95)"] | floor) ms, max \(.value.values.max | floor) ms, n \(.value.values.count // "-")"' "$f"
  jq -r '.metrics | to_entries[] | select(.value.thresholds) | .key as $k
    | .value.thresholds | to_entries[] | "  threshold \($k) \(.key): \(if .value.ok then "PASS" else "FAIL" end)"' "$f"
  jq -r '"  requests \(.metrics.http_reqs.values.count), failed \((.metrics.http_req_failed.values.rate * 100 * 100 | floor) / 100) %"' "$f"
}

cmd_run() {
  local which="${1:-}"; shift || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --uplink-kbit) UPLINK_KBIT="$2"; shift 2 ;;
      *) die "unknown option $1" ;;
    esac
  done
  need_stack
  local scenarios=() s failed=0
  case "$which" in
    all) scenarios=(clinicians upload analysis) ;;
    clinicians | upload | analysis) scenarios=("$which") ;;
    *) die "run takes clinicians, upload, analysis or all" ;;
  esac
  [ "$which" = clinicians ] || make_photo
  for s in "${scenarios[@]}"; do
    mint_tokens
    say "Scenario $s"
    if [ "$s" = upload ]; then
      start_proxy
      run_k6 upload "http://$PROXY:18000" || failed=1
      docker rm -f "$PROXY" >/dev/null 2>&1 || true
    else
      run_k6 "$s" http://backend-web:8000 || failed=1
    fi
  done
  [ $failed = 0 ] && echo "All thresholds passed." || echo "At least one threshold failed (see above and $WORK)."
  return $failed
}

case "${1:-help}" in
  seed) cmd_seed ;;
  run) shift; cmd_run "$@" ;;
  clean) docker rm -f "$PROXY" >/dev/null 2>&1 || true; echo "cleaned" ;;
  help | -h | --help) awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0" ;;
  *) die "unknown command $1 (scripts/loadtest.sh help)" ;;
esac
