# shellcheck shell=bash
# ci-common.sh: shared helpers for scripts/ci-local.sh (local replacement for GitHub-hosted CI).
# The same file is vendored in every ILTIAM repo (iltiam-deployment/LOCAL_CI_MIGRATION.md); keep the copies identical
# and bump CI_COMMON_VERSION when you change it.
#
# A check is a shell function or command run through `ci_check`. Its result is one of
#   PASS              exit 0
#   FAIL              any other exit code
#   BLOCKED           exit 77 (call `ci_blocked "reason"` inside a check function); a required BLOCKED fails the run
#   SKIPPED-OPTIONAL  an optional check that cannot run here (`ci_skip_optional`); never fails the run
# The run exits 1 when any REQUIRED check is FAIL or BLOCKED, 0 otherwise.

CI_COMMON_VERSION=1

set -o pipefail

CI_MODE=""
CI_NAMES=()
CI_LEVELS=()
CI_RESULTS=()
CI_NOTES=()
CI_SECONDS=()
CI_REPO_ROOT=""
CI_LOG_DIR=""
CI_BLOCK_FILE=""
CI_START_SNAPSHOT=""
CI_START_EPOCH=0

_ci_red() { if [ -t 1 ]; then printf '\033[31m%s\033[0m' "$1"; else printf '%s' "$1"; fi; }
_ci_green() { if [ -t 1 ]; then printf '\033[32m%s\033[0m' "$1"; else printf '%s' "$1"; fi; }
_ci_yellow() { if [ -t 1 ]; then printf '\033[33m%s\033[0m' "$1"; else printf '%s' "$1"; fi; }

ci_log() { printf '[ci-local] %s\n' "$*"; }

# ci_init <repo-name> "$@": parses the common options and leaves the rest in CI_ARGS.
ci_init() {
  local repo="$1"
  shift
  CI_REPO_NAME="$repo"
  CI_ARGS=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --fast) CI_MODE=fast ;;
      --full) CI_MODE=full ;;
      -h | --help) CI_MODE=help ;;
      *) CI_ARGS+=("$1") ;;
    esac
    shift
  done
  if [ "$CI_MODE" = help ] || [ -z "$CI_MODE" ]; then
    return 0
  fi
  CI_REPO_ROOT="$(git rev-parse --show-toplevel)" || {
    echo "ci-local: not inside a git repository" >&2
    exit 2
  }
  cd "$CI_REPO_ROOT" || exit 2
  CI_LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ci-local-${repo}-XXXXXX")"
  CI_BLOCK_FILE="$CI_LOG_DIR/.blocked"
  CI_START_EPOCH=$(date +%s)
  CI_START_SNAPSHOT="$(_ci_snapshot)"
  ci_log "$repo: --$CI_MODE, logs in $CI_LOG_DIR"
  ci_check "checkout line endings (.gitattributes)" required -- ci_eol_check
}

# Files that differ from HEAD (tracked, staged or not) plus untracked files that are not gitignored, each with a
# content hash, so the run can tell which files it changed itself. Gitignored output (*.g.dart, build/) is ignored.
_ci_snapshot() {
  {
    git diff --name-only HEAD -- 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | sort -u | while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ -f "$f" ]; then
      printf '%s %s\n' "$(git hash-object -- "$f" 2>/dev/null)" "$f"
    else
      printf 'deleted %s\n' "$f"
    fi
  done
}

ci_blocked() {
  printf '%s' "$*" >"$CI_BLOCK_FILE"
  return 77
}

# ci_check <name> <required|optional> [--needs <name>]... -- <command...>
ci_check() {
  local name="$1" level="$2"
  shift 2
  local needs=()
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do
    case "$1" in
      --needs) needs+=("$2"); shift 2 ;;
      *) echo "ci_check: unexpected argument $1" >&2; return 2 ;;
    esac
  done
  [ "${1:-}" = "--" ] && shift
  local dep
  for dep in "${needs[@]}"; do
    if [ "$(ci_result_of "$dep")" != PASS ]; then
      _ci_record "$name" "$level" BLOCKED "needs '$dep' to pass first" 0
      return 0
    fi
  done
  local log
  log="$CI_LOG_DIR/$(printf '%s' "$name" | tr -c 'A-Za-z0-9._-' '_').log"
  rm -f "$CI_BLOCK_FILE"
  ci_log "RUN  $name"
  local t0 rc
  t0=$(date +%s)
  ( "$@" ) >"$log" 2>&1
  rc=$?
  local secs=$(($(date +%s) - t0))
  if [ $rc -eq 0 ]; then
    _ci_record "$name" "$level" PASS "" "$secs"
  elif [ $rc -eq 77 ]; then
    local reason="blocked"
    [ -f "$CI_BLOCK_FILE" ] && reason="$(cat "$CI_BLOCK_FILE")"
    if [ "$level" = optional ]; then
      _ci_record "$name" "$level" SKIPPED-OPTIONAL "$reason" "$secs"
    else
      _ci_record "$name" "$level" BLOCKED "$reason" "$secs"
    fi
  else
    _ci_record "$name" "$level" FAIL "exit $rc, log: $log" "$secs"
    echo "----- last 40 lines of $name -----"
    tail -n 40 "$log"
    echo "-----"
  fi
}

# For a check that cannot run on this machine at all (decided before running anything).
ci_skip() {
  local name="$1" level="$2" reason="$3"
  if [ "$level" = optional ]; then
    _ci_record "$name" "$level" SKIPPED-OPTIONAL "$reason" 0
  else
    _ci_record "$name" "$level" BLOCKED "$reason" 0
  fi
}

_ci_record() {
  CI_NAMES+=("$1")
  CI_LEVELS+=("$2")
  CI_RESULTS+=("$3")
  CI_NOTES+=("$4")
  CI_SECONDS+=("$5")
  local mark
  case "$3" in
    PASS) mark="$(_ci_green PASS)" ;;
    FAIL) mark="$(_ci_red FAIL)" ;;
    BLOCKED) mark="$(_ci_red BLOCKED)" ;;
    *) mark="$(_ci_yellow "$3")" ;;
  esac
  ci_log "$mark $1${4:+ ($4)}"
}

ci_result_of() {
  local i
  for i in "${!CI_NAMES[@]}"; do
    if [ "${CI_NAMES[$i]}" = "$1" ]; then
      printf '%s' "${CI_RESULTS[$i]}"
      return 0
    fi
  done
  printf 'MISSING'
}

# ci_need_cmd <command> <hint>: inside a check function, BLOCKED when a tool is missing.
ci_need_cmd() {
  command -v "$1" >/dev/null 2>&1 || ci_blocked "'$1' is not installed ($2)"
}

# ci_docker_ready: BLOCKED unless a Docker daemon answers.
ci_docker_ready() {
  command -v docker >/dev/null 2>&1 || { ci_blocked "docker is not installed"; return 77; }
  docker info >/dev/null 2>&1 || { ci_blocked "the Docker daemon is not running (start Docker Desktop / dockerd)"; return 77; }
}

# Converts a path for a docker bind mount (Git Bash on Windows needs a C:/ path and MSYS_NO_PATHCONV=1).
ci_docker_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

ci_docker_version() {
  local v
  v="$(docker info --format '{{.ServerVersion}}' 2>/dev/null)"
  printf '%s' "${v:-not running}"
}

# A Windows clone made before a .gitattributes rule (eol=lf or -text) keeps CRLF copies until those files are checked
# out again; formatters and byte-for-byte checks then fail for a reason that is not in the code.
ci_eol_check() {
  local stale
  stale="$(git ls-files --eol | awk '$1 == "i/lf" && $2 == "w/crlf" && ($3 ~ /eol=lf/ || $3 ~ /-text/) { print $NF }')"
  [ -z "$stale" ] && { echo "checkout line endings match .gitattributes"; return 0; }
  echo "These files are CRLF in this checkout but .gitattributes wants them as committed (LF):"
  printf '%s\n' "$stale" | sed 's/^/  /'
  echo "Refresh them (only if they have no local edits):"
  echo "  git rm -r -q --cached <path> && git checkout HEAD -- <path>"
  return 1
}

ci_os() {
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*) printf 'Windows (%s)' "$(uname -s)" ;;
    Darwin) printf 'macOS %s' "$(sw_vers -productVersion 2>/dev/null)" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then printf 'Linux (WSL) '; else printf 'Linux '; fi
      # shellcheck disable=SC1091
      (. /etc/os-release 2>/dev/null && printf '%s' "${PRETTY_NAME:-}")
      ;;
    *) uname -s ;;
  esac
}

# ci_finish <tool version lines...>: guard against changed files, print the summary, record --full, exit.
ci_finish() {
  # 1. The run must not have changed tracked files or added unignored files.
  local end_snapshot changed
  end_snapshot="$(_ci_snapshot)"
  changed="$(comm -13 <(printf '%s\n' "$CI_START_SNAPSHOT" | sort) <(printf '%s\n' "$end_snapshot" | sort) | sed 's/^[^ ]* //' | sort -u)"
  if [ -n "$changed" ]; then
    local n
    n="$(printf '%s\n' "$changed" | wc -l | tr -d ' ')"
    _ci_record "no files changed by the run" required FAIL \
      "$n changed: $(printf '%s\n' "$changed" | head -n 10 | tr '\n' ' ')$([ "$n" -gt 10 ] && echo '...')" 0
    echo "The run changed these files (format/codegen/contract drift?). Inspect with 'git diff', then commit or revert:"
    printf '%s\n' "$changed" | sed 's/^/  /'
  else
    _ci_record "no files changed by the run" required PASS "" 0
  fi

  # 2. Summary table.
  local failed=0 i total=$(($(date +%s) - CI_START_EPOCH))
  local head dirty="no"
  head="$(git rev-parse HEAD)"
  [ -n "$CI_START_SNAPSHOT" ] && dirty="yes"
  echo
  echo "## Local CI: $CI_REPO_NAME --$CI_MODE"
  echo
  echo "| Check | Level | Result | Time | Note |"
  echo "|---|---|---|---|---|"
  for i in "${!CI_NAMES[@]}"; do
    printf '| %s | %s | %s | %ss | %s |\n' "${CI_NAMES[$i]}" "${CI_LEVELS[$i]}" "${CI_RESULTS[$i]}" \
      "${CI_SECONDS[$i]}" "$(printf '%s' "${CI_NOTES[$i]}" | tr '|' '/')"
    if [ "${CI_LEVELS[$i]}" = required ] && { [ "${CI_RESULTS[$i]}" = FAIL ] || [ "${CI_RESULTS[$i]}" = BLOCKED ]; }; then
      failed=1
    fi
  done
  echo
  local verdict=PASS
  [ $failed -eq 0 ] || verdict=FAIL
  echo "- Verdict: **$verdict** (any required FAIL or BLOCKED fails the run)"
  echo "- Tested commit: \`$head\`$([ "$dirty" = yes ] && printf ' **plus uncommitted changes** (not a valid --full result)')"
  echo "- OS: $(ci_os)"
  local line
  for line in "$@"; do echo "- $line"; done
  echo "- Took ${total}s; logs: $CI_LOG_DIR"

  # 3. --full: the main it was tested against, recorded for scripts/merge-pr.sh.
  if [ "$CI_MODE" = full ]; then
    local main_sha="unknown" fetched=yes contains=no
    git fetch -q origin main 2>/dev/null || fetched=no
    main_sha="$(git rev-parse -q --verify origin/main 2>/dev/null || echo unknown)"
    if [ "$main_sha" != unknown ] && git merge-base --is-ancestor "$main_sha" HEAD 2>/dev/null; then contains=yes; fi
    echo "- main tested against: \`$main_sha\` (fetched now: $fetched; HEAD contains it: $contains)"
    [ "$contains" = yes ] || echo "- $(_ci_yellow WARNING): HEAD does not contain origin/main. Merge main and run --full again before merging."
    local state_dir
    state_dir="$(git rev-parse --git-path ci-local)"
    mkdir -p "$state_dir"
    {
      echo "verdict=$verdict"
      echo "head=$head"
      echo "main=$main_sha"
      echo "contains_main=$contains"
      echo "dirty=$dirty"
      echo "date=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo "common_version=$CI_COMMON_VERSION"
    } >"$state_dir/last-full.env"
    echo "- Recorded in $state_dir/last-full.env"
  fi
  [ $failed -eq 0 ]
  exit $?
}

ci_usage() {
  cat <<EOF
Usage: scripts/ci-local.sh --fast | --full [options]
  --fast   format, lint, typecheck/analyze and fast unit tests (run before every push)
  --full   everything the old GitHub CI ran (run on the exact merge result before merging)
$1
Results: PASS, FAIL, BLOCKED (required but cannot run here), SKIPPED-OPTIONAL. Exit 1 if any required check is FAIL
or BLOCKED. Policy: AGENTS.md. Hook: scripts/install-hooks.sh.
EOF
}
