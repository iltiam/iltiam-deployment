#!/usr/bin/env bash
# The steps of the automatic staging deploy (.github/workflows/auto-deploy-staging.yml; Runbook 9, version 2), on the
# GitHub runner. Nothing here runs on the VM: scripts/remote-deploy.sh does that.
#
#   heads                         ONLY, PIN_SHA, GH_TOKEN (APP_SOURCE_TOKEN): the commit each app repository's main is
#                                 at (or PIN_SHA, after checking it is on that main). Prints heads=<JSON>.
#   plan <status file> <heads>    MODE, RETRY_FAILED; logged in to GHCR: what to build and what to deploy. The status
#                                 file is what `remote-deploy.sh --status staging` printed. Prints build=<JSON> and
#                                 deploy=<JSON>, writes a table to the job summary.
#   build <service> <sha>         GH_TOKEN, GHCR_USER, GHCR_TOKEN: that commit's source as a tarball, its linux/arm64
#                                 image(s) built and pushed as sha-<7>, then checked on GHCR.
#   published <service> <tag>     logged in to GHCR: are that tag's images on GHCR with linux/arm64? Prints ready=.
#   prepare <service> <sha> <status file>
#                                 In this repository's checkout (the workflow's commit of main): commit the base
#                                 (env/staging.versions = what the VM runs) and the target (plus the new tag). Pushes
#                                 nothing. Prints previous=, tag=, changed=, base=, target=.
#   push                          Force-push HEAD to the auto/staging branch, with a lease.
#   mark-failed <service> <tag> <commit>   Tag auto-failed/<service>/<tag>: the next runs skip it.
#   clear-failed <service> <tag>  Remove that tag, if it is there.
#   check-built <builds JSON>     After a failed build job: mark-failed every planned build that is not on GHCR.
#
# heads, plan, published and prepare print only their NAME=value lines on stdout (the workflow appends them to
# $GITHUB_OUTPUT); everything else goes to stderr.
#
# The order of the services is the order they deploy in: ai, then backend (it calls the AI service), then web (it
# calls the backend).
#
# THIS REPOSITORY IS PUBLIC, SO THE WORKFLOW'S LOG IS PUBLIC; THE APP REPOSITORIES ARE PRIVATE. This prints service
# names, sha-<7> tags, image names and states, which env/staging.versions publishes anyway. The source arrives as a
# tarball (git would print commit messages); the build's own output goes to a file that is never printed, because
# docker quotes the Dockerfile and the failing command's output in it. Never `set -x` here.

set -euo pipefail

SERVICES=(ai backend web)
OWNER=iltiam
REGISTRY=ghcr.io/iltiam
AUTO_BRANCH=auto/staging

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

note() { printf '    %s\n' "$*" >&2; }

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
summary="${GITHUB_STEP_SUMMARY:-/dev/null}"

check_service() { [[ "$1" =~ ^(ai|backend|web)$ ]] || die "the service must be ai, backend or web, got '$1'"; }
check_sha() { [[ "$1" =~ ^[0-9a-f]{40}$ ]] || die "expected a full 40-character commit hash"; }
check_tag() { [[ "$1" =~ ^sha-[0-9a-f]{7}$ ]] || die "the tag must be sha-<7>, got '$1'"; }

repo_of() {
  case "$1" in
    ai) echo iltiam-ai-service ;;
    backend) echo iltiam-backend ;;
    web) echo iltiam-web ;;
  esac
}

# image:target, one word per image. The same targets and contexts as scripts/publish-image.sh.
builds_of() {
  case "$1" in
    ai) echo "iltiam-ai-api:api iltiam-ai-worker:worker" ;;
    backend) echo "iltiam-backend:runtime" ;;
    web) echo "iltiam-web:" ;;
  esac
}

context_of() {
  if [[ "$1" == web ]]; then echo web; else echo .; fi
}

# The container whose image says which build of the service runs.
container_of() {
  case "$1" in
    ai) echo ai-api ;;
    backend) echo backend-web ;;
    web) echo web ;;
  esac
}

# ai always runs; backend and web only with their profile on in env/staging.versions.
profile_on() {
  local profiles
  [[ "$1" == ai ]] && return 0
  profiles="$(sed -n 's/^COMPOSE_PROFILES=//p' "$repo_root/env/staging.versions" | tr -d '\r' | tail -n 1)"
  [[ ",$profiles," == *",$1,"* ]]
}

# The tag a service runs, from the status lines "<compose service> <image:tag> <state>", or "none" without a container.
running_tag() {
  local image
  image="$(awk -v s="$(container_of "$2")" '$1 == s { print $2; exit }' "$1")"
  if [[ -n "$image" ]]; then printf '%s' "${image##*:}"; else printf none; fi
}

# Is this image on GHCR with linux/arm64? An index (multi-arch, or with an attestation) or a single manifest.
image_has_arm64() {
  local raw
  raw="$(docker buildx imagetools inspect --raw "$1" 2>/dev/null)" || return 1
  if jq -e 'has("manifests")' >/dev/null 2>&1 <<<"$raw"; then
    jq -e '[.manifests[]?.platform.architecture] | index("arm64") != null' >/dev/null <<<"$raw"
  else
    docker buildx imagetools inspect "$1" --format '{{json .Image}}' 2>/dev/null \
      | jq -e '.architecture == "arm64"' >/dev/null
  fi
}

# Every image of the service at this tag is on GHCR with linux/arm64.
published() {
  local entry
  for entry in $(builds_of "$1"); do
    image_has_arm64 "$REGISTRY/${entry%%:*}:$2" || return 1
  done
}

git_bot() {
  git -C "$repo_root" config user.name 'github-actions[bot]'
  git -C "$repo_root" config user.email '41898282+github-actions[bot]@users.noreply.github.com'
}

# --- heads ------------------------------------------------------------------------------------------------------

cmd_heads() {
  [[ $# -eq 0 ]] || die "usage: $0 heads"
  local only="${ONLY:-all}" pin="${PIN_SHA:-}" svc repo sha status out='{}'
  [[ "$only" =~ ^(all|ai|backend|web)$ ]] || die "only must be all, ai, backend or web, got '$only'"
  if [[ -n "$pin" ]]; then
    [[ "$only" != all ]] || die "a sha needs one service in 'only'"
    check_sha "$pin"
  fi
  [[ -n "${GH_TOKEN:-}" ]] || die "GH_TOKEN is empty: the app-source Environment's APP_SOURCE_TOKEN secret is not set (Runbook 9, section 2)"
  command -v gh >/dev/null 2>&1 || die "the gh CLI is missing on this runner"
  echo "==> the app repositories' main" >&2
  for svc in "${SERVICES[@]}"; do
    [[ "$only" == all || "$only" == "$svc" ]] || continue
    repo="$(repo_of "$svc")"
    if [[ -n "$pin" ]]; then
      # compare/<pin>...main: "ahead" (main is ahead of it) or "identical" means the commit is on main.
      status="$(gh api "repos/$OWNER/$repo/compare/$pin...main" --jq .status 2>/dev/null)" \
        || die "could not compare ${pin:0:7} with $repo main (no such commit, or APP_SOURCE_TOKEN can't read $repo)"
      [[ "$status" == ahead || "$status" == identical ]] || die "${pin:0:7} is not on $repo main ($status)"
      sha="$pin"
    else
      sha="$(gh api "repos/$OWNER/$repo/commits/main" --jq .sha 2>/dev/null)" \
        || die "could not read $repo main: is APP_SOURCE_TOKEN expired, or without Contents: Read on $repo?"
    fi
    check_sha "$sha"
    out="$(jq -c --arg s "$svc" --arg v "$sha" '. + {($s): $v}' <<<"$out")"
    note "$repo: sha-${sha:0:7}$([[ -n "$pin" ]] && echo ' (chosen by hand, on main)')"
  done
  printf 'heads=%s\n' "$out"
}

# --- plan -------------------------------------------------------------------------------------------------------

cmd_plan() {
  [[ $# -eq 2 && -f "$1" ]] || die "usage: $0 plan <status file> <heads JSON>"
  local status="$1" heads="$2" mode="${MODE:-}" retry="${RETRY_FAILED:-false}"
  local failed svc sha tag running action item build='[]' deploy='[]'
  [[ "$mode" =~ ^(plan|build|deploy)$ ]] || die "MODE must be plan, build or deploy, got '$mode'"
  jq -e 'type == "object"' >/dev/null 2>&1 <<<"$heads" || die "the heads are not a JSON object"
  failed="$(git -C "$repo_root" ls-remote --tags origin 'refs/tags/auto-failed/*' | awk '{ print $2 }')" \
    || die "could not list the auto-failed tags"

  echo "==> plan (mode: $mode)" >&2
  {
    echo "### Staging against main (mode: $mode)"
    echo
    echo "| Service | Staging runs | main | Action |"
    echo "|---|---|---|---|"
  } >>"$summary"
  for svc in "${SERVICES[@]}"; do
    sha="$(jq -r --arg s "$svc" '.[$s] // empty' <<<"$heads")"
    [[ -n "$sha" ]] || continue
    check_sha "$sha"
    tag="sha-${sha:0:7}"
    running="$(running_tag "$status" "$svc")"
    item="$(jq -cn --arg s "$svc" --arg h "$sha" '{service: $s, sha: $h}')"
    if ! profile_on "$svc"; then
      action="none: the $svc profile is off in env/staging.versions"
    elif [[ "$running" == none ]]; then
      action="none: no $(container_of "$svc") container on staging; a person looks first (Runbook 9, section 6)"
    elif [[ "$running" == "$tag" ]]; then
      action="none: up to date"
    elif grep -qxF "refs/tags/auto-failed/$svc/$tag" <<<"$failed" && [[ "$retry" != true ]]; then
      action="none: $tag failed before (run by hand with retry_failed to try it again)"
    else
      if published "$svc" "$tag"; then
        action="image already on GHCR"
      elif [[ "$mode" == plan ]]; then
        action="would build"
      else
        build="$(jq -c --argjson i "$item" '. + [$i]' <<<"$build")"
        action="build"
      fi
      case "$mode" in
        deploy)
          deploy="$(jq -c --argjson i "$item" '. + [$i]' <<<"$deploy")"
          action+=", deploy"
          ;;
        plan) action+=", would deploy" ;;
      esac
    fi
    printf '| %s | %s | %s | %s |\n' "$svc" "$running" "$tag" "$action" >>"$summary"
    note "$svc: staging runs $running, main is $tag: $action"
  done
  printf 'build=%s\ndeploy=%s\n' "$build" "$deploy"
}

# --- build ------------------------------------------------------------------------------------------------------

cmd_build() {
  [[ $# -eq 2 ]] || die "usage: $0 build <service> <sha>"
  local svc="$1" sha="$2" repo context tag work entry image target ref
  local -a args
  check_service "$svc"
  check_sha "$sha"
  [[ -n "${GH_TOKEN:-}" ]] || die "GH_TOKEN is empty: the app-source Environment's APP_SOURCE_TOKEN secret is not set"
  [[ -n "${GHCR_USER:-}" && -n "${GHCR_TOKEN:-}" ]] || die "GHCR_USER and GHCR_TOKEN must be set"
  [[ "$(uname -m)" == aarch64 ]] || die "build on an arm64 runner (ubuntu-24.04-arm), this is $(uname -m)"
  repo="$(repo_of "$svc")"
  context="$(context_of "$svc")"
  tag="sha-${sha:0:7}"

  work="$(mktemp -d "${RUNNER_TEMP:-/tmp}/auto-build.XXXXXX")"
  # shellcheck disable=SC2064 # $work is fixed now, on purpose
  trap "rm -rf '$work'; docker logout ghcr.io >/dev/null 2>&1 || true" EXIT

  echo "==> source: $repo at $tag"
  gh api "repos/$OWNER/$repo/tarball/$sha" >"$work/source.tar.gz" 2>/dev/null \
    || die "could not download $repo at $tag: is APP_SOURCE_TOKEN expired, or without Contents: Read on $repo?"
  mkdir "$work/src"
  tar -xzf "$work/source.tar.gz" -C "$work/src" --strip-components=1 >/dev/null 2>&1 \
    || die "the $repo archive could not be unpacked"
  rm -f "$work/source.tar.gz"
  [[ -d "$work/src/$context" ]] || die "$repo has no '$context' directory at $tag"
  note "unpacked (its files are not listed: a private repository)"

  echo "==> builder"
  docker buildx create --name iltiam-auto --driver docker-container --use --bootstrap >/dev/null 2>&1 \
    || die "docker buildx could not start a builder"
  printf '%s' "$GHCR_TOKEN" | docker login ghcr.io --username "$GHCR_USER" --password-stdin >/dev/null 2>&1 \
    || die "GHCR login failed (does iltiam-deployment have Write in the package's Manage Actions access?)"
  note "docker-container builder; logged in to ghcr.io until this step ends"

  for entry in $(builds_of "$svc"); do
    image="${entry%%:*}"
    target="${entry#*:}"
    ref="$REGISTRY/$image:$tag"
    echo "==> build and push $ref (linux/arm64)"
    # The labels health-check.sh reads (revision) and publish-image.sh sets. Provenance min: an image index with
    # linux/arm64 in it, as the deploy's check expects. No cache: a cache in a public repository is readable by a
    # fork's pull request workflow, and these layers hold the private code.
    args=(--platform linux/arm64 --push --progress=quiet --provenance=mode=min
      --label "org.opencontainers.image.source=https://github.com/$OWNER/$repo"
      --label "org.opencontainers.image.revision=$sha"
      --label "org.opencontainers.image.version=$tag"
      -t "$ref")
    if [[ -n "$target" ]]; then args+=(--target "$target"); fi
    # The output stays in this file: never printed, gone with $work at the end of the step.
    if ! docker buildx build "${args[@]}" "$work/src/$context" >"$work/build.log" 2>&1; then
      die "the build of $ref failed. Its output is not shown (it quotes the private code). Reproduce it from a clone" \
        "of $repo at ${sha:0:7}: docker buildx build --platform linux/arm64${target:+ --target $target} $context"
    fi
    image_has_arm64 "$ref" || die "$ref was pushed but GHCR shows no linux/arm64 for it"
    note "ok: $ref"
  done
}

# --- published --------------------------------------------------------------------------------------------------

cmd_published() {
  [[ $# -eq 2 ]] || die "usage: $0 published <service> <tag>"
  check_service "$1"
  check_tag "$2"
  local entry
  if published "$1" "$2"; then
    for entry in $(builds_of "$1"); do note "$REGISTRY/${entry%%:*}:$2: published, linux/arm64"; done
    echo "ready=true"
  else
    note "$1 $2 is not on GHCR with linux/arm64: its build failed or was cancelled; nothing deploys"
    echo "ready=false"
  fi
}

# --- prepare ----------------------------------------------------------------------------------------------------

cmd_prepare() {
  [[ $# -eq 3 && -f "$3" ]] || die "usage: $0 prepare <service> <sha> <status file>"
  local svc="$1" sha="$2" status="$3" s running start base target previous tag out changed others
  check_service "$svc"
  check_sha "$sha"
  cd "$repo_root"
  [[ -z "$(git status --porcelain)" ]] || die "the checkout has uncommitted changes"
  start="$(git rev-parse HEAD)"
  git_bot

  # 1. The base: env/staging.versions as staging runs it now, so a rollback never moves another service.
  for s in "${SERVICES[@]}"; do
    running="$(running_tag "$status" "$s")"
    [[ "$running" == none ]] && continue
    bash scripts/set-version.sh --auto staging "$s" --tag "$running" >/dev/null
  done
  if git diff --quiet; then
    base="$start"
  else
    git commit -q -am "chore(staging): what staging runs (auto-deploy base)" \
      -m "Auto-deploy run ${GITHUB_RUN_ID:-local}: the tags the VM ran before this run changed anything (Runbook 9)."
    base="$(git rev-parse HEAD)"
  fi
  previous="$(running_tag "$status" "$svc")"

  # 2. The target: the base plus the new tag.
  out="$(bash scripts/set-version.sh --auto staging "$svc" "$sha")"
  tag="$(sed -n 's/^tag=//p' <<<"$out")"
  changed="$(sed -n 's/^changed=//p' <<<"$out")"
  if [[ "$changed" == true ]]; then
    git commit -q -am "chore(staging): deploy $svc $tag (auto)" \
      -m "iltiam/$(repo_of "$svc")@$sha, auto-deploy run ${GITHUB_RUN_ID:-local} (Runbook 9)."
  fi
  target="$(git rev-parse HEAD)"

  # Only env/staging.versions may differ from the workflow's commit of main: every script the VM runs is main's.
  others="$(git diff --name-only "$start" HEAD | grep -vx 'env/staging.versions' || true)"
  [[ -z "$others" ]] || die "the auto-deploy commits changed more than env/staging.versions"
  bash scripts/deploy.sh --check-versions staging >&2
  note "base ${base:0:7} (what runs), target ${target:0:7} ($svc $previous -> $tag, changed: $changed)"
  printf 'previous=%s\ntag=%s\nchanged=%s\nbase=%s\ntarget=%s\n' "$previous" "$tag" "$changed" "$base" "$target"
}

# --- push, mark-failed, clear-failed, check-built ---------------------------------------------------------------

cmd_push() {
  [[ $# -eq 0 ]] || die "usage: $0 push"
  local old
  cd "$repo_root"
  old="$(git ls-remote origin "refs/heads/$AUTO_BRANCH" | awk '{ print $1 }')" || die "could not read $AUTO_BRANCH"
  # The lease: only over the commit read just now (or only if the branch doesn't exist yet).
  git push -q --force-with-lease="refs/heads/$AUTO_BRANCH:$old" origin "HEAD:refs/heads/$AUTO_BRANCH" \
    || die "could not push $AUTO_BRANCH"
  note "$AUTO_BRANCH is now $(git rev-parse --short HEAD)"
}

cmd_mark_failed() {
  [[ $# -eq 3 ]] || die "usage: $0 mark-failed <service> <tag> <commit>"
  check_service "$1"
  check_tag "$2"
  check_sha "$3"
  cd "$repo_root"
  git tag -f "auto-failed/$1/$2" "$3" >/dev/null
  git push -q -f origin "refs/tags/auto-failed/$1/$2" || die "could not push the tag auto-failed/$1/$2"
  note "tagged auto-failed/$1/$2: the next runs skip it (run by hand with retry_failed to try again)"
}

cmd_clear_failed() {
  [[ $# -eq 2 ]] || die "usage: $0 clear-failed <service> <tag>"
  check_service "$1"
  check_tag "$2"
  cd "$repo_root"
  if git ls-remote --exit-code --tags origin "refs/tags/auto-failed/$1/$2" >/dev/null 2>&1; then
    git push -q origin ":refs/tags/auto-failed/$1/$2" || die "could not delete the tag auto-failed/$1/$2"
    note "deleted the tag auto-failed/$1/$2: it deployed this time"
  fi
}

cmd_check_built() {
  [[ $# -eq 1 ]] || die "usage: $0 check-built <builds JSON>"
  local svc sha tag missing=0
  jq -e 'type == "array"' >/dev/null 2>&1 <<<"$1" || die "the builds are not a JSON list"
  while IFS=$'\t' read -r svc sha; do
    [[ -n "$svc" ]] || continue
    check_service "$svc"
    check_sha "$sha"
    tag="sha-${sha:0:7}"
    if published "$svc" "$tag"; then
      note "$svc $tag: built"
    else
      echo "::error::the build of $svc $tag failed; it is skipped until a new commit or a run with retry_failed"
      cmd_mark_failed "$svc" "$tag" "${GITHUB_SHA:?}"
      missing=$((missing + 1))
    fi
  done < <(jq -r '.[] | [.service, .sha] | @tsv' <<<"$1" | tr -d '\r')
  ((missing == 0))
}

# --- main -------------------------------------------------------------------------------------------------------

[[ $# -ge 1 ]] || die "usage: $0 <heads|plan|build|published|prepare|push|mark-failed|clear-failed|check-built> ..."
command -v jq >/dev/null 2>&1 || die "jq not found"
sub="$1"
shift
case "$sub" in
  heads) cmd_heads "$@" ;;
  plan) cmd_plan "$@" ;;
  build) cmd_build "$@" ;;
  published) cmd_published "$@" ;;
  prepare) cmd_prepare "$@" ;;
  push) cmd_push "$@" ;;
  mark-failed) cmd_mark_failed "$@" ;;
  clear-failed) cmd_clear_failed "$@" ;;
  check-built) cmd_check_built "$@" ;;
  *) die "unknown step '$sub'" ;;
esac
