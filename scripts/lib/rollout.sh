# shellcheck shell=bash
# rollout.sh: replace one long-running service's container with no downtime (iltiam-ai-service#150, NFR-MAI-01).
# Sourced by scripts/deploy.sh for ai-api and ai-worker; scripts/check-rollout.sh tests it on a throwaway project.
# The AI side, and why the old way failed analyses: iltiam-ai-service docs/model-update.md.
#
#   rollout <service> <ready command, run inside the new container ...>
#
# Needs, from the caller: a function `compose` (docker compose for this project), `log`, `ok` and `die`.
#   1. No running container: `up -d --wait` (a first deploy: nothing to keep up). Same config hash as the running
#      one: nothing to do. Two or more running: an earlier rollout was cut short; stop and say how to clean up.
#   2. Free memory for a second container (its mem_limit + ROLLOUT_HEADROOM_MB), or stop with nothing changed.
#      Never the old stop-then-start instead: the backend gives up after ~6 s, and a model takes longer to load.
#   3. A second container next to the old one, with the new config: `up -d --no-deps --no-recreate --scale <s>=2`.
#      Both answer on the service's name meanwhile (Compose's DNS returns both).
#   4. Wait (ROLLOUT_TIMEOUT_S) until it is running, healthy (if it has a healthcheck) and the ready command exits 0
#      inside it. Not ready in time, or it exited: its logs go to ROLLOUT_LOG_DIR, it is removed, and the rollout
#      stops. The old container was never touched.
#   5. Stop the old one (SIGTERM, then its stop_grace_period: a worker finishes its jobs in progress, gunicorn its
#      requests) and remove it.
#
# Prints names, states and the ready command's output only (the deploy log is public): the ready commands print
# model versions, never a value from the env files. Never `set -x`.

ROLLOUT_TIMEOUT_S="${ROLLOUT_TIMEOUT_S:-600}"
ROLLOUT_HEADROOM_MB="${ROLLOUT_HEADROOM_MB:-256}"
ROLLOUT_MEMINFO="${ROLLOUT_MEMINFO:-/proc/meminfo}"
ROLLOUT_LOG_DIR="${ROLLOUT_LOG_DIR:-}"

# Running container ids of a service, one per line.
rollout_running() {
  compose ps -q "$1"
}

rollout_free_mb() {
  awk '/^MemAvailable:/ { print int($2 / 1024); found = 1 } END { if (!found) exit 1 }' "$ROLLOUT_MEMINFO" \
    || die "cannot read MemAvailable from $ROLLOUT_MEMINFO"
}

# MB a second container of the running container $1 may use: its memory limit plus the headroom.
rollout_needed_mb() {
  local limit
  limit="$(docker inspect -f '{{.HostConfig.Memory}}' "$1")"
  [[ "$limit" =~ ^[0-9]+$ && "$limit" -gt 0 ]] \
    || die "$(rollout_name "$1") has no memory limit: set mem_limit in compose.yml, so its rollout can be sized"
  echo $((limit / 1048576 + ROLLOUT_HEADROOM_MB))
}

rollout_name() {
  docker inspect -f '{{.Name}}' "$1" | sed 's#^/##'
}

# Does the running container $2 of service $1 already have the config Compose would give it now?
rollout_current() {
  local want have
  want="$(compose config --hash="$1" | awk -v s="$1" '$1 == s { print $2 }')"
  [[ -n "$want" ]] || die "no config hash for $1"
  have="$(docker inspect -f '{{index .Config.Labels "com.docker.compose.config-hash"}}' "$2")"
  [[ "$want" == "$have" ]]
}

# rollout_memory_check <service ...>: before anything changes, enough memory for the largest second container any
# of these services will need (they roll one at a time).
rollout_memory_check() {
  local service ids need max=0 who="" free
  for service in "$@"; do
    mapfile -t ids < <(rollout_running "$service")
    [[ ${#ids[@]} -eq 1 ]] || continue
    rollout_current "$service" "${ids[0]}" && continue
    need="$(rollout_needed_mb "${ids[0]}")"
    if ((need > max)); then max="$need" who="$service"; fi
  done
  ((max > 0)) || return 0
  free="$(rollout_free_mb)"
  ((free >= max)) || die "not enough free memory to start a second $who next to the old one: ${free} MB available,\
 ${max} MB needed (its mem_limit + ${ROLLOUT_HEADROOM_MB} MB). Nothing was changed. Free some memory, then deploy\
 again; never stop it first instead, the backend would fail the analyses meanwhile (ai-service docs/model-update.md)"
  ok "free memory: ${free} MB, the largest second container needs ${max} MB ($who)"
}

rollout() {
  local service="$1"
  shift
  local -a ready_cmd=("$@") old_ids ids
  local old new id need free deadline state health out grace code

  mapfile -t old_ids < <(rollout_running "$service")
  if [[ ${#old_ids[@]} -eq 0 ]]; then
    log "start: $service (none running)"
    compose up -d --wait --wait-timeout "$ROLLOUT_TIMEOUT_S" --no-deps "$service"
    return
  fi
  if [[ ${#old_ids[@]} -gt 1 ]]; then
    die "${#old_ids[@]} $service containers are running: an earlier rollout was cut short. Keep the newest: docker ps\
 --filter label=com.docker.compose.service=$service, then docker stop -t 60 <the older one> && docker rm <it>, and\
 deploy again"
  fi
  old="${old_ids[0]}"
  if rollout_current "$service" "$old"; then
    ok "$service: up to date ($(rollout_name "$old"))"
    return
  fi

  log "rollout: $service"
  need="$(rollout_needed_mb "$old")"
  free="$(rollout_free_mb)"
  ((free >= need)) || die "not enough free memory to start a second $service next to the old one: ${free} MB\
 available, ${need} MB needed (its mem_limit + ${ROLLOUT_HEADROOM_MB} MB). The old one still runs. Free some memory,\
 then deploy again; never stop it first instead, the backend would fail the analyses meanwhile"
  ok "free memory: ${free} MB, needed ${need} MB"

  compose up -d --no-deps --no-recreate --scale "$service=2" "$service"
  mapfile -t ids < <(rollout_running "$service")
  new=""
  for id in "${ids[@]}"; do
    [[ "$id" != "$old" ]] && new="$id"
  done
  [[ -n "$new" && ${#ids[@]} -eq 2 ]] || die "$service: expected the old and one new container, got ${#ids[@]}"
  ok "new container $(rollout_name "$new") next to $(rollout_name "$old")"

  deadline=$((SECONDS + ROLLOUT_TIMEOUT_S))
  while :; do
    state="$(docker inspect -f '{{.State.Status}}' "$new")"
    health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$new")"
    if [[ "$state" != running ]]; then
      rollout_abandon "$service" "$new" "it is $state"
    fi
    if [[ "$health" == healthy || "$health" == none ]] && out="$(docker exec "$new" "${ready_cmd[@]}" 2>/dev/null)"; then
      break
    fi
    ((SECONDS < deadline)) || rollout_abandon "$service" "$new" "not ready after ${ROLLOUT_TIMEOUT_S} s (health: $health)"
    sleep 3
  done
  ok "$(rollout_name "$new") is ready: ${out//$'\n'/ }"

  grace="$(docker inspect -f '{{.Config.StopTimeout}}' "$old")"
  [[ "$grace" =~ ^[0-9]+$ ]] || grace=10
  log "stop the old $service: $(rollout_name "$old") (SIGTERM, up to ${grace} s)"
  docker stop -t "$grace" "$old" >/dev/null
  code="$(docker inspect -f '{{.State.ExitCode}}' "$old")"
  docker rm "$old" >/dev/null
  if [[ "$code" == 0 ]]; then
    ok "old $service stopped cleanly and removed"
  else
    printf '    WARNING: the old %s exited with %s (killed at the end of its grace period?); its jobs are redelivered\n' \
      "$service" "$code"
  fi
}

# The new container failed: keep its logs on the VM (not in the public deploy log), remove it, stop the deploy.
rollout_abandon() {
  local service="$1" new="$2" why="$3" file=""
  if [[ -n "$ROLLOUT_LOG_DIR" ]]; then
    file="$ROLLOUT_LOG_DIR/rollout-$service-$(date -u +%Y%m%dT%H%M%SZ).log"
    (umask 077 && docker logs "$new" >"$file" 2>&1) || file=""
  fi
  docker rm -f "$new" >/dev/null
  die "the new $service was $why, so it was removed and the old one still runs${file:+; its logs: $file}"
}
