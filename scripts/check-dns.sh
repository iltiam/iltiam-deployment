#!/usr/bin/env bash
# Check iltiamcare.com from the outside (Runbook 2, issue #12): the rows of the checklist in
# docs/runbooks/02-cloudflare-dns-tls.md, section 12.2, that a command can decide. DNS, the email records and the
# HTTPS headers of the staging hosts. Read-only: it only asks Cloudflare's resolver and fetches two public pages.
#
# Usage, in Git Bash on a Windows laptop or on iltiam-1:
#   bash scripts/check-dns.sh
# In PowerShell, name Git Bash in full, because plain "bash" there can start WSL instead. -l reads your Git Bash
# profile, which may be what puts jq on the PATH:
#   & "C:\Program Files\Git\bin\bash.exe" -l scripts/check-dns.sh
#
# Optional, from the environment:
#   DKIM_SELECTOR  the OCI DKIM selector of section 11.3, when it isn't the default iltiam-ruh-202611
#
# DNS goes to Cloudflare's resolver over HTTPS (DoH), so it works where `dig` is missing (Git Bash) and on networks
# that block port 53 to outside resolvers. Needs curl and jq.
#
# Each output line names its checklist row ("row 18"; "R3 row 23" is Runbook 3's checklist). The output is the one to
# paste into the issue: the DMARC report address and the DS digest are redacted, and no IP, ID or URL is printed.
#   PASS     the row's command check passed
#   FAIL     it failed, or a query got no answer
#   PENDING  can't pass yet: the email record or the HSTS header doesn't exist yet (#35), or staging isn't answering
#   NOTE     not counted
# Rows that need the dashboard, a mailbox, OCI or SSL Labs are not checked here; the last NOTE lists them.
# Exit 0 when nothing failed (PENDING lines allowed); 1 when a check failed. Some networks break the HTTPS checks
# (no answer, FAIL): run it again from the VM.

set -euo pipefail

DOMAIN=iltiamcare.com
DOH=https://cloudflare-dns.com/dns-query
SPF_CF="v=spf1 include:_spf.mx.cloudflare.net -all"
# The one CNAME that OCI generates for the return path (Runbook 2, section 11.4).
RETURN_PATH_TARGET="ruh1.rp.oracleemaildelivery.com."
GIT_BASH_HINT='On Windows, use Git Bash: & "C:\Program Files\Git\bin\bash.exe" -l scripts/check-dns.sh'
# Row 19: a max-age of exactly 6 months.
HSTS_MAX_AGE_RE='(^|[[:space:];])max-age=15552000($|[[:space:];])'
# Statuses Cloudflare answers itself when nothing runs behind the tunnel yet (530: no connector for the hostname).
ORIGIN_DOWN=" 502 503 504 521 522 523 524 530 "

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 0 ]] || die "usage: $0 (no arguments; DKIM_SELECTOR from the environment)"
command -v curl >/dev/null 2>&1 || die "curl not found. $GIT_BASH_HINT"
command -v jq >/dev/null 2>&1 || die "jq not found. $GIT_BASH_HINT"
DKIM_SELECTOR="${DKIM_SELECTOR:-iltiam-ruh-202611}"
[[ "$DKIM_SELECTOR" =~ ^[A-Za-z0-9-]+$ ]] || die "DKIM_SELECTOR: letters, digits and dashes only"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0 fail=0 pending=0
answered=0
not_validated=()

result() {
  case "$1" in
    PASS) pass=$((pass + 1)) ;;
    FAIL) fail=$((fail + 1)) ;;
    PENDING) pending=$((pending + 1)) ;;
  esac
  printf '  %-7s  %-9s  %s%s\n' "$1" "$2" "$3" "${4:+: $4}"
}

note() {
  printf '  NOTE     %s\n' "$*"
}

section() {
  printf '\n==> %s\n' "$*"
}

# jq without the carriage returns that the Windows build adds to each line.
jqr() {
  jq -r "$@" | tr -d '\r'
}

# ask NAME TYPE: the resolver's JSON answer goes into $json. Use it alone for an answer that follows a CNAME into
# Oracle's zone: that zone isn't signed, so the answer's AD flag says nothing about ours (row 8).
json=
ask() {
  json=$(curl -fsS -m 15 --retry 2 -H 'accept: application/dns-json' "$DOH?name=$1&type=$2" 2>/dev/null) || {
    json=
    return 1
  }
}

# query NAME TYPE: the same for an answer from our own zone. Also notes, for row 8, every answer that wasn't
# DNSSEC-validated (the AD flag) or that failed (SERVFAIL is what a broken DNSSEC chain gives).
query() {
  ask "$1" "$2" || return 1
  answered=$((answered + 1))
  local status ad
  status=$(jqr '.Status' <<<"$json")
  ad=$(jqr '.AD' <<<"$json")
  # 0 NOERROR, 3 NXDOMAIN (the name doesn't exist yet): both are real answers.
  if [[ ("$status" != 0 && "$status" != 3) || "$ad" != true ]]; then
    not_validated+=("$1 $2 (status $status, AD $ad)")
  fi
}

# data TYPE: the answer records of that type (1 A, 2 NS, 5 CNAME, 15 MX, 43 DS), one per line.
data() {
  # shellcheck disable=SC2016  # $t is a jq variable (--argjson), not a shell one
  jqr --argjson t "$1" '.Answer // [] | .[] | select(.type == $t) | .data' <<<"$json"
}

# TXT records, one per line, their strings joined and the quotes removed.
txt() {
  jqr '.Answer // [] | .[] | select(.type == 16) | .data | gsub("\" \""; "") | ltrimstr("\"") | rtrimstr("\"")' <<<"$json"
}

no_answer() {
  result FAIL "$1" "$2" "no answer from Cloudflare's resolver (network? run it again)"
}

redact_spf() {
  sed -E 's/(ip[46]:)[^ ]+/\1<redacted>/g'
}

redact_dmarc() {
  sed -E 's/(ru[af]=)[^;]*/\1<redacted>/g'
}

printf 'check-dns %s: %s UTC, DNS from Cloudflare over HTTPS\n' "$DOMAIN" "$(date -u '+%Y-%m-%d %H:%M')"
[[ -z "${WSL_DISTRO_NAME:-}" ]] || note "this is WSL, not Git Bash. $GIT_BASH_HINT"

# --- DNS -------------------------------------------------------------------------------------------------------------
section "DNS: the zone and DNSSEC"

if query "$DOMAIN" NS; then
  mapfile -t ns < <(data 2 | sort)
  cloudflare=0
  for name in "${ns[@]}"; do
    if [[ "$name" == *.ns.cloudflare.com. ]]; then
      cloudflare=$((cloudflare + 1))
    fi
  done
  if ((${#ns[@]} == 2 && cloudflare == 2)); then
    result PASS "row 5" "nameservers" "${ns[0]%.}, ${ns[1]%.}"
  else
    result FAIL "row 5" "nameservers" "${#ns[@]} names, $cloudflare on Cloudflare"
  fi
else
  no_answer "row 5" "nameservers"
fi

if query "$DOMAIN" DS; then
  mapfile -t ds < <(data 43)
  if ((${#ds[@]} == 1)) && [[ "${ds[0]}" =~ ^[0-9]+\ 13\ 2\ [0-9A-Fa-f]+$ ]]; then
    result PASS "row 7" "DS record in .com" "one, algorithm 13, digest type 2 (digest not shown)"
  elif ((${#ds[@]} == 0)); then
    result FAIL "row 7" "DS record in .com" "none: DNSSEC isn't active at the registry (section 4)"
  else
    result FAIL "row 7" "DS record in .com" "${#ds[@]} records, algorithm and digest type: $(cut -d' ' -f2,3 <<<"${ds[0]}")"
  fi
else
  no_answer "row 7" "DS record in .com"
fi

# Only for row 8: the zone's own signed answer.
query "$DOMAIN" SOA || true

section "DNS: email records"

spf=()
if query "$DOMAIN" TXT; then
  mapfile -t spf < <(txt | grep -iE '^v=spf1( |$)' || true)
  if ((${#spf[@]} == 0)); then
    result FAIL "row 17" "SPF" "no v=spf1 record"
  elif ((${#spf[@]} > 1)); then
    result FAIL "row 17" "SPF" "${#spf[@]} v=spf1 records: SPF fails everywhere (section 11.9, step 3)"
  else
    value=$(redact_spf <<<"${spf[0]}")
    if [[ "${spf[0]}" == "$SPF_CF" ]]; then
      result PASS "row 17" "SPF, one record" "$value"
    else
      result FAIL "row 17" "SPF, one record" "unexpected content: $value"
    fi
  fi
else
  no_answer "row 17" "SPF"
fi

if query "_dmarc.$DOMAIN" TXT; then
  mapfile -t dmarc < <(txt | grep -E '^[[:space:]]*v=DMARC1' || true)
  if ((${#dmarc[@]} == 0)); then
    result FAIL "row 18" "DMARC" "no v=DMARC1 record"
  elif ((${#dmarc[@]} > 1)); then
    result FAIL "row 18" "DMARC" "${#dmarc[@]} records: receivers ignore them all"
  elif [[ "${dmarc[0]}" =~ ^[[:space:]] ]]; then
    result FAIL "row 18" "DMARC" "something before v=DMARC1: receivers ignore it (section 13)"
  elif [[ "${dmarc[0]}" =~ ^v=DMARC1\;\ *p=quarantine\; && "${dmarc[0]}" == *"sp=quarantine"* ]]; then
    result PASS "row 18" "DMARC" "$(redact_dmarc <<<"${dmarc[0]}")"
  else
    result FAIL "row 18" "DMARC" "not p=quarantine with sp=quarantine: $(redact_dmarc <<<"${dmarc[0]}")"
  fi
else
  no_answer "row 18" "DMARC"
fi

if query "$DOMAIN" MX; then
  mapfile -t mx < <(data 15 | sort -k2)
  hosts=$(printf '%s\n' "${mx[@]}" | cut -d' ' -f2 | tr '\n' ' ')
  if [[ "$hosts" == "route1.mx.cloudflare.net. route2.mx.cloudflare.net. route3.mx.cloudflare.net. " ]]; then
    result PASS "row 26" "MX (Email Routing)" "$(printf '%s\n' "${mx[@]}" | awk '{ sub(/\.$/, "", $2); printf "%s%s (%s)", sep, $2, $1; sep = ", " }')"
  else
    result FAIL "row 26" "MX (Email Routing)" "${#mx[@]} records: ${hosts% }"
  fi
else
  no_answer "row 26" "MX (Email Routing)"
fi

if query "cf2024-1._domainkey.$DOMAIN" TXT; then
  if txt | grep -qE 'p=[A-Za-z0-9+/]'; then
    result PASS "row 27" "Email Routing DKIM" "public key present (not shown)"
  else
    result FAIL "row 27" "Email Routing DKIM" "no record with p= (section 11.9)"
  fi
else
  no_answer "row 27" "Email Routing DKIM"
fi

if query "$DKIM_SELECTOR._domainkey.$DOMAIN" CNAME; then
  if [[ -n "$(data 5)" ]]; then
    result PASS "row 22" "OCI DKIM" "CNAME present, DNS only (target not shown; Active is checked in OCI)"
  elif query "$DKIM_SELECTOR._domainkey.$DOMAIN" A && [[ -n "$(data 1)" ]]; then
    result FAIL "row 22" "OCI DKIM" "proxied (orange cloud): set DNS only (section 11.3)"
  else
    result PENDING "row 22" "OCI DKIM" "no record yet (section 11.3)"
  fi
else
  no_answer "row 22" "OCI DKIM"
fi

# Row 23 reads the SPF behind this CNAME: "ok" when the CNAME is right, "missing" when there is none yet.
return_path=bad
if query "ruh.rp.$DOMAIN" CNAME; then
  rp_cname=$(data 5)
  if [[ "${rp_cname,,}" == "$RETURN_PATH_TARGET" ]]; then
    return_path=ok
    # A CNAME can't share its name with any other record, so this also rules out an MX or TXT at ruh.rp.
    result PASS "row 33" "return path ruh.rp" "one CNAME to ${RETURN_PATH_TARGET%.}, DNS only (Active is checked in OCI)"
  elif [[ -n "$rp_cname" ]]; then
    result FAIL "row 33" "return path ruh.rp" "CNAME to ${rp_cname%.}, expected ${RETURN_PATH_TARGET%.} (section 11.4)"
  elif query "ruh.rp.$DOMAIN" A && [[ -n "$(data 1)" ]]; then
    result FAIL "row 33" "return path ruh.rp" "proxied (orange cloud): set DNS only (section 11.4)"
  elif ! query "ruh.rp.$DOMAIN" MX; then
    no_answer "row 33" "return path ruh.rp"
  elif [[ -n "$(data 15)" ]]; then
    result FAIL "row 33" "return path ruh.rp" "an MX at ruh.rp: replace it with OCI's one CNAME (section 11.4)"
  elif ! query "ruh.rp.$DOMAIN" TXT; then
    no_answer "row 33" "return path ruh.rp"
  elif [[ -n "$(txt)" ]]; then
    result FAIL "row 33" "return path ruh.rp" "a TXT at ruh.rp: replace it with OCI's one CNAME (section 11.4)"
  else
    return_path=missing
    result PENDING "row 33" "return path ruh.rp" "no record yet (section 11.4)"
  fi
else
  no_answer "row 33" "return path ruh.rp"
fi

# OCI's mail is checked against the SPF of its return path, so the main record doesn't need an OCI include. Oracle's
# record lists its senders as ip4: ranges today, so any mechanism that names a sender counts, not only include:.
if ((${#spf[@]} != 1)); then
  result FAIL "row 23" "SPF with the provider" "the main SPF isn't one record (row 17)"
elif [[ "$return_path" == missing ]]; then
  result PENDING "row 23" "SPF with the provider" "no return path yet (section 11.4)"
elif [[ "$return_path" != ok ]]; then
  result FAIL "row 23" "SPF with the provider" "the return path isn't right (row 33)"
elif ask "ruh.rp.$DOMAIN" TXT; then
  mapfile -t rp_spf < <(txt | grep -iE '^v=spf1( |$)' || true)
  if ((${#rp_spf[@]} == 1)) && [[ "${rp_spf[0]}" =~ [[:space:]](ip4:|ip6:|include:) ]]; then
    result PASS "row 23" "SPF with the provider" "Oracle's at ruh.rp: $(redact_spf <<<"${rp_spf[0]}"); the main SPF is one record"
  else
    result FAIL "row 23" "SPF with the provider" "${#rp_spf[@]} v=spf1 records behind ruh.rp, expected one that names Oracle's senders"
  fi
else
  no_answer "row 23" "SPF with the provider"
fi

if ((answered == 0)); then
  result FAIL "row 8" "DNSSEC validates" "no answers to check"
elif ((${#not_validated[@]} > 0)); then
  result FAIL "row 8" "DNSSEC validates" "not validated: $(printf '%s; ' "${not_validated[@]}")"
else
  result PASS "row 8" "DNSSEC validates" "all $answered answers above have the AD flag"
fi

# --- HTTPS -----------------------------------------------------------------------------------------------------------
section "HTTPS: staging hosts (Runbook 3, section 11)"

# fetch NAME HOST PATH: GET with certificate checks on, redirects not followed. Headers go to $tmp/NAME.head and the
# body to $tmp/NAME.body. Prints the status: 000 when there was no answer.
fetch() {
  local code
  : >"$tmp/$1.head"
  : >"$tmp/$1.body"
  code=$(curl -s -m 20 --retry 2 -o "$tmp/$1.body" -D "$tmp/$1.head" -w '%{http_code}' "https://$2$3" 2>/dev/null) || true
  printf '%s' "${code:-000}"
}

# header_all NAME FIELD: every value of that header in the response, one per line, or nothing.
header_all() {
  { grep -i "^$2:" "$tmp/$1.head" || true; } | cut -d: -f2- | tr -d '\r' | sed 's/^ *//'
}

# header NAME FIELD: the last value of that header in the response, or nothing.
header() {
  header_all "$1" "$2" | tail -n 1
}

# hsts_ok VALUE...: at least one value, and each has the 6-month max-age and includeSubDomains, without preload. Every
# line counts: Cloudflare and the backend can each send one, and browsers obey only the first.
hsts_ok() {
  (($# > 0)) || return 1
  local value
  for value in "$@"; do
    [[ "$value" =~ $HSTS_MAX_AGE_RE && "$value" == *[Ii]nclude[Ss]ub[Dd]omains* && "$value" != *[Pp]reload* ]] || return 1
  done
}

origin_down() {
  [[ "$ORIGIN_DOWN" == *" $1 "* ]]
}

# not_up ROW LABEL STATUS...: prints FAIL or PENDING and succeeds when one of the answers can't be checked.
not_up() {
  local row=$1 label=$2 status
  shift 2
  for status in "$@"; do
    if [[ "$status" == 000 ]]; then
      result FAIL "$row" "$label" "no HTTPS answer (network? run it again from the VM)"
      return 0
    fi
  done
  for status in "$@"; do
    if origin_down "$status"; then
      result PENDING "$row" "$label" "staging isn't answering (HTTP $status): check the stack first (Runbook 5)"
      return 0
    fi
  done
  return 1
}

app=$(fetch app "staging-app.$DOMAIN" /)
api=$(fetch api "staging-api.$DOMAIN" /api/health/)
api2=$(fetch api2 "staging-api.$DOMAIN" /api/health/)

if ! not_up "row 19" "HSTS" "$app" "$api"; then
  mapfile -t app_hsts < <(header_all app strict-transport-security)
  mapfile -t api_hsts < <(header_all api strict-transport-security)
  if ((${#app_hsts[@]} == 0)); then
    result PENDING "row 19" "HSTS" "no header on staging-app yet: the web app is live, HSTS is the last step of #35 (section 7)"
  elif hsts_ok "${app_hsts[@]}" && hsts_ok "${api_hsts[@]}"; then
    result PASS "row 19" "HSTS" "${#app_hsts[@]} header(s) on staging-app, ${#api_hsts[@]} on staging-api, all: ${app_hsts[0]}"
  else
    result FAIL "row 19" "HSTS" "staging-app: $(IFS='|'; printf '%s' "${app_hsts[*]:-none}"); staging-api: $(IFS='|'; printf '%s' "${api_hsts[*]:-none}") (section 7)"
  fi
fi

if ! not_up "row 20" "API not rewritten" "$api"; then
  problems=()
  [[ "$api" == 200 ]] || problems+=("HTTP $api")
  jq -e . "$tmp/api.body" >/dev/null 2>&1 || problems+=("not JSON")
  ! grep -qiE 'rocket-loader|email-decode' "$tmp/api.body" || problems+=("injected script found")
  if ((${#problems[@]} == 0)); then
    result PASS "row 20" "API not rewritten" "HTTP 200, JSON, no injected script"
  else
    result FAIL "row 20" "API not rewritten" "$(printf '%s, ' "${problems[@]}" | sed 's/, $//')"
  fi
fi

if ! not_up "R3 row 23" "API never cached" "$api" "$api2"; then
  first=$(header api cf-cache-status)
  second=$(header api2 cf-cache-status)
  if [[ "$first" =~ ^(DYNAMIC|BYPASS)$ && "$second" =~ ^(DYNAMIC|BYPASS)$ ]]; then
    result PASS "R3 row 23" "API never cached" "cf-cache-status $first, then $second"
  else
    result FAIL "R3 row 23" "API never cached" "cf-cache-status ${first:-none}, then ${second:-none}"
  fi
fi

# --- Summary ---------------------------------------------------------------------------------------------------------
section "Summary"
note "by hand (Runbook 2, section 12.2): rows 1-4, 6, 9-16, 21, 24, 25, 28-32 and 34; the OCI pages of rows 22 and 33"
printf '  %s PASS, %s FAIL, %s PENDING\n' "$pass" "$fail" "$pending"

((fail == 0)) || exit 1
