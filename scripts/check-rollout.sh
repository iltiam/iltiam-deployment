#!/usr/bin/env bash
# Tests scripts/lib/rollout.sh, the no-downtime replacement deploy.sh uses for ai-api and ai-worker
# (iltiam-ai-service#150), on a throwaway Compose project of busybox containers. Needs a Docker daemon; touches
# nothing but the project `iltiam-rollout-check`, which it removes at the end.
#
#   scripts/check-rollout.sh
#
# Each container writes /tmp/ready READY_AFTER seconds after it starts (as a model finishes loading), and on SIGTERM
# writes "drained" to its log, waits 2 s (a job finishing) and exits 0. The checks:
#   1. no container yet: one is started;            2. same config: nothing is recreated;
#   3. a new config: the new container is ready before the old one gets SIGTERM, which drains and exits 0;
#   4. never ready: the new one is removed, its logs kept, the old one untouched;
#   5. not enough memory: stops before starting anything;  6. two running: refuses, says how to clean up.

set -euo pipefail
export MSYS_NO_PATHCONV=1 # Git Bash: keep /tmp/ready a container path

PROJECT=iltiam-rollout-check
IMAGE=busybox:1.36.1
tmp="$(mktemp -d "${TMPDIR:-/tmp}/rollout-check-XXXXXX")"
failures=0

native() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

cleanup() {
  docker compose -p "$PROJECT" -f "$(native "$tmp/compose.yml")" down -t 1 --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap cleanup EXIT

pass() { printf '  PASS  %s\n' "$*"; }
fail() {
  printf '  FAIL  %s\n' "$*"
  failures=$((failures + 1))
}
expect() { # expect <description> <command ...>
  local what="$1"
  shift
  if "$@"; then pass "$what"; else fail "$what"; fi
}

cat >"$tmp/compose.yml" <<'EOF'
name: iltiam-rollout-check
services:
  app:
    image: busybox:1.36.1
    environment:
      VERSION: "${VERSION:-1}"
      READY_AFTER: "${READY_AFTER:-2}"
    command:
      - sh
      - -c
      - >-
        trap 'echo drained $$VERSION; sleep 2; exit 0' TERM;
        (sleep $$READY_AFTER && echo $$VERSION > /tmp/ready) &
        while true; do sleep 1; done
    healthcheck:
      test: ["CMD", "true"]
      interval: 1s
      start_period: 1s
    stop_grace_period: 10s
    mem_limit: 32m
EOF

# What deploy.sh gives rollout.sh.
compose() { docker compose -p "$PROJECT" -f "$(native "$tmp/compose.yml")" "$@"; }
log() { printf '==> %s\n' "$*"; }
ok() { printf '    ok: %s\n' "$*"; }
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}
# shellcheck source=scripts/lib/rollout.sh
source "$(dirname "$0")/lib/rollout.sh"
ROLLOUT_TIMEOUT_S=30
ROLLOUT_LOG_DIR="$tmp"
ready_cmd=(cat /tmp/ready)
printf 'MemTotal: 8000000 kB\nMemAvailable: 4000000 kB\n' >"$tmp/meminfo"
ROLLOUT_MEMINFO="$tmp/meminfo"

docker pull -q "$IMAGE" >/dev/null
running() { compose ps -q app; }
count() { running | wc -l | tr -d ' '; }
version_of() { docker exec "$1" cat /tmp/ready 2>/dev/null; }
# A first deploy returns once its container runs (`up -d --wait`; this busybox has no healthcheck), not once it is
# ready, and it writes /tmp/ready READY_AFTER seconds later: wait for that before reading the version.
version_when_ready() { # version_when_ready <container>: its /tmp/ready, waiting up to 10 s for it to be written
  local v
  for _ in $(seq 1 20); do
    if v="$(version_of "$1")" && [[ -n "$v" ]]; then
      printf '%s' "$v"
      return 0
    fi
    sleep 0.5
  done
  return 1
}
in_env() { # in_env <NAME=value ...> -- <command ...>: in a subshell (die exits it), output in $tmp/out
  (
    while [[ "$1" != -- ]]; do
      export "${1?}"
      shift
    done
    shift
    "$@"
  ) >"$tmp/out" 2>&1
}
attempt() { in_env "$@" -- rollout app "${ready_cmd[@]}"; }
precheck() { in_env "$@" -- rollout_memory_check app; }

echo "1. first deploy"
expect "rollout starts the first container" attempt VERSION=1
first="$(running)"
expect "one container, version 1" test "$(count)" = 1 -a "$(version_when_ready "$first")" = 1

echo "2. same config"
expect "rollout succeeds" attempt VERSION=1
expect "nothing recreated" test "$(running)" = "$first"
expect "it says up to date" grep -q "app: up to date" "$tmp/out"

echo "3. a new config"
expect "rollout to version 2 succeeds" attempt VERSION=2 READY_AFTER=4
second="$(running)"
expect "one container, version 2" test "$(count)" = 1 -a "$(version_of "$second")" = 2
expect "the old container is removed" test -z "$(docker ps -aq --filter "id=$first")"
expect "the old one drained on SIGTERM and exited 0" grep -q "old app stopped cleanly" "$tmp/out"
expect "the new one started before the old one was stopped" grep -q "new container .* next to" "$tmp/out"
expect "it was ready before the stop" bash -c "grep -n 'is ready: 2' '$tmp/out' | cut -d: -f1 | {
  read -r r; s=\$(grep -n 'stop the old app' '$tmp/out' | cut -d: -f1); test \"\$r\" -lt \"\$s\"; }"

echo "4. never ready"
ROLLOUT_TIMEOUT_S=6
if attempt VERSION=3 READY_AFTER=999; then fail "rollout should fail"; else pass "rollout fails"; fi
ROLLOUT_TIMEOUT_S=30
expect "the old container still runs, version 2" test "$(running)" = "$second" -a "$(version_of "$second")" = 2
expect "the failed one is removed" test "$(docker ps -aq --filter label=com.docker.compose.service=app | wc -l | tr -d ' ')" = 1
expect "it says why and keeps the logs" grep -q "not ready after 6 s.*the old one still runs; its logs: " "$tmp/out"
expect "a log file was written" bash -c "ls '$tmp'/rollout-app-*.log >/dev/null"

echo "5. not enough memory"
printf 'MemTotal: 8000000 kB\nMemAvailable: 200000 kB\n' >"$tmp/meminfo" # 195 MB < 32 + 256
if attempt VERSION=3; then fail "rollout should refuse"; else pass "rollout refuses"; fi
expect "it says how much is needed" grep -q "195 MB available, 288 MB needed" "$tmp/out"
expect "nothing changed" test "$(running)" = "$second"
if precheck VERSION=3; then fail "the pre-check should refuse"; else pass "the pre-check refuses before anything changes"; fi
expect "the pre-check ignores an up-to-date service" precheck VERSION=2 READY_AFTER=4
printf 'MemTotal: 8000000 kB\nMemAvailable: 4000000 kB\n' >"$tmp/meminfo"

echo "6. two running"
compose up -d --no-deps --no-recreate --scale app=2 app >/dev/null 2>&1
if attempt VERSION=3; then fail "rollout should refuse"; else pass "rollout refuses"; fi
expect "it says how to clean up" grep -q "2 app containers are running: an earlier rollout was cut short" "$tmp/out"

if ((failures)); then
  echo "check-rollout: $failures check(s) FAILED"
  exit 1
fi
echo "check-rollout: all checks passed"
