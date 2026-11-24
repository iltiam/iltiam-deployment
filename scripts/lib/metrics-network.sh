#!/usr/bin/env bash
# The metrics network of one environment, iltiam-metrics-<env> (Runbook 7, issue #10). Sourced by scripts/deploy.sh
# and scripts/monitoring.sh, which both make it when it is missing, so either project can start first.
#
# Internal (no route out), and on it only the environment's four scrape targets (compose.yml) and the monitoring
# project's Prometheus and blackbox exporter (compose.monitoring.yml). Neither Compose project owns it: both declare
# it external, so neither removes it on `down` or refuses it for a missing Compose label.

# metrics_network_ensure <staging|production>: make the network if it is missing; refuse one that is not internal.
metrics_network_ensure() {
  local net="iltiam-metrics-$1" internal
  if internal="$(docker network inspect --format '{{.Internal}}' "$net" 2>/dev/null)"; then
    [[ "$internal" == true ]] || {
      printf 'ERROR: %s exists but is not internal: once nothing uses it, docker network rm %s (Runbook 7)\n' \
        "$net" "$net" >&2
      return 1
    }
    printf '    ok: %s (internal)\n' "$net"
  else
    docker network create --internal --label org.iltiam.purpose=metrics "$net" >/dev/null || return 1
    printf '    ok: made %s (internal)\n' "$net"
  fi
}
