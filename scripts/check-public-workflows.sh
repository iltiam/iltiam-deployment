#!/usr/bin/env bash
# This repository is public, so every Actions log, artifact and cache it makes is public too. This check holds every
# workflow in .github/workflows to the rules that keep secrets, env values and the private app repositories' code out
# of them (Runbook 9, section 9). scripts/ci-local.sh and env-check.yml run it.
#
# Usage:
#   scripts/check-public-workflows.sh              check this repository
#   scripts/check-public-workflows.sh --self-test  also prove that each rule refuses a workflow that breaks it
#
# The rules (full-line comments are ignored; the file and line of a finding are printed, never more):
#   triggers   no pull_request_target or workflow_run (they run with this repository's secrets on events others can
#              cause); a workflow with a pull_request trigger uses no secret and no Environment
#   secrets    never toJSON(secrets); each secret by name. A step that runs scripts/render-deploy-env.sh lists every
#              secret the env templates take (and FCM_SERVICE_ACCOUNT_JSON) as DEPLOY_SECRET_<NAME>: ${{ secrets.<NAME> }}
#              and nothing else under that prefix. APP_SOURCE_TOKEN (read access to the private app repositories)
#              only as GH_TOKEN, for `gh`
#   output     no set -x / bash -x / xtrace, no printenv or a bare `env`, no GH_DEBUG / ACTIONS_STEP_DEBUG
#   storage    no actions/upload-artifact or download-artifact (anyone signed in can download a public repository's
#              artifacts), no actions/cache or buildx type=gha cache (a fork's pull request workflow can restore
#              main's caches), no docker/build-push-action (its build record artifact and summary hold the
#              Dockerfile and the build log)
#   private    no `repository:` or `token:` input (actions/checkout of a private repository prints its commit message);
#              no docker build in a workflow: images are built by scripts/auto-deploy.sh, whose build runs with
#              --progress=quiet and its output in a file
#   login      `docker login` with --password-stdin only, in workflows and scripts
#
# Needs bash, grep, awk. Prints rule names, file names and line numbers only.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

# The names of every secret the env templates take, in either environment, plus the FCM file's secret.
expected_secrets() {
  local r="$1" env template
  {
    for env in staging production; do
      for template in "$r"/env/*.env.example; do
        bash "$r/scripts/render-env.sh" --list "$env" "$template" | awk '$1 == "secret" { print $3 }'
      done
    done
    echo FCM_SERVICE_ACCOUNT_JSON
  } | tr -d '\r' | sort -u
}

# check <repository root>: prints the findings, returns 1 if there is any.
check() {
  local r="$1" findings=0 f rel code n name count expected secrets_used
  report() {
    printf '    FAIL [%s] %s\n' "$1" "$2"
    findings=$((findings + 1))
  }
  # The numbers of the lines of $1 that match the ERE $2, full-line comments left out.
  lines() {
    { tr -d '\r' <"$1" | grep -nE "$2" || true; } | grep -vE '^[0-9]+:[[:space:]]*#' | cut -d: -f1 | tr '\n' ' ' || true
  }

  # The self-test's copies have the same templates: worked out once (each name costs a render-env.sh run).
  if [[ -z "${EXPECTED_SECRETS:-}" ]]; then
    EXPECTED_SECRETS="$(expected_secrets "$r")"
  fi
  expected="$EXPECTED_SECRETS"
  [[ -n "$expected" ]] || die "no secret names from the env templates"

  shopt -s nullglob
  local workflows=("$r"/.github/workflows/*.yml "$r"/.github/workflows/*.yaml)
  ((${#workflows[@]} > 0)) || die "no workflows under $r/.github/workflows"
  for f in "${workflows[@]}"; do
    rel="${f#"$r"/}"
    code="$(awk '!/^[[:space:]]*#/' "$f" | tr -d '\r')"

    # triggers
    n="$(lines "$f" '(^|[^A-Za-z_])(pull_request_target|workflow_run)([^A-Za-z_]|$)')"
    [[ -z "$n" ]] || report triggers "$rel: pull_request_target or workflow_run (lines $n)"
    if grep -Eq '(^|[[:space:][,])pull_request([[:space:]:,]|\]|$)' <<<"$code"; then
      n="$(lines "$f" 'secrets\.|^[[:space:]]*environment:')"
      [[ -z "$n" ]] || report triggers "$rel: a pull_request workflow that uses a secret or an Environment (lines $n)"
    fi

    # secrets
    n="$(lines "$f" '[Tt][Oo][Jj][Ss][Oo][Nn][[:space:]]*\([[:space:]]*secrets[[:space:]]*\)')"
    [[ -z "$n" ]] || report secrets "$rel: toJSON(secrets) (lines $n); list each secret by name"
    n="$(lines "$f" 'secrets\.APP_SOURCE_TOKEN' | tr ' ' '\n' | while read -r l; do
      [[ -n "$l" ]] || continue
      sed -n "${l}p" "$f" | grep -Eq '^[[:space:]]*GH_TOKEN:[[:space:]]*\$\{\{[[:space:]]*secrets\.APP_SOURCE_TOKEN[[:space:]]*\}\}[[:space:]]*$' \
        || printf '%s ' "$l"
    done)"
    [[ -z "$n" ]] || report secrets "$rel: APP_SOURCE_TOKEN other than as 'GH_TOKEN: \${{ secrets.APP_SOURCE_TOKEN }}' (lines $n)"
    # DEPLOY_SECRET_<NAME>: ${{ secrets.<NAME> }}, the same name on both sides, and a name the templates know.
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      if [[ "$line" =~ ^[[:space:]]*DEPLOY_SECRET_([A-Z0-9_]+):[[:space:]]*\$\{\{[[:space:]]*secrets\.([A-Z0-9_]+)[[:space:]]*\}\}[[:space:]]*$ ]]; then
        [[ "${BASH_REMATCH[1]}" == "${BASH_REMATCH[2]}" ]] \
          || report secrets "$rel: DEPLOY_SECRET_${BASH_REMATCH[1]} is given secrets.${BASH_REMATCH[2]}"
        grep -qx "${BASH_REMATCH[1]}" <<<"$expected" \
          || report secrets "$rel: DEPLOY_SECRET_${BASH_REMATCH[1]}: no env template takes that secret"
      else
        report secrets "$rel: a DEPLOY_SECRET_ line that is not 'DEPLOY_SECRET_<NAME>: \${{ secrets.<NAME> }}'"
      fi
    done < <(grep -E '^[[:space:]]*DEPLOY_SECRET_' <<<"$code" || true)
    count="$(grep -Ec '^[[:space:]]*(run:[[:space:]]*)?bash scripts/render-deploy-env\.sh' <<<"$code" || true)"
    if ((count > 0)); then
      while IFS= read -r name; do
        n="$(grep -Ec "^[[:space:]]*DEPLOY_SECRET_${name}:[[:space:]]*\\\$\{\{[[:space:]]*secrets\.${name}[[:space:]]*\}\}" <<<"$code" || true)"
        ((n == count)) || report secrets "$rel: DEPLOY_SECRET_$name is listed $n time(s) for $count render step(s)"
      done <<<"$expected"
    fi

    # output
    n="$(lines "$f" 'set[[:space:]]+-[A-Za-z]*x|bash[[:space:]]+-[A-Za-z]*x|xtrace')"
    [[ -z "$n" ]] || report output "$rel: set -x / bash -x / xtrace (lines $n)"
    n="$(lines "$f" '(^|[^A-Za-z_-])printenv([^A-Za-z_-]|$)|^[[:space:]]*(run:[[:space:]]*)?env[[:space:]]*($|[|>;&])')"
    [[ -z "$n" ]] || report output "$rel: printenv or a bare env (lines $n)"
    n="$(lines "$f" 'GH_DEBUG|ACTIONS_STEP_DEBUG|ACTIONS_RUNNER_DEBUG')"
    [[ -z "$n" ]] || report output "$rel: debug logging (lines $n)"

    # storage
    n="$(lines "$f" 'actions/(upload|download)-artifact|actions/cache|type=gha|docker/build-push-action')"
    [[ -z "$n" ]] || report storage "$rel: an artifact, a cache or docker/build-push-action (lines $n)"

    # private
    n="$(lines "$f" '^[[:space:]]*(repository|token):')"
    [[ -z "$n" ]] || report private "$rel: a repository: or token: input (lines $n); private code comes as a tarball (scripts/auto-deploy.sh)"
    n="$(lines "$f" 'docker[[:space:]]+(buildx[[:space:]]+)?build([[:space:]]|$)')"
    [[ -z "$n" ]] || report private "$rel: a docker build in the workflow (lines $n); use scripts/auto-deploy.sh build"

    # login
    n="$(lines "$f" 'docker[[:space:]]+login' | tr ' ' '\n' | while read -r l; do
      [[ -n "$l" ]] || continue
      sed -n "${l}p" "$f" | grep -q -- '--password-stdin' || printf '%s ' "$l"
    done)"
    [[ -z "$n" ]] || report login "$rel: docker login without --password-stdin (lines $n)"
  done

  # login, in the scripts too (not this one: its self-test holds a bad example on purpose)
  for f in "$r"/scripts/*.sh "$r"/scripts/lib/*.sh; do
    rel="${f#"$r"/}"
    [[ "$rel" != scripts/check-public-workflows.sh ]] || continue
    n="$(lines "$f" 'docker[[:space:]]+login' | tr ' ' '\n' | while read -r l; do
      [[ -n "$l" ]] || continue
      sed -n "${l}p" "$f" | grep -q -- '--password-stdin' || printf '%s ' "$l"
    done)"
    [[ -z "$n" ]] || report login "$rel: docker login without --password-stdin (lines $n)"
  done

  # private: the one place that builds an image from private code
  f="$r/scripts/auto-deploy.sh"
  if [[ -f "$f" ]]; then
    grep -Eq '^[^#]*--progress=quiet' "$f" || report private "scripts/auto-deploy.sh: the build must run with --progress=quiet"
    # A build command: `docker buildx build` before any quote on its line (a message that quotes the command is not one).
    # shellcheck disable=SC2016 # the $ is literal: the script's own text
    n="$(lines "$f" '^[^"#]*docker[[:space:]]+buildx[[:space:]]+build' | tr ' ' '\n' | while read -r l; do
      [[ -n "$l" ]] || continue
      sed -n "${l}p" "$f" | grep -Eq '>"\$work/build\.log" 2>&1' || printf '%s ' "$l"
    done)"
    [[ -z "$n" ]] || report private "scripts/auto-deploy.sh: a build whose output is not sent to \$work/build.log (lines $n)"
    secrets_used="$(lines "$f" 'set[[:space:]]+-[A-Za-z]*x|xtrace')"
    [[ -z "$secrets_used" ]] || report output "scripts/auto-deploy.sh: set -x / xtrace (lines $secrets_used)"
  fi

  ((findings == 0))
}

# --- self-test: each rule refuses a workflow that breaks it -----------------------------------------------------

# The samples below are workflow text: their ${{ }} and $ are literal on purpose.
# shellcheck disable=SC2016
self_test() {
  local work case_name failed=0
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' RETURN
  # A good workflow: deploy.yml from this repository, which passes.
  mk() {
    rm -rf "$work/r"
    mkdir -p "$work/r/.github/workflows"
    cp -r "$root/env" "$root/scripts" "$work/r/"
    cp "$root/.github/workflows/deploy.yml" "$work/r/.github/workflows/"
  }
  # $1 a name, $2 a sed expression applied to deploy.yml, or "+<file>" with the content in $3 (a new workflow).
  bad() {
    case_name="$1"
    mk
    if [[ "$2" == +* ]]; then
      printf '%s\n' "$3" >"$work/r/.github/workflows/${2#+}"
    else
      sed -i "$2" "$work/r/.github/workflows/deploy.yml"
    fi
    if check "$work/r" >/dev/null 2>&1; then
      printf '    FAIL self-test: not refused: %s\n' "$case_name"
      failed=$((failed + 1))
    else
      printf '    ok: refused: %s\n' "$case_name"
    fi
  }
  mk
  check "$work/r" >/dev/null || { printf '    FAIL self-test: the unchanged deploy.yml is refused\n'; return 1; }
  printf '    ok: the unchanged deploy.yml passes\n'
  bad "toJSON(secrets)" 's/^\(\s*\)VARS_JSON: .*/&\n\1SECRETS_JSON: ${{ toJSON(secrets) }}/'
  bad "a template secret missing from the list" '/DEPLOY_SECRET_AI_SERVICE_TOKEN:/d'
  bad "a DEPLOY_SECRET_ given another secret" 's/DEPLOY_SECRET_SECRET_KEY: .*/DEPLOY_SECRET_SECRET_KEY: ${{ secrets.JWT_SECRET_KEY }}/'
  bad "a DEPLOY_SECRET_ no template takes" 's/^\(\s*\)VARS_JSON: .*/&\n\1DEPLOY_SECRET_NOT_A_SECRET: ${{ secrets.NOT_A_SECRET }}/'
  bad "set -x" 's/^\(\s*\)run: bash scripts\/remote-deploy.sh/\1run: set -x; bash scripts\/remote-deploy.sh/'
  bad "docker login with a password argument" 's/^\(\s*\)run: bash scripts\/remote-deploy.sh/\1run: docker login ghcr.io -u x -p "$GHCR_TOKEN"; bash scripts\/remote-deploy.sh/'
  bad "printenv" 's/^\(\s*\)run: bash scripts\/remote-deploy.sh/\1run: printenv; bash scripts\/remote-deploy.sh/'
  bad "a checkout with a token" 's/^\(\s*\)persist-credentials: false/\1token: ${{ secrets.APP_SOURCE_TOKEN }}/'
  bad "workflow_run" 's/^  workflow_dispatch:/  workflow_run:\n    workflows: [x]\n  workflow_dispatch:/'
  bad "pull_request with a secret" +pr.yml 'name: pr
on:
  pull_request:
jobs:
  a:
    runs-on: ubuntu-24.04
    steps:
      - run: test -n "$T"
        env:
          T: ${{ secrets.DEPLOY_HOST }}'
  bad "an artifact" +art.yml 'name: art
on: workflow_dispatch
jobs:
  a:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/upload-artifact@v4
        with: { name: x, path: x }'
  bad "a buildx gha cache" +cache.yml 'name: cache
on: workflow_dispatch
jobs:
  a:
    runs-on: ubuntu-24.04
    steps:
      - run: bash scripts/x.sh --cache-to type=gha'
  bad "a docker build in a workflow" +build.yml 'name: build
on: workflow_dispatch
jobs:
  a:
    runs-on: ubuntu-24.04
    steps:
      - run: docker buildx build .'
  bad "APP_SOURCE_TOKEN other than as GH_TOKEN" +tok.yml 'name: tok
on: workflow_dispatch
jobs:
  a:
    runs-on: ubuntu-24.04
    steps:
      - run: true
        env:
          TOKEN: ${{ secrets.APP_SOURCE_TOKEN }}'
  # The build's output: printed instead of kept in its file.
  case_name="a build whose output is printed"
  mk
  sed -i 's#>"\$work/build\.log" 2>&1##' "$work/r/scripts/auto-deploy.sh"
  if check "$work/r" >/dev/null 2>&1; then
    printf '    FAIL self-test: not refused: %s\n' "$case_name"
    failed=$((failed + 1))
  else
    printf '    ok: refused: %s\n' "$case_name"
  fi
  ((failed == 0))
}

case "${1:-}" in
  "") ;;
  --self-test) ;;
  *) die "usage: $0 [--self-test]" ;;
esac

echo "==> public workflow rules (.github/workflows, scripts)"
if ! check "$root"; then
  die "the workflows break the public-log rules above (see this script's header)"
fi
echo "    ok: every workflow and script follows the rules"
if [[ "${1:-}" == --self-test ]]; then
  echo "==> self-test: each rule refuses a workflow that breaks it"
  self_test || die "the self-test failed"
fi
