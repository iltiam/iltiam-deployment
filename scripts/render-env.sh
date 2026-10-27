#!/usr/bin/env bash
# Render one env file from a template in env/ and the GitHub Environment's secrets and variables.
# Runbook: docs/runbooks/04-secrets.md. The deploy workflows (DEP-03, DEP-04) call it; CI calls it with dummies.
#
# Usage:
#   render-env.sh <staging|production> <template> <output>   write the env file (mode 600)
#   render-env.sh --list <staging|production> <template>      print "kind must|may NAME" for what that env takes
#
# Each value comes from the environment variable of the same name, never from an argument, so values don't show
# up in `ps` or in an Actions log. This script prints names only, never a value.
#
# The template's comment line above each variable sets its kind (secret|var) and need:
#   required        every environment must have it
#   prod-required   production must have it; staging may leave it out
#   optional        left out of the file when unset (an empty NAME= would break typed settings such as env.int)
#   staging-only    staging may have it; production refuses it, so it must not be set there at all
#
# Values are written single-quoted: Compose then takes them literally, and a `$` in a third-party password is not
# interpolated. A value containing a single quote, a carriage return or a newline is refused. The output is for
# Docker Compose (env_file / --env-file) only; `docker run --env-file` would keep the quotes.

set -euo pipefail

TAG_RE='^# (secret|var), (required|prod-required|optional|staging-only): .+'
NAME_RE='^([A-Z][A-Z0-9_]*)=(.*)$'

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  die "usage: $0 <staging|production> <template> <output>  |  $0 --list <staging|production> <template>"
}

check_env_name() {
  [[ "$1" == staging || "$1" == production ]] || die "environment must be staging or production, got '$1'"
}

# Print "kind need NAME" for each variable of the template; stop on anything malformed.
parse_template() {
  local file="$1" line kind="" need="" lineno=0 name
  local -A seen=()
  [[ -f "$file" ]] || die "template not found: $file"
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    line="${line%$'\r'}"
    if [[ "$line" =~ $TAG_RE ]]; then
      [[ -z "$kind" ]] || die "$file:$lineno: two '# kind, need:' lines in a row"
      kind="${BASH_REMATCH[1]}"
      need="${BASH_REMATCH[2]}"
    elif [[ "$line" =~ $NAME_RE ]]; then
      name="${BASH_REMATCH[1]}"
      [[ -z "${BASH_REMATCH[2]}" ]] || die "$file:$lineno: $name has a value; templates hold none"
      [[ -n "$kind" ]] || die "$file:$lineno: $name has no '# kind, need: ...' line right above it"
      [[ -z "${seen[$name]:-}" ]] || die "$file:$lineno: $name appears twice"
      seen[$name]=1
      printf '%s %s %s\n' "$kind" "$need" "$name"
      kind=""
      need=""
    elif [[ -n "$kind" ]]; then
      die "$file:$lineno: a '# kind, need:' line must be followed directly by its variable"
    elif [[ -n "$line" && "$line" != \#* ]]; then
      die "$file:$lineno: expected a comment, a blank line or NAME="
    fi
  done <"$file"
  [[ -z "$kind" ]] || die "$file: ends with a '# kind, need:' line but no variable"
}

# must | may | forbidden, for a need in an environment.
rule() {
  local env="$1" need="$2"
  case "$need" in
    required) echo must ;;
    prod-required) [[ "$env" == production ]] && echo must || echo may ;;
    optional) echo may ;;
    staging-only) [[ "$env" == staging ]] && echo may || echo forbidden ;;
  esac
}

list() {
  local env="$1" template="$2" entries kind need name r
  entries="$(parse_template "$template")"
  while read -r kind need name; do
    [[ -n "$name" ]] || continue
    r="$(rule "$env" "$need")"
    [[ "$r" == forbidden ]] || printf '%s %s %s\n' "$kind" "$r" "$name"
  done <<<"$entries"
}

render() {
  local env="$1" template="$2" output="$3" entries kind need name r value
  local missing=() forbidden=() unsafe=() written=0 skipped=0
  entries="$(parse_template "$template")"
  umask 077
  tmp="$(mktemp "${output}.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT
  {
    printf '# Rendered by scripts/render-env.sh from %s for %s. Do not edit, print or commit.\n' \
      "$(basename "$template")" "$env"
    while read -r kind need name; do
      [[ -n "$name" ]] || continue
      r="$(rule "$env" "$need")"
      value="${!name:-}"
      if [[ -z "$value" ]]; then
        if [[ "$r" == must ]]; then missing+=("$name"); else skipped=$((skipped + 1)); fi
        continue
      fi
      if [[ "$r" == forbidden ]]; then
        forbidden+=("$name")
      elif [[ "$value" == *"'"* || "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
        unsafe+=("$name")
      else
        printf "%s='%s'\n" "$name" "$value"
        written=$((written + 1))
      fi
    done <<<"$entries"
  } >"$tmp"

  local failed=0
  if ((${#missing[@]})); then
    printf 'ERROR: %s: not set for %s: %s\n' "$template" "$env" "${missing[*]}" >&2
    failed=1
  fi
  if ((${#forbidden[@]})); then
    printf 'ERROR: %s: must not be set for %s: %s\n' "$template" "$env" "${forbidden[*]}" >&2
    failed=1
  fi
  if ((${#unsafe[@]})); then
    printf "ERROR: %s: value contains a single quote or a line break: %s\n" "$template" "${unsafe[*]}" >&2
    failed=1
  fi
  ((failed == 0)) || exit 1

  chmod 600 "$tmp"
  mv -f "$tmp" "$output"
  trap - EXIT
  printf 'wrote %s: %d set, %d optional left out\n' "$output" "$written" "$skipped"
}

if [[ "${1:-}" == --list ]]; then
  [[ $# -eq 3 ]] || usage
  check_env_name "$2"
  list "$2" "$3"
else
  [[ $# -eq 3 ]] || usage
  check_env_name "$1"
  render "$1" "$2" "$3"
fi
