#!/usr/bin/env bash
# Local CI for iltiam-deployment: replaces .github/workflows/env-check.yml and docs.yml (both kept, disabled), plus a
# deploy preflight. deploy.yml is replaced by scripts/deploy-staging.sh / deploy-prod.sh (by hand, never automatic).
# Policy: AGENTS.md.
#   scripts/ci-local.sh --fast   shellcheck, check-env.sh, check-compose.sh, both versions files, gitleaks (history)
#   scripts/ci-local.sh --full   plus MkDocs strict and the deploy dry-runs' offline preflight
# THIS REPOSITORY IS PUBLIC. Nothing here prints a secret: `docker compose config` only with --quiet (inside the
# checks), gitleaks only with --redact, no `set -x`.
# Tools: bash, jq, openssl, the Docker Compose plugin (daemon not needed for the env/compose checks). shellcheck and
# gitleaks run natively when installed at the pinned version, else from their pinned images (needs the daemon).
set -u
cd "$(dirname "$0")/.." || exit 2
# shellcheck source=lib/ci-common.sh disable=SC1091
. scripts/lib/ci-common.sh

SHELLCHECK_VERSION="0.9.0"                               # ubuntu-24.04's apt package, what env-check.yml ran
SHELLCHECK_IMAGE="koalaman/shellcheck:v$SHELLCHECK_VERSION"
GITLEAKS_VERSION="8.30.1"                                # env-check.yml
GITLEAKS_IMAGE="ghcr.io/gitleaks/gitleaks:v$GITLEAKS_VERSION"
PY_PINNED="3.12"                                         # docs.yml

ci_init iltiam-deployment "$@"
if [ "$CI_MODE" = help ] || [ -z "$CI_MODE" ]; then
  ci_usage ""
  exit 0
fi
[ ${#CI_ARGS[@]} -eq 0 ] || { echo "unknown option: ${CI_ARGS[*]}" >&2; exit 2; }

PYTHON="${PYTHON:-}"
if [ -z "$PYTHON" ]; then
  for p in python3 python; do
    command -v "$p" >/dev/null 2>&1 && "$p" -c 'import sys' 2>/dev/null && { PYTHON="$p"; break; }
  done
fi

run_shellcheck() {
  # Same file list as env-check.yml.
  local files
  files=$(ls scripts/*.sh postgres/initdb/*.sh scripts/lib/*.sh 2>/dev/null)
  if command -v shellcheck >/dev/null 2>&1 && shellcheck --version | grep -q "version: $SHELLCHECK_VERSION\$"; then
    # shellcheck disable=SC2086
    shellcheck $files
  else
    ci_docker_ready || { ci_blocked "shellcheck $SHELLCHECK_VERSION not installed and no Docker daemon for $SHELLCHECK_IMAGE"; return; }
    # shellcheck disable=SC2086
    MSYS_NO_PATHCONV=1 docker run --rm -v "$(ci_docker_path "$PWD"):/mnt" -w /mnt "$SHELLCHECK_IMAGE" $files
  fi
}

compose_tools() {
  ci_need_cmd jq "jq 1.6+" || return
  ci_need_cmd openssl "openssl" || return
  docker compose version >/dev/null 2>&1 || ci_blocked "the Docker Compose plugin is not installed" || return
  docker compose version
}

run_gitleaks() {
  if command -v gitleaks >/dev/null 2>&1 && gitleaks version 2>/dev/null | grep -q "$GITLEAKS_VERSION"; then
    gitleaks git . --redact --no-banner --verbose
  else
    ci_docker_ready || { ci_blocked "gitleaks $GITLEAKS_VERSION not installed and no Docker daemon for $GITLEAKS_IMAGE"; return; }
    MSYS_NO_PATHCONV=1 docker run --rm -v "$(ci_docker_path "$PWD"):/repo" "$GITLEAKS_IMAGE" git /repo --redact --no-banner --verbose
  fi
}

mkdocs_strict() {
  [ -n "$PYTHON" ] || ci_blocked "no Python $PY_PINNED (docs.yml)" || return
  local v
  v="$("$PYTHON" -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
  echo "python $v (docs.yml: $PY_PINNED)"
  # Every pin in docs/requirements.txt must be the installed version.
  "$PYTHON" - <<'EOF' || { echo "Run: $PYTHON -m pip install -r docs/requirements.txt"; return 1; }
import importlib.metadata as m, re, sys
bad = []
for line in open("docs/requirements.txt", encoding="utf-8"):
    line = line.split("#")[0].strip()
    if not line:
        continue
    name, _, want = line.partition("==")
    try:
        have = m.version(name)
    except m.PackageNotFoundError:
        have = None
    if have != want:
        bad.append(f"{name}: want {want}, have {have}")
print("\n".join(bad) or "docs/requirements.txt pins installed")
sys.exit(1 if bad else 0)
EOF
  "$PYTHON" -m mkdocs build --strict --site-dir "$CI_LOG_DIR/site"
}

deploy_preflight() {
  local env
  for env in staging production; do
    bash scripts/deploy.sh --check-versions "$env" || return 1
  done
  bash scripts/deploy-staging.sh --dry-run --offline || return 1
  bash scripts/deploy-prod.sh --dry-run --offline || return 1
}

ci_check "shellcheck" required -- run_shellcheck
ci_check "Compose tools (jq, openssl, compose)" required -- compose_tools
ci_check "check-env.sh (lint, dummy render, compose config)" required --needs "Compose tools (jq, openssl, compose)" -- bash scripts/check-env.sh
ci_check "check-compose.sh (networks, ports, limits, secrets)" required --needs "Compose tools (jq, openssl, compose)" -- bash scripts/check-compose.sh
ci_check "versions files (staging, production)" required -- bash -c 'bash scripts/deploy.sh --check-versions staging && bash scripts/deploy.sh --check-versions production'
ci_check "gitleaks (full history, redacted)" required -- run_gitleaks

if [ "$CI_MODE" = full ]; then
  ci_check "MkDocs strict build" required -- mkdocs_strict
  ci_check "deploy preflight (dry-run, offline)" required -- deploy_preflight
fi

ci_finish "Docker Compose: $(docker compose version --short 2>/dev/null || echo none)" "jq: $(jq --version 2>/dev/null)" \
  "Python: $("${PYTHON:-python}" --version 2>&1)" \
  "Docker daemon: $(ci_docker_version)"
