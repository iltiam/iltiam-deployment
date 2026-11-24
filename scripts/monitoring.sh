#!/usr/bin/env bash
# The monitoring stack on iltiam-1: the Compose project iltiam-monitoring, shared by both environments (Runbook 7,
# docs/runbooks/07-monitoring.md, issue #10).
#
# Usage, on the VM as deploy:
#   scripts/monitoring.sh up                      deploy: what the deploy workflow runs (-f environment=monitoring)
#   scripts/monitoring.sh <compose command ...>   day to day: ps, logs --tail 100 grafana, restart alloy, top, ...
# Anywhere (scripts/check-monitoring.sh):
#   scripts/monitoring.sh --render <env file> <output directory>
#       Only render what `up` renders, into <output directory>: targets/*.json and alertmanager/alertmanager.yml.
#
# `up`, in order:
#   1. Guards: arm64, not root, /srv/iltiam mounted, /srv/iltiam/env/monitoring (700) and its monitoring.env (600),
#      the folders of section 3 of the runbook. The VM's deploy lock (the same one as scripts/deploy.sh).
#   2. monitoring.env read as data (NAME='value' lines, never run); the required names set.
#   3. The metrics networks of both environments (scripts/lib/metrics-network.sh), made if missing.
#   4. targets/*.json from MONITORED_ENVIRONMENTS and each env/<env>.versions: a profile that is off has no target.
#      alertmanager/alertmanager.yml from monitoring/alertmanager/alertmanager.yml.template (mode 600).
#   5. pull, then `up -d --wait`; then Prometheus, Alertmanager and the blackbox exporter reread their files, and
#      Loki, Alloy and Grafana restart when their configuration changed since the last run.
#   6. What runs, and its memory (the issue's limit: 1.2 GB in all).
#
# THIS REPOSITORY IS PUBLIC and the deploy log too: this script prints names, tags and states only, never a value.
# `config` is refused unless it prints nothing secret (as in scripts/compose.sh). Never `set -x` here.

set -euo pipefail

PROJECT=iltiam-monitoring
WAIT_TIMEOUT=300
NAMES=(MONITORED_ENVIRONMENTS MONITORING_TUNNEL_TOKEN GRAFANA_ADMIN_PASSWORD ALERT_SMTP_USERNAME ALERT_SMTP_PASSWORD
  ALERT_EMAIL_TO ALERT_DISCORD_WEBHOOK_URL ALERT_HEARTBEAT_URL)
REQUIRED=(MONITORED_ENVIRONMENTS MONITORING_TUNNEL_TOKEN GRAFANA_ADMIN_PASSWORD ALERT_SMTP_USERNAME ALERT_SMTP_PASSWORD
  ALERT_EMAIL_TO)
# The public hostnames of each environment (Runbook 3): what the public probes ask.
declare -A API_HOST=([staging]=staging-api.iltiamcare.com [production]=api.iltiamcare.com)
declare -A APP_HOST=([staging]=staging-app.iltiamcare.com [production]=app.iltiamcare.com)

log() { printf '\n==> %s\n' "$*"; }
ok() { printf '    ok: %s\n' "$*"; }
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

# Docker Compose on Windows is a Windows program: hand it C:/... paths (only for the checks in Git Bash).
native() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

repo="$(cd "$(dirname "$0")/.." && pwd)"
root="${ILTIAM_ROOT:-/srv/iltiam}"
env_dir="$root/env/monitoring"
env_file="$env_dir/monitoring.env"
mon_dir="$root/monitoring"

# --- monitoring.env, read as data ------------------------------------------------------------------------------

declare -A M=()

# load_env <file>: NAME='value' lines (scripts/render-env.sh writes nothing else), comments and blank lines. Anything
# else, or a name this script doesn't know, stops it; nothing in the file is ever run.
load_env() {
  local file="$1" line name n known
  [[ -r "$file" ]] || die "$file not found or not readable: run the deploy workflow with environment=monitoring (Runbook 7, section 11)"
  [[ "$root" != /srv/iltiam || "$(stat -c '%a' "$file")" == 600 ]] || die "$file must have mode 600"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" == '#'* ]] && continue
    [[ "$line" =~ ^([A-Z][A-Z0-9_]*)=\'([^\']*)\'$ ]] || die "$file: a line that is not NAME='value'"
    name="${BASH_REMATCH[1]}"
    known=false
    for n in "${NAMES[@]}"; do [[ "$n" == "$name" ]] && known=true; done
    [[ "$known" == true ]] || die "$file: $name is not a monitoring setting"
    M[$name]="${BASH_REMATCH[2]}"
  done <"$file"
  local missing=()
  for name in "${REQUIRED[@]}"; do [[ -n "${M[$name]:-}" ]] || missing+=("$name"); done
  ((${#missing[@]} == 0)) || die "missing from monitoring.env: ${missing[*]} (Runbook 7, section 11)"
  # Shapes only; the message names the setting, never its value.
  [[ "${M[ALERT_EMAIL_TO]}" =~ ^[^[:space:],@]+@[^[:space:],@]+(,[^[:space:],@]+@[^[:space:],@]+)*$ ]] \
    || die "ALERT_EMAIL_TO must be one or more email addresses, comma-separated, no spaces"
  [[ -z "${M[ALERT_DISCORD_WEBHOOK_URL]:-}" || "${M[ALERT_DISCORD_WEBHOOK_URL]}" =~ ^https://(discord|discordapp)\.com/api/webhooks/[^[:space:]]+$ ]] \
    || die "ALERT_DISCORD_WEBHOOK_URL must be a Discord webhook URL (https://discord.com/api/webhooks/...)"
  [[ -z "${M[ALERT_HEARTBEAT_URL]:-}" || "${M[ALERT_HEARTBEAT_URL]}" =~ ^https://[^[:space:]]+$ ]] \
    || die "ALERT_HEARTBEAT_URL must be an https:// URL"
}

# The monitored environments, one per line; refuses anything but staging and production, and duplicates.
monitored() {
  local list="${M[MONITORED_ENVIRONMENTS]}" e seen=","
  [[ "$list" =~ ^[a-z]+(,[a-z]+)*$ ]] || die "MONITORED_ENVIRONMENTS must be staging or staging,production"
  for e in ${list//,/ }; do
    [[ "$e" == staging || "$e" == production ]] || die "MONITORED_ENVIRONMENTS: unknown environment '$e'"
    [[ "$seen" != *",$e,"* ]] || die "MONITORED_ENVIRONMENTS names $e twice"
    seen+="$e,"
    printf '%s\n' "$e"
  done
}

# --- Rendering ------------------------------------------------------------------------------------------------

# write_file <path> <content>: atomically, so Prometheus never reads half a file.
write_file() {
  local tmp="$1.tmp.$$"
  printf '%s\n' "$2" >"$tmp"
  mv -f "$tmp" "$1"
}

# One file_sd entry: entry <target> <labels as "k":"v" pairs>. Every value here comes from this script's own fixed
# strings (environment names, service names, hostnames), never from monitoring.env.
entry() { printf '  {"targets": ["%s"], "labels": {%s}}' "$1" "$2"; }

# render_targets <directory>
render_targets() {
  local dir="$1" env profiles envs
  local -A out=([ai-api]="" [ai-worker]="" [backend-web]="" [backend-worker]="" [probe-internal]="" [probe-public]="")
  add() { out[$1]+="${out[$1]:+,$'\n'}$2"; }
  # In a command substitution, so its die only ends that subshell: hence the `|| exit 1`.
  envs="$(monitored)" || exit 1
  for env in $envs; do
    profiles="$(sed -n 's/^COMPOSE_PROFILES=//p' "$repo/env/$env.versions" | tr -d '\r' | tail -n 1)"
    add ai-api "$(entry "$env-ai-api:8000" "\"env\": \"$env\"")"
    add ai-worker "$(entry "$env-ai-worker:9808" "\"env\": \"$env\"")"
    add probe-internal "$(entry "http://$env-ai-api:8000/ready" "\"env\": \"$env\", \"module\": \"http_internal\", \"check\": \"ai-ready\"")"
    if [[ ",$profiles," == *",backend,"* ]]; then
      add backend-web "$(entry "$env-backend-web:9100" "\"env\": \"$env\"")"
      add backend-worker "$(entry "$env-backend-worker:9101" "\"env\": \"$env\"")"
      add probe-internal "$(entry "http://$env-backend-web:8000/api/health/" "\"env\": \"$env\", \"module\": \"backend_internal_$env\", \"check\": \"backend-health\"")"
      add probe-public "$(entry "https://${API_HOST[$env]}/api/health/" "\"env\": \"$env\", \"module\": \"https_public\", \"check\": \"api-public\"")"
    fi
    if [[ ",$profiles," == *",web,"* ]]; then
      add probe-public "$(entry "https://${APP_HOST[$env]}/" "\"env\": \"$env\", \"module\": \"https_public\", \"check\": \"app-public\"")"
    fi
    ok "targets: $env (profiles '$profiles')"
  done
  mkdir -p "$dir"
  local name
  for name in "${!out[@]}"; do
    if [[ -n "${out[$name]}" ]]; then
      write_file "$dir/$name.json" "[
${out[$name]}
]"
    else
      write_file "$dir/$name.json" "[]"
    fi
  done
}

# render_alertmanager <output file>: the template with each @@NAME@@ replaced, and the "# begin NAME" ... "# end NAME"
# blocks of unset optional values dropped. The values reach awk through its environment, never an argument.
render_alertmanager() {
  local out="$1" tmp
  tmp="$out.tmp.$$"
  (
    umask 077
    for name in "${NAMES[@]}"; do export "AM_$name=${M[$name]:-}"; done
    awk '
      /^# begin [A-Z_]+$/ { if (ENVIRON["AM_" $3] == "") skip = 1; next }
      /^# end [A-Z_]+$/   { skip = 0; next }
      skip { next }
      /^#/ { print; next }
      {
        line = $0
        while (match(line, /@@[A-Z_]+@@/)) {
          name = substr(line, RSTART + 2, RLENGTH - 4)
          if (!(("AM_" name) in ENVIRON)) { print "unknown placeholder " name > "/dev/stderr"; exit 1 }
          line = substr(line, 1, RSTART - 1) ENVIRON["AM_" name] substr(line, RSTART + RLENGTH)
        }
        print line
      }' "$repo/monitoring/alertmanager/alertmanager.yml.template" >"$tmp"
  ) || { rm -f "$tmp"; die "rendering alertmanager.yml failed"; }
  chmod 600 "$tmp"
  mv -f "$tmp" "$out"
  ok "alertmanager.yml (email$([[ -n "${M[ALERT_DISCORD_WEBHOOK_URL]:-}" ]] && echo ", Discord")$([[ -n "${M[ALERT_HEARTBEAT_URL]:-}" ]] && echo ", heartbeat"))"
}

if [[ "${1:-}" == --render ]]; then
  [[ $# -eq 3 ]] || die "usage: $0 --render <env file> <output directory>"
  root=/nonexistent
  load_env "$2"
  mkdir -p "$3/targets" "$3/alertmanager"
  render_targets "$3/targets"
  render_alertmanager "$3/alertmanager/alertmanager.yml"
  exit 0
fi

# --- Compose ------------------------------------------------------------------------------------------------------

[[ $# -ge 1 ]] || die "usage: $0 up | $0 <docker compose command and arguments> | $0 --render <env file> <dir>"

compose() {
  MONITORING_UID="$(id -u)" MONITORING_GID="$(id -g)" ENV_DIR="$(native "$env_dir")" MON_DIR="$(native "$mon_dir")" \
    docker compose -p "$PROJECT" -f "$(native "$repo/compose.monitoring.yml")" --env-file "$(native "$env_file")" "$@"
}

if [[ "$1" != up ]]; then
  if [[ "$1" == config && "$root" == /srv/iltiam ]]; then
    [[ $# -ge 2 ]] || die "'config' alone would print secrets. Use 'config --quiet'"
    for arg in "${@:2}"; do
      case "$arg" in
        -q | --quiet | --services | --images | --profiles | --networks | --volumes) ;;
        *) die "'config $arg' would print secrets into this terminal. Use 'config --quiet'" ;;
      esac
    done
  fi
  [[ -r "$env_file" ]] || die "$env_file not found: deploy monitoring first (Runbook 7, section 11)"
  compose "$@"
  exit $?
fi

# --- up -------------------------------------------------------------------------------------------------------

log "guards"
[[ "$(uname -m)" == aarch64 ]] || die "expected the arm64 VM iltiam-1, this is $(uname -m)"
[[ "$(id -u)" -ne 0 ]] || die "run as deploy, not root"
mountpoint -q "$root" || die "$root is not mounted: the data volume is missing (Runbook 1, section 10)"
[[ -d "$env_dir" && "$(stat -c '%a %U' "$env_dir")" == "700 $(id -un)" ]] \
  || die "$env_dir must exist, mode 700, owned by $(id -un) (Runbook 7, section 3)"
for d in "$mon_dir" "$root/backups/status"; do
  [[ -d "$d" && -w "$d" ]] || die "$d must exist and be writable by $(id -un) (Runbook 7, section 3)"
done
exec 9>"$root/env/.deploy.lock"
flock -n 9 || die "a deploy is running on this VM; wait for it to finish"
ok "deploy lock taken"

load_env "$env_file"
ok "monitoring.env: every required setting present"

log "metrics networks"
# shellcheck source=scripts/lib/metrics-network.sh
source "$repo/scripts/lib/metrics-network.sh"
for e in staging production; do
  metrics_network_ensure "$e" || die "can't make the metrics network iltiam-metrics-$e"
done

log "folders"
for d in prometheus alertmanager loki grafana alloy; do
  install -d -m 750 "$mon_dir/$d"
done
install -d -m 755 "$mon_dir/targets"
install -d -m 700 "$env_dir/alertmanager"
ok "$mon_dir: prometheus alertmanager loki grafana alloy targets"

log "render"
render_targets "$mon_dir/targets"
render_alertmanager "$env_dir/alertmanager/alertmanager.yml"

log "docker compose"
compose config --quiet
ok "compose.monitoring.yml valid"
compose pull --quiet
ok "images present"

# Which configurations changed since the last `up`: those services restart after it (Prometheus, Alertmanager and the
# blackbox exporter reread theirs without a restart).
hash_of() { (cd "$repo/monitoring/$1" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1); }
declare -A changed=()
for c in loki alloy grafana; do
  h="$(hash_of "$c")"
  [[ "$(cat "$mon_dir/.$c.sha256" 2>/dev/null || true)" == "$h" ]] || changed[$c]="$h"
done

compose up -d --wait --wait-timeout "$WAIT_TIMEOUT" --remove-orphans
for c in "${!changed[@]}"; do
  if [[ -f "$mon_dir/.$c.sha256" ]]; then
    compose restart "$c" >/dev/null
    ok "restarted $c (its configuration changed)"
  fi
  printf '%s\n' "${changed[$c]}" >"$mon_dir/.$c.sha256"
done

log "reload"
for s in prometheus:9090 alertmanager:9093 blackbox:9115; do
  compose exec -T "${s%%:*}" wget -q -O /dev/null --post-data= "http://127.0.0.1:${s##*:}/-/reload" </dev/null \
    || die "${s%%:*} refused its new configuration: scripts/monitoring.sh logs --tail 50 ${s%%:*}"
  ok "${s%%:*} reread its configuration"
done

log "running in $PROJECT"
compose ps --format 'table {{.Service}}\t{{.Image}}\t{{.Status}}'
echo
used="$(docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' | awk -v p="$PROJECT-" '
  index($1, p) == 1 {
    v = $2; u = v; gsub(/[0-9.]/, "", u); gsub(/[^0-9.]/, "", v)
    m = (u == "GiB") ? 1024 : (u == "KiB") ? 1 / 1024 : (u == "B") ? 1 / 1048576 : 1
    s += v * m
  }
  END { printf "%.0f", s }')"
printf '    memory in use: %s MiB (issue #10: at most 1.2 GB, about 1229 MiB)\n' "$used"
log "monitoring deployed"
