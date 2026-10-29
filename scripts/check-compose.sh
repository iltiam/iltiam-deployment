#!/usr/bin/env bash
# The rules compose.yml must never break (issue #2, Runbook 5), checked on Compose's normalised config with dummy
# values. CI runs it after scripts/check-env.sh; a laptop runs the same (Git Bash with Docker Desktop installed; the
# Docker daemon need not run).
#
#   1. env/<env>.versions is well formed (scripts/deploy.sh --check-versions).
#   2. scripts/compose.sh refuses a `config` that would print secrets on the VM.
#   3. For staging and production, each with and without the FCM file, through scripts/compose.sh:
#      - exactly the expected services (production: no backend while its profile is off);
#      - no published port, no host network, no privileged container;
#      - every service on exactly its networks: only cloudflared and backend-web on edge; internal is internal: true;
#      - mem_limit, capped json-file logs, the restart policy and no-new-privileges everywhere; cap_drop ALL on our
#        own images and cloudflared;
#      - every image pinned to a tag, never latest;
#      - host paths only under /srv/iltiam (and the repository's postgres/initdb); the weights read-only except in
#        weights-init;
#      - each secret of infra.env only in the containers that need it;
#      - the health checks; 2 torch threads in the AI api and worker; FORWARDED_ALLOW_IPS in backend-web;
#      - the FCM file mounted read-only into the four backend roles when it exists, nowhere when it doesn't, and
#        never with a host path Docker would create (compared with how this Compose version renders an explicit
#        create_host_path false and true: section 0 below).
#   4. Negative cases: a published port, the AI api on edge, a secret in the wrong container, a latest tag, an FCM
#      mount that would create the host path, and a writable FCM mount are all caught.
#
# Usage: bash scripts/check-compose.sh
# Needs bash, jq and the Docker Compose plugin. No image is pulled and no container started.
# Prints names and results only. The dummy configs stay in a temporary directory and are never printed.

set -euo pipefail

cd "$(dirname "$0")/.."

log() { printf '\n==> %s\n' "$*"; }
ok() { printf '    ok: %s\n' "$*"; }
fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq not found"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
root="$work/root"

native() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

ALL_SERVICES='["cloudflared","postgres","redis","weights-init","ai-api","ai-worker","ai-beat",
  "backend-migrate","backend-web","backend-worker","backend-beat"]'
NO_BACKEND='["cloudflared","postgres","redis","weights-init","ai-api","ai-worker","ai-beat"]'

# The rules, as one jq program over `docker compose config --format json`. Prints one line per broken rule.
cat >"$work/rules.jq" <<'JQ'
def networks_of: {
  "cloudflared": ["edge"], "backend-web": ["edge", "internal"],
  "postgres": ["internal"], "redis": ["internal"],
  "ai-api": ["internal"], "ai-beat": ["internal"], "ai-worker": ["egress", "internal"], "weights-init": ["egress"],
  "backend-migrate": ["internal"], "backend-beat": ["internal"], "backend-worker": ["egress", "internal"]
};
def one_shots: ["weights-init", "backend-migrate"];
def no_capabilities: ["cloudflared", "weights-init", "ai-api", "ai-worker", "ai-beat",
  "backend-migrate", "backend-web", "backend-worker", "backend-beat"];
def health_checked: ["cloudflared", "postgres", "redis", "ai-api", "ai-worker", "backend-web"];
def backend: ["backend-migrate", "backend-web", "backend-worker", "backend-beat"];
# Which containers may hold each value of infra.env (the dummies are unique strings).
def secret_holders: {
  "CF_TUNNEL_TOKEN": ["cloudflared"],
  "POSTGRES_PASSWORD": ["postgres"],
  "BACKEND_DB_PASSWORD": (["postgres"] + backend),
  "AI_DB_PASSWORD": ["postgres", "ai-api", "ai-worker", "ai-beat"],
  "WEIGHTS_READ_TOKEN": ["weights-init"]
};
def fcm_target: "/run/secrets/fcm-service-account.json";

. as $c
| ($c.services | keys) as $have
| (
    (if $have != ($expected | sort) then "services: expected \($expected | sort | join(" ")), got \($have | join(" "))"
     else empty end),
    (["edge", "egress"][] | select($c.networks[.].internal == true) | "network \(.): must not be internal"),
    (if $c.networks.internal.internal != true then "network internal: must be internal: true" else empty end),
    ($c.services | to_entries[] | .key as $s | .value as $v | (
      (if ($v.ports // []) | length > 0 then "\($s): publishes ports" else empty end),
      (if ($v.network_mode // "") != "" then "\($s): network_mode \($v.network_mode)" else empty end),
      (if $v.privileged == true then "\($s): privileged" else empty end),
      ((($v.networks // {}) | keys) as $n
        | if $n != (networks_of[$s] // ["(not listed in check-compose.sh)"])
          then "\($s): networks \($n | join(",")), expected \(networks_of[$s] // [] | join(","))" else empty end),
      (if ($v.mem_limit // "") == "" then "\($s): no mem_limit" else empty end),
      (if ($v.logging.driver // "") != "json-file" or ($v.logging.options["max-size"] // "") == ""
       then "\($s): logs not capped" else empty end),
      (if (one_shots | index($s)) != null
       then (if $v.restart != "no" then "\($s): a one-shot needs restart \"no\"" else empty end)
       else (if $v.restart != "unless-stopped" then "\($s): restart must be unless-stopped" else empty end) end),
      (if (($v.security_opt // []) | index("no-new-privileges:true")) == null then "\($s): no no-new-privileges"
       else empty end),
      (if (no_capabilities | index($s)) != null and ((($v.cap_drop // []) | index("ALL")) == null)
       then "\($s): cap_drop ALL missing" else empty end),
      (($v.image // "") as $i
        | if ($i | test(":[A-Za-z0-9_][A-Za-z0-9_.-]*$") | not) or ($i | test(":latest$"))
          then "\($s): image '\($i)' is not pinned to a tag" else empty end),
      ($v.volumes // [] | .[] | select(.type == "bind")
        | if (.source | startswith($root + "/")) or (.source | startswith("/srv/iltiam/"))
             or (.source | test("postgres[/\\\\]initdb$")) then empty
          else "\($s): host path outside /srv/iltiam (target \(.target))" end),
      ($v.volumes // [] | .[] | select(.source == "/srv/iltiam/weights")
        | if ($s == "weights-init") == (.read_only == true)
          then "\($s): the weights must be \(if $s == "weights-init" then "writable" else "read-only" end) here"
          else empty end),
      (if (health_checked | index($s)) != null
          and (($v.healthcheck.test // []) | length == 0 or $v.healthcheck.disable == true)
       then "\($s): no health check" else empty end)
    )),
    (secret_holders | to_entries[] | .key as $name | .value as $allowed
      | ($dummies[$name]) as $value
      | $c.services | to_entries[]
      | .key as $s
      | select([(.value.environment // {})[] | tostring | contains($value)] | any)
      | select(($allowed | index($s)) == null)
      | "\($s): holds \($name), which only \($allowed | join(", ")) may"),
    (["ai-api", "ai-worker"][] as $s | ["ILTIAM_TORCH_THREADS", "OMP_NUM_THREADS"][] as $k
      | select($c.services[$s] != null and $c.services[$s].environment[$k] != "2")
      | "\($s): \($k) must be 2"),
    (select($c.services["backend-web"] != null and $c.services["backend-web"].environment.FORWARDED_ALLOW_IPS != "*")
      | "backend-web: FORWARDED_ALLOW_IPS must be *"),
    ($c.services | to_entries[] | .key as $s
      | ([.value.volumes // [] | .[] | select(.target == fcm_target)]) as $m
      | if $fcm and (backend | index($s)) != null then
          (if ($m | length) != 1 or $m[0].read_only != true or $m[0].bind != $never_created
              or $m[0].bind == $created
           then "\($s): the FCM file must be mounted read-only, never created" else empty end),
          (if .value.environment.FCM_CREDENTIALS_FILE != fcm_target then "\($s): FCM_CREDENTIALS_FILE not set"
           else empty end)
        else (if ($m | length) > 0 then "\($s): mounts the FCM file, which it must not" else empty end) end)
  )
JQ

# Broken rules of one config file, one per line (empty when all hold).
broken() {
  local cfg="$1" expected="$2" fcm="$3"
  jq -r --arg root "$(native "$root")" --argjson expected "$expected" --argjson fcm "$fcm" \
    --argjson dummies "$(cat "$work/dummies.json")" \
    --argjson never_created "$never_created" --argjson created "$created" \
    -f "$work/rules.jq" "$cfg" | tr -d '\r'
}

# --- 0. How this Compose version renders "never create the host path" ------------------------------------------
#
# Compose prints a bind mount's create_host_path only when it differs from that version's own default, and the
# defaults differ: 2.38 prints `"bind": {}` for an explicit false and `{"create_host_path": true}` for true (or the
# short syntax); 5.x prints `{"create_host_path": false}` for false and `{}` for true. So `{}` means opposite things.
# Instead of guessing, render one mount of each kind with the Compose that runs this check, and require the FCM
# mount to look exactly like the explicit false and unlike the true.

log "docker compose $(docker compose version --short)"
cat >"$work/bind-probe.yml" <<'YAML'
services:
  probe:
    image: busybox:1.37.0
    volumes:
      - {type: bind, source: /srv/iltiam/never, target: /never, read_only: true, bind: {create_host_path: false}}
      - {type: bind, source: /srv/iltiam/created, target: /created, read_only: true, bind: {create_host_path: true}}
YAML
docker compose -p bind-probe -f "$(native "$work/bind-probe.yml")" config --format json >"$work/bind-probe.json" \
  || fail "docker compose config failed on the bind-mount probe"
never_created="$(jq -c '.services.probe.volumes[] | select(.target == "/never") | .bind' "$work/bind-probe.json" | tr -d '\r')"
created="$(jq -c '.services.probe.volumes[] | select(.target == "/created") | .bind' "$work/bind-probe.json" | tr -d '\r')"
[[ -n "$never_created" && -n "$created" && "$never_created" != "$created" ]] \
  || fail "this Compose version renders create_host_path true and false alike; the FCM rule can't be checked"
ok "create_host_path false renders as $never_created, true as $created"

# --- 1. Versions files ----------------------------------------------------------------------------------------------

log "env/<env>.versions"
for env in staging production; do
  bash scripts/deploy.sh --check-versions "$env" >/dev/null || fail "env/$env.versions (see the error above)"
  ok "env/$env.versions"
done

# --- 2. compose.sh never prints secrets on the VM ---------------------------------------------------------------------

log "scripts/compose.sh"
for args in "config" "config --format json" "config --environment"; do
  # shellcheck disable=SC2086  # the arguments are meant to split
  if out="$(bash scripts/compose.sh staging $args 2>&1)"; then fail "compose.sh ran 'docker compose $args'"; fi
  [[ "$out" == *"print"*"secret"* ]] || fail "compose.sh refused 'docker compose $args' for another reason: $out"
  ok "refused: $args"
done

# --- 3. Rules, per environment --------------------------------------------------------------------------------------

printf '{' >"$work/dummies.json"
sep=""
for name in CF_TUNNEL_TOKEN POSTGRES_PASSWORD BACKEND_DB_PASSWORD AI_DB_PASSWORD WEIGHTS_READ_TOKEN; do
  printf '%s"%s":"dummy-%s"' "$sep" "$name" "${name,,}" >>"$work/dummies.json"
  sep=","
done
printf '}\n' >>"$work/dummies.json"

for env in staging production; do
  mkdir -p "$root/env/$env"
  jq -r 'to_entries[] | "\(.key)='"'"'\(.value)'"'"'"' "$work/dummies.json" | tr -d '\r' >"$root/env/$env/infra.env"
  : >"$root/env/$env/ai.env"
  : >"$root/env/$env/backend.env"
  expected="$ALL_SERVICES"
  [[ "$env" == production ]] && expected="$NO_BACKEND"

  for fcm in false true; do
    if [[ "$fcm" == true ]]; then : >"$root/env/$env/fcm-service-account.json"; fi
    log "$env, FCM file $([[ "$fcm" == true ]] && echo present || echo absent)"
    cfg="$work/$env-$fcm.json"
    ILTIAM_ROOT="$root" bash scripts/compose.sh "$env" config --format json >"$cfg" 2>"$work/err" \
      || { cat "$work/err" >&2; fail "docker compose config failed for $env"; }
    problems="$(broken "$cfg" "$expected" "$fcm")"
    [[ -z "$problems" ]] || { printf '    %s\n' "$problems" >&2; fail "$env: compose.yml breaks the rules above"; }
    ok "$(jq '.services | length' "$cfg" | tr -d '\r') services, every rule holds"
  done
  rm -f "$root/env/$env/fcm-service-account.json"
done

# --- 4. Negative cases -----------------------------------------------------------------------------------------------

log "negative cases"
jq '.services["ai-api"].ports = [{"target": 8000, "published": "8000"}]' "$work/staging-false.json" >"$work/neg-ports.json"
broken "$work/neg-ports.json" "$ALL_SERVICES" false | grep -q "ai-api: publishes ports" \
  || fail "a published port was not caught"
ok "caught: a published port"
jq '.services["ai-api"].networks.edge = null' "$work/staging-false.json" >"$work/neg-edge.json"
broken "$work/neg-edge.json" "$ALL_SERVICES" false | grep -q "ai-api: networks edge,internal" \
  || fail "the AI api on edge was not caught"
ok "caught: the AI api on edge"
jq '.services["ai-api"].environment.X = "dummy-cf_tunnel_token"' "$work/staging-false.json" >"$work/neg-secret.json"
broken "$work/neg-secret.json" "$ALL_SERVICES" false | grep -q "ai-api: holds CF_TUNNEL_TOKEN" \
  || fail "the tunnel token in the AI api was not caught"
ok "caught: the tunnel token in the AI api"
jq '.services.redis.image = "redis:latest"' "$work/staging-false.json" >"$work/neg-latest.json"
broken "$work/neg-latest.json" "$ALL_SERVICES" false | grep -q "redis: image 'redis:latest' is not pinned" \
  || fail "an image tagged latest was not caught"
ok "caught: an image tagged latest"
fcm_mount='.services["backend-web"].volumes |= map(if .target == "/run/secrets/fcm-service-account.json"'
jq --argjson created "$created" "$fcm_mount then .bind = \$created else . end)" "$work/staging-true.json" \
  >"$work/neg-fcm-created.json"
broken "$work/neg-fcm-created.json" "$ALL_SERVICES" true | grep -q "backend-web: the FCM file must be mounted" \
  || fail "an FCM mount that would create the host path was not caught"
ok "caught: an FCM mount that would create the host path (create_host_path true or the short syntax)"
jq "$fcm_mount then .read_only = false else . end)" "$work/staging-true.json" >"$work/neg-fcm-rw.json"
broken "$work/neg-fcm-rw.json" "$ALL_SERVICES" true | grep -q "backend-web: the FCM file must be mounted" \
  || fail "a writable FCM mount was not caught"
ok "caught: a writable FCM mount"

log "all compose checks passed"
