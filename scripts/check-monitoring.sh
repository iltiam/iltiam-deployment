#!/usr/bin/env bash
# The checks of the monitoring stack (Runbook 7, issue #10). scripts/ci-local.sh runs it; it needs the Docker daemon,
# because every tool runs from the same pinned image the VM runs (compose.monitoring.yml).
#
#   1. compose.monitoring.yml, through `docker compose config` with dummy values:
#      - no published port, host network or privileged container; every image pinned; mem_limit, capped logs,
#        restart unless-stopped and no-new-privileges everywhere;
#      - the memory limits add up to at most 1228 MiB (the issue's 1.2 GB, in docker stats' units);
#      - every service on exactly its networks: only cloudflared and Grafana on `tunnel`; only Prometheus and the
#        blackbox exporter on the environments' metrics networks, which are external and named
#        iltiam-metrics-staging / iltiam-metrics-production; only the proxy, Alloy and cAdvisor on `docker-api`;
#      - the Docker socket mounted into docker-proxy only and containerd's into cAdvisor only, both read-only; every
#        other host mount read-only, except the data folders under /srv/iltiam/monitoring;
#      - the tunnel token only in cloudflared, Grafana's password only in Grafana;
#      - negative cases: each of these rules catches what it must.
#   2. scripts/monitoring.sh --render: the targets of each environment and profile, Alertmanager's configuration with
#      and without the optional receivers, and what it must refuse.
#   3. scripts/render-deploy-env.sh monitoring: writes monitoring.env only, and refuses a missing required name.
#   4. promtool: prometheus.yml (with rendered targets), every rule file, and both rule tests
#      (tests/iltiam.test.yml, tests/ai-drift.test.yml). amtool: the rendered alertmanager.yml.
#      The blackbox exporter, Loki and Alloy check their own configuration. The dashboards are valid JSON.
#
# Usage: bash scripts/check-monitoring.sh
# Prints names and results only; the dummy files stay in a temporary directory.

set -euo pipefail

cd "$(dirname "$0")/.."

log() { printf '\n==> %s\n' "$*"; }
ok() { printf '    ok: %s\n' "$*"; }
fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

native() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

command -v jq >/dev/null 2>&1 || fail "jq not found"
docker info >/dev/null 2>&1 || fail "no Docker daemon: the tools run from their pinned images"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

MAX_MIB=1228
image_of() { sed -n "s|^    image: \\($1:[^[:space:]]*\\)\$|\\1|p" compose.monitoring.yml | head -n 1; }
PROM_IMAGE="$(image_of prom/prometheus)"
AM_IMAGE="$(image_of prom/alertmanager)"
BB_IMAGE="$(image_of prom/blackbox-exporter)"
LOKI_IMAGE="$(image_of grafana/loki)"
ALLOY_IMAGE="$(image_of grafana/alloy)"
for v in PROM_IMAGE AM_IMAGE BB_IMAGE LOKI_IMAGE ALLOY_IMAGE; do
  [[ -n "${!v}" ]] || fail "can't find the image for $v in compose.monitoring.yml"
done

# A dummy monitoring.env, as scripts/render-env.sh writes it.
dummy_env() {
  cat <<'EOF'
MONITORED_ENVIRONMENTS='staging,production'
MONITORING_TUNNEL_TOKEN='dummy-monitoring_tunnel_token'
GRAFANA_ADMIN_PASSWORD='dummy-grafana_admin_password'
ALERT_SMTP_USERNAME='ocid1.user.oc1..dummy@ocid1.tenancy.oc1..dummy'
ALERT_SMTP_PASSWORD='dummy&smtp$password\x'
ALERT_EMAIL_TO='alerts-one@example.com,alerts-two@example.com'
EOF
}

# --- 1. compose.monitoring.yml --------------------------------------------------------------------------------

log "compose.monitoring.yml"
dummy_env >"$work/monitoring.env"
# MSYS2_ENV_CONV_EXCL: Git Bash would otherwise turn the /srv paths into C:/Program Files/Git/srv/...
MSYS2_ENV_CONV_EXCL='ENV_DIR;MON_DIR' MONITORING_UID=1000 MONITORING_GID=1000 \
  ENV_DIR=/srv/iltiam/env/monitoring MON_DIR=/srv/iltiam/monitoring \
  docker compose -p iltiam-monitoring -f compose.monitoring.yml --env-file "$(native "$work/monitoring.env")" \
  config --format json >"$work/config.json" 2>"$work/err" || { cat "$work/err" >&2; fail "docker compose config failed"; }

cat >"$work/rules.jq" <<'JQ'
def networks_of: {
  "prometheus": ["metrics-production", "metrics-staging", "monitoring"],
  "alertmanager": ["monitoring", "outbound"],
  "blackbox": ["metrics-production", "metrics-staging", "monitoring", "outbound"],
  "node-exporter": ["monitoring"],
  "cadvisor": ["docker-api", "monitoring"],
  "docker-proxy": ["docker-api"],
  "alloy": ["docker-api", "monitoring"],
  "loki": ["monitoring"],
  "grafana": ["monitoring", "outbound", "tunnel"],
  "cloudflared": ["outbound", "tunnel"]
};
def secret_holders: {"dummy-monitoring_tunnel_token": "cloudflared", "dummy-grafana_admin_password": "grafana"};
def mib: (tostring | tonumber) / 1048576;

. as $c
| (
    (if ($c.services | keys) != (networks_of | keys) then
       "services: expected \(networks_of | keys | join(" ")), got \($c.services | keys | join(" "))" else empty end),
    (["monitoring", "tunnel", "docker-api"][] | select($c.networks[.].internal != true)
      | "network \(.): must be internal: true"),
    (if $c.networks.outbound.internal == true then "network outbound: must not be internal" else empty end),
    (["staging", "production"][] as $e
      | select($c.networks["metrics-\($e)"].external != true or $c.networks["metrics-\($e)"].name != "iltiam-metrics-\($e)")
      | "network metrics-\($e): must be the external network iltiam-metrics-\($e)"),
    ([$c.services[].mem_limit // 0 | mib] | add) as $total
      | (if $total > $max then "mem_limits add up to \($total) MiB, more than \($max)" else empty end),
    ($c.services | to_entries[] | .key as $s | .value as $v | (
      (if ($v.ports // []) | length > 0 then "\($s): publishes ports" else empty end),
      (if ($v.network_mode // "") != "" then "\($s): network_mode \($v.network_mode)" else empty end),
      (if $v.privileged == true then "\($s): privileged" else empty end),
      (if $v.pid == "host" then "\($s): host pid namespace" else empty end),
      ((($v.networks // {}) | keys) as $n
        | if $n != (networks_of[$s] // ["(not listed in check-monitoring.sh)"])
          then "\($s): networks \($n | join(",")), expected \(networks_of[$s] // [] | join(","))" else empty end),
      (if ($v.mem_limit // "") == "" then "\($s): no mem_limit" else empty end),
      (if ($v.logging.driver // "") != "json-file" or ($v.logging.options["max-size"] // "") == ""
       then "\($s): logs not capped" else empty end),
      (if $v.restart != "unless-stopped" then "\($s): restart must be unless-stopped" else empty end),
      (if (($v.security_opt // []) | index("no-new-privileges:true")) == null then "\($s): no no-new-privileges"
       else empty end),
      (($v.image // "") as $i
        | if ($i | test(":[A-Za-z0-9_][A-Za-z0-9_.-]*$") | not) or ($i | test(":(latest|main)$"))
          then "\($s): image '\($i)' is not pinned to a version" else empty end),
      ($v.volumes // [] | .[] | select(.type == "bind") | . as $m
        | if $m.source == "/var/run/docker.sock" then
            (if $s != "docker-proxy" or $m.read_only != true
             then "\($s): mounts the Docker socket (only docker-proxy may, read-only)" else empty end)
          elif ($m.source | test("containerd")) then
            (if $s != "cadvisor" or $m.read_only != true
             then "\($s): mounts containerd's socket (only cAdvisor may, read-only)" else empty end)
          elif ($m.source | startswith("/srv/iltiam/monitoring/")) then empty
          elif $m.read_only != true then "\($s): writable host mount \($m.source)"
          else empty end),
      ([($v.environment // {})[] | tostring] | join(" ")) as $envs
        | (secret_holders | to_entries[] | .key as $k | select(($envs | contains($k)) and .value != $s)
           | "\($s): holds the secret only \(.value) may")
    ))
  )
JQ

broken() { jq -r --argjson max "$MAX_MIB" -f "$work/rules.jq" "$1" | tr -d '\r'; }

problems="$(broken "$work/config.json")"
[[ -z "$problems" ]] || { printf '    %s\n' "$problems" >&2; fail "compose.monitoring.yml breaks the rules above"; }
total="$(jq '[.services[].mem_limit | tonumber] | add / 1048576' "$work/config.json" | tr -d '\r')"
ok "$(jq '.services | length' "$work/config.json" | tr -d '\r') services, every rule holds; mem_limits ${total} MiB of at most $MAX_MIB"

must_catch() {
  local what="$1" line="$2" edit="$3"
  jq "$edit" "$work/config.json" >"$work/neg.json"
  grep -qF -- "$line" <<<"$(broken "$work/neg.json")" || fail "$what was not caught"
  ok "caught: $what"
}
must_catch "a published port" "grafana: publishes ports" '.services.grafana.ports = [{"target": 3000, "published": "3000"}]'
must_catch "limits over 1.2 GB" "mem_limits add up to" '.services.prometheus.mem_limit = "1073741824"'
must_catch "a service without mem_limit" "loki: no mem_limit" 'del(.services.loki.mem_limit)'
must_catch "Grafana on a metrics network" "grafana: networks" \
  '.services.grafana.networks["metrics-staging"] = null'
must_catch "Loki on the tunnel network" "loki: networks" '.services.loki.networks.tunnel = null'
must_catch "a metrics network owned by the project" "network metrics-staging: must be the external" \
  '.networks["metrics-staging"] = {"name": "iltiam-metrics-staging"}'
must_catch "the Docker socket in Alloy" "alloy: mounts the Docker socket" \
  '.services.alloy.volumes += [{"type": "bind", "source": "/var/run/docker.sock", "target": "/var/run/docker.sock", "read_only": true}]'
must_catch "containerd's socket in Grafana" "grafana: mounts containerd's socket" \
  '.services.grafana.volumes += [{"type": "bind", "source": "/run/containerd/containerd.sock", "target": "/run/containerd/containerd.sock", "read_only": true}]'
must_catch "a writable Docker socket" "docker-proxy: mounts the Docker socket" \
  '.services["docker-proxy"].volumes |= map(.read_only = false)'
must_catch "a writable host mount" "node-exporter: writable host mount /" \
  '.services["node-exporter"].volumes |= map(if .target == "/host" then .read_only = false else . end)'
must_catch "the tunnel token in Grafana" "grafana: holds the secret only cloudflared may" \
  '.services.grafana.environment.X = "dummy-monitoring_tunnel_token"'
must_catch "an image tagged latest" "loki: image 'grafana/loki:latest' is not pinned" \
  '.services.loki.image = "grafana/loki:latest"'
must_catch "a privileged cAdvisor" "cadvisor: privileged" '.services.cadvisor.privileged = true'

# --- 2. monitoring.sh --render ------------------------------------------------------------------------------------

log "scripts/monitoring.sh --render"
bash scripts/monitoring.sh --render "$work/monitoring.env" "$work/render" >/dev/null
for f in ai-api ai-worker backend-web backend-worker probe-internal probe-public; do
  jq -e 'type == "array"' "$work/render/targets/$f.json" >/dev/null || fail "targets/$f.json is not a JSON array"
done
targets() { jq -r '.[] | .targets[0] + " " + .labels.env' "$work/render/targets/$1.json" | tr -d '\r' | sort | xargs; }
staging_profiles="$(sed -n 's/^COMPOSE_PROFILES=//p' env/staging.versions | tr -d '\r' | tail -n 1)"
prod_profiles="$(sed -n 's/^COMPOSE_PROFILES=//p' env/production.versions | tr -d '\r' | tail -n 1)"
[[ "$(targets ai-api)" == "production-ai-api:8000 production staging-ai-api:8000 staging" ]] \
  || fail "ai-api targets: $(targets ai-api)"
ok "ai-api: both environments, as <env>-ai-api:8000"
expected_backend=""
[[ ",$prod_profiles," != *",backend,"* ]] || expected_backend+="production-backend-web:9100 production "
[[ ",$staging_profiles," != *",backend,"* ]] || expected_backend+="staging-backend-web:9100 staging"
[[ "$(targets backend-web)" == "$(xargs <<<"$expected_backend")" ]] \
  || fail "backend-web targets '$(targets backend-web)', expected '$expected_backend'"
ok "backend-web: only where the backend profile is on (staging '$staging_profiles', production '$prod_profiles')"
! grep -q 'ready/' "$work/render/targets/probe-internal.json" "$work/render/targets/probe-public.json" \
  || fail "a probe asks the backend's /api/ready/ (5 object storage requests per call, Runbook 8, section 2)"
ok "no probe asks the backend's /api/ready/"

am="$work/render/alertmanager/alertmanager.yml"
grep -q "smtp_auth_password: 'dummy&smtp\$password\\\\x'" "$am" || fail "the SMTP password did not reach alertmanager.yml unchanged"
! grep -q '@@' <(grep -v '^#' "$am") || fail "alertmanager.yml still holds a placeholder"
! grep -q 'discord_configs\|webhook_configs' "$am" || fail "an unset optional receiver reached alertmanager.yml"
ok "alertmanager.yml: values unchanged (& \$ \\ included), no optional receiver when unset"
{ dummy_env; printf "ALERT_DISCORD_WEBHOOK_URL='https://discord.com/api/webhooks/1/dummy'\n";
  printf "ALERT_HEARTBEAT_URL='https://hc-ping.com/dummy'\n"; } >"$work/all.env"
bash scripts/monitoring.sh --render "$work/all.env" "$work/render-all" >/dev/null
for receiver in discord_configs webhook_configs; do
  grep -q "$receiver" "$work/render-all/alertmanager/alertmanager.yml" || fail "$receiver is missing when set"
done
ok "alertmanager.yml: Discord and the heartbeat when set"

expect_refused() {
  local what="$1" file="$work/refused.env"
  shift
  "$@" >"$file"
  if bash scripts/monitoring.sh --render "$file" "$work/refused" >/dev/null 2>&1; then fail "not refused: $what"; fi
  ok "refused: $what"
}
expect_refused "a line that is not NAME='value'" bash -c "$(declare -f dummy_env); dummy_env; echo 'X=\$(touch pwned)'"
[[ ! -e pwned ]] || { rm -f pwned; fail "reading monitoring.env ran a command from it"; }
expect_refused "a name that is not a monitoring setting" bash -c "$(declare -f dummy_env); dummy_env; echo \"POSTGRES_PASSWORD='x'\""
expect_refused "a missing required name" bash -c "$(declare -f dummy_env); dummy_env | grep -v ALERT_EMAIL_TO"
expect_refused "an unknown environment" bash -c "$(declare -f dummy_env); dummy_env | sed 's/staging,production/staging,dev/'"
expect_refused "an environment named twice" bash -c "$(declare -f dummy_env); dummy_env | sed 's/staging,production/staging,staging/'"
expect_refused "an email list with a space" bash -c "$(declare -f dummy_env); dummy_env | sed 's/,alerts-two/, alerts-two/'"
expect_refused "a Discord URL that is not Discord's" bash -c "$(declare -f dummy_env); dummy_env; echo \"ALERT_DISCORD_WEBHOOK_URL='https://example.com/x'\""

# --- 3. render-deploy-env.sh monitoring -----------------------------------------------------------------------

log "scripts/render-deploy-env.sh monitoring"
secrets='{"MONITORING_TUNNEL_TOKEN":"t","GRAFANA_ADMIN_PASSWORD":"g","ALERT_SMTP_USERNAME":"u","ALERT_SMTP_PASSWORD":"p","ALERT_EMAIL_TO":"a@example.com"}'
SECRETS_JSON="$secrets" VARS_JSON='{"MONITORED_ENVIRONMENTS":"staging"}' \
  bash scripts/render-deploy-env.sh monitoring "$work/deploy" >/dev/null
written="$(find "$work/deploy" -mindepth 1 -printf '%f ')"
[[ "$written" == "monitoring.env " ]] || fail "render-deploy-env.sh monitoring wrote: $written"
bash scripts/monitoring.sh --render "$work/deploy/monitoring.env" "$work/render-deploy" >/dev/null \
  || fail "monitoring.sh can't read the monitoring.env render-deploy-env.sh writes"
ok "monitoring.env only, and monitoring.sh reads it"
if SECRETS_JSON='{"MONITORING_TUNNEL_TOKEN":"t"}' VARS_JSON='{"MONITORED_ENVIRONMENTS":"staging"}' \
  bash scripts/render-deploy-env.sh monitoring "$work/deploy-missing" >/dev/null 2>&1; then
  fail "render-deploy-env.sh monitoring did not refuse missing secrets"
fi
ok "refused: monitoring without its required secrets"

# --- 4. The tools' own checks -------------------------------------------------------------------------------------

m="$(native "$PWD/monitoring")"
r="$(native "$work/render")"
run() { MSYS_NO_PATHCONV=1 docker run --rm "$@"; }

log "promtool ($PROM_IMAGE)"
run -v "$m/prometheus:/etc/prometheus:ro" -v "$r/targets:/etc/prometheus-targets:ro" --entrypoint promtool \
  "$PROM_IMAGE" check config /etc/prometheus/prometheus.yml >"$work/out" 2>&1 \
  || { cat "$work/out" >&2; fail "promtool check config"; }
ok "prometheus.yml and every rule file"
for t in iltiam ai-drift; do
  run -v "$m:/m:ro" --entrypoint promtool "$PROM_IMAGE" test rules "/m/prometheus/tests/$t.test.yml" >"$work/out" 2>&1 \
    || { cat "$work/out" >&2; fail "promtool test rules tests/$t.test.yml"; }
  ok "promtool test rules tests/$t.test.yml"
done

log "amtool ($AM_IMAGE)"
for d in render render-all; do
  run -v "$(native "$work/$d/alertmanager"):/c:ro" --entrypoint amtool "$AM_IMAGE" check-config /c/alertmanager.yml \
    >"$work/out" 2>&1 || { cat "$work/out" >&2; fail "amtool check-config ($d)"; }
done
ok "alertmanager.yml, without and with the optional receivers"

log "blackbox, Loki and Alloy"
run -v "$m/blackbox:/etc/blackbox:ro" "$BB_IMAGE" --config.file=/etc/blackbox/blackbox.yml --config.check \
  >"$work/out" 2>&1 || { cat "$work/out" >&2; fail "blackbox exporter --config.check"; }
ok "blackbox.yml ($BB_IMAGE)"
run -v "$m/loki:/etc/loki:ro" "$LOKI_IMAGE" -config.file=/etc/loki/loki.yml -verify-config >"$work/out" 2>&1 \
  || { cat "$work/out" >&2; fail "loki -verify-config"; }
ok "loki.yml ($LOKI_IMAGE)"
run -v "$m/alloy:/etc/alloy:ro" "$ALLOY_IMAGE" validate /etc/alloy/config.alloy >"$work/out" 2>&1 \
  || { cat "$work/out" >&2; fail "alloy validate"; }
ok "config.alloy ($ALLOY_IMAGE)"

log "Grafana dashboards"
uids=""
for f in monitoring/grafana/dashboards/*.json; do
  uid="$(jq -er '.uid' "$f" | tr -d '\r')" || fail "$f: not JSON, or no uid"
  uids+="$uid "
  # Every data source is a provisioned one (by uid) or the dashboard's own variable.
  bad="$(jq -r '[.. | objects | select(has("datasource")) | .datasource | select(type == "object") | .uid]
    | unique | map(select(. != "prometheus" and . != "loki" and . != "${datasource}")) | join(" ")' "$f" | tr -d '\r')"
  [[ -z "$bad" ]] || fail "$f: unknown data source uid(s): $bad"
  ok "$(basename "$f"): uid $uid, $(jq '[.. | objects | select(has("gridPos"))] | length' "$f" | tr -d '\r') panels"
done
[[ "$(tr ' ' '\n' <<<"$uids" | sed '/^$/d' | sort | uniq -d)" == "" ]] || fail "two dashboards share a uid"

log "all monitoring checks passed"
