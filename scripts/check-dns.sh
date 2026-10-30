#!/usr/bin/env bash
# Check iltiamcare.com from the outside (Runbook 2, issue #12): the rows of the checklist in
# docs/runbooks/02-cloudflare-dns-tls.md, section 12.2, that a command can decide. DNS, the email records and the
# HTTPS headers of the staging hosts. Read-only: it only asks Cloudflare's resolver and fetches two public pages.
#
# Usage, in Git Bash on a laptop or on iltiam-1:
#   bash scripts/check-dns.sh
#
# Optional, from the environment:
#   DKIM_SELECTOR  the OCI DKIM selector of section 11.3 (e.g. iltiam-ruh-202611); without it row 22 is PENDING
#
# DNS goes to Cloudflare's resolver over HTTPS (DoH), so it works where `dig` is missing (Git Bash) and on networks
# that block port 53 to outside resolvers. Needs curl and jq.
#
# Each output line names its checklist row ("row 18"; "R3 row 23" is Runbook 3's checklist). The output is the one to
# paste into the issue: the DMARC report address and the DS digest are redacted, and no IP, ID or URL is printed.
#   PASS     the row's command check passed
#   FAIL     it failed, or a query got no answer
#   PENDING  can't pass yet: the record or the origin doesn't exist yet (after the SMTP provider, after #2)
#   NOTE     not counted
# Rows that need the dashboard, a mailbox, OCI or SSL Labs are not checked here; the last NOTE lists them.
# Exit 0 when nothing failed (PENDING lines allowed); 1 when a check failed. Some networks break the HTTPS checks
# (no answer, FAIL): run it again from a phone hotspot.

set -euo pipefail

DOMAIN=iltiamcare.com
DOH=https://cloudflare-dns.com/dns-query
SPF_CF="v=spf1 include:_spf.mx.cloudflare.net -all"
SPF_OCI="v=spf1 include:_spf.mx.cloudflare.net include:ap.rp.oracleemaildelivery.com -all"
# OCI's "All Commercial Regions" fallback (Runbook 2, section 11.4).
SPF_OCI_ALL="v=spf1 include:_spf.mx.cloudflare.net include:rp.oracleemaildelivery.com include:ap.rp.oracleemaildelivery.com include:eu.rp.oracleemaildelivery.com -all"
RETURN_PATH_MX="10 bmta.email.me-riyadh-1.oci.oraclecloud.com."
# Statuses Cloudflare answers itself when nothing runs behind the tunnel yet (530: no connector for the hostname).
ORIGIN_DOWN=" 502 503 504 521 522 523 524 530 "

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 0 ]] || die "usage: $0 (no arguments; DKIM_SELECTOR from the environment)"
command -v curl >/dev/null 2>&1 || die "curl not found"
command -v jq >/dev/null 2>&1 || die "jq not found"
[[ -z "${DKIM_SELECTOR:-}" || "$DKIM_SELECTOR" =~ ^[A-Za-z0-9-]+$ ]] || die "DKIM_SELECTOR: letters, digits and dashes only"

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

# query NAME TYPE: the resolver's JSON answer goes into $json. Also notes, for row 8, every answer that wasn't
# DNSSEC-validated (the AD flag) or that failed (SERVFAIL is what a broken DNSSEC chain gives).
json=
query() {
  json=$(curl -fsS -m 15 --retry 2 -H 'accept: application/dns-json' "$DOH?name=$1&type=$2" 2>/dev/null) || {
    json=
    return 1
  }
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

if query "$DOMAIN" TXT; then
  mapfile -t spf < <(txt | grep -iE '^v=spf1( |$)' || true)
  if ((${#spf[@]} == 0)); then
    result FAIL "row 17" "SPF" "no v=spf1 record"
  elif ((${#spf[@]} > 1)); then
    result FAIL "row 17" "SPF" "${#spf[@]} v=spf1 records: SPF fails everywhere (section 11.9, step 3)"
  else
    value=$(redact_spf <<<"${spf[0]}")
    case "${spf[0]}" in
      "$SPF_CF")
        result PASS "row 17" "SPF, one record" "$value"
        result PENDING "row 23" "SPF with the provider" "no OCI include yet (section 11.4)"
        ;;
      "$SPF_OCI" | "$SPF_OCI_ALL")
        result PASS "row 17" "SPF, one record"
        result PASS "row 23" "SPF with the provider" "$value (the OCI page is checked by hand)"
        ;;
      *)
        result FAIL "row 17" "SPF, one record" "unexpected content: $value"
        ;;
    esac
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

if [[ -z "${DKIM_SELECTOR:-}" ]]; then
  result PENDING "row 22" "OCI DKIM" "set DKIM_SELECTOR after section 11.3"
elif query "$DKIM_SELECTOR._domainkey.$DOMAIN" CNAME; then
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

if query "ruh.rp.$DOMAIN" MX; then
  mapfile -t rp_mx < <(data 15)
  if query "ruh.rp.$DOMAIN" TXT; then
    rp_spf=$(txt | grep -ciE '^v=spf1( |$)' || true)
    if ((${#rp_mx[@]} == 0 && rp_spf == 0)); then
      result PENDING "row 33" "return path ruh.rp" "no records yet (section 11.4)"
    elif ((${#rp_mx[@]} == 1 && rp_spf == 1)) && [[ "${rp_mx[0]}" == "$RETURN_PATH_MX" ]]; then
      result PASS "row 33" "return path ruh.rp" "MX ${RETURN_PATH_MX%.}, one v=spf1 TXT (the OCI page is checked by hand)"
    else
      result FAIL "row 33" "return path ruh.rp" "${#rp_mx[@]} MX (${rp_mx[*]:-none}), $rp_spf v=spf1 TXT; expected MX ${RETURN_PATH_MX%.} and one TXT"
    fi
  else
    no_answer "row 33" "return path ruh.rp"
  fi
else
  no_answer "row 33" "return path ruh.rp"
fi

if ((answered == 0)); then
  result FAIL "row 8" "DNSSEC validates" "no answers to check"
elif ((${#not_validated[@]} > 0)); then
  result FAIL "row 8" "DNSSEC validates" "not validated: $(printf '%s; ' "${not_validated[@]}")"
else
  result PASS "row 8" "DNSSEC validates" "all $answered answers above have the AD flag"
fi

# --- HTTPS -----------------------------------------------------------------------------------------------------------
section "HTTPS: staging hosts (after #2 deploys staging; Runbook 3, section 11)"

# fetch NAME HOST PATH: GET with certificate checks on, redirects not followed. Headers go to $tmp/NAME.head and the
# body to $tmp/NAME.body. Prints the status: 000 when there was no answer.
fetch() {
  local code
  : >"$tmp/$1.head"
  : >"$tmp/$1.body"
  code=$(curl -s -m 20 --retry 2 -o "$tmp/$1.body" -D "$tmp/$1.head" -w '%{http_code}' "https://$2$3" 2>/dev/null) || true
  printf '%s' "${code:-000}"
}

# header NAME FIELD: the last value of that header in the response, or nothing.
header() {
  { grep -i "^$2:" "$tmp/$1.head" || true; } | tail -n 1 | cut -d: -f2- | tr -d '\r' | sed 's/^ *//'
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
      result FAIL "$row" "$label" "no HTTPS answer (network? run it again from a phone hotspot)"
      return 0
    fi
  done
  for status in "$@"; do
    if origin_down "$status"; then
      result PENDING "$row" "$label" "staging isn't deployed yet (HTTP $status): after #2"
      return 0
    fi
  done
  return 1
}

app=$(fetch app "staging-app.$DOMAIN" /)
api=$(fetch api "staging-api.$DOMAIN" /api/health/)
api2=$(fetch api2 "staging-api.$DOMAIN" /api/health/)

if ! not_up "row 19" "HSTS" "$app" "$api"; then
  app_hsts=$(header app strict-transport-security)
  api_hsts=$(header api strict-transport-security)
  if [[ -z "$app_hsts" ]]; then
    result PENDING "row 19" "HSTS" "no header on staging-app yet (section 7)"
  elif [[ "$app_hsts" == *max-age=15552000* && "$app_hsts" == *[Ii]nclude[Ss]ub[Dd]omains* &&
    "$api_hsts" == *max-age=15552000* && "$api_hsts" == *[Ii]nclude[Ss]ub[Dd]omains* ]]; then
    result PASS "row 19" "HSTS" "staging-app and staging-api: $app_hsts"
  else
    result FAIL "row 19" "HSTS" "staging-app: ${app_hsts:-none}; staging-api: ${api_hsts:-none} (section 7)"
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
note "by hand (Runbook 2, section 12.2): rows 1-4, 6, 9-16, 21, 24, 25, 28-32 and 34; the OCI pages of rows 22, 23 and 33"
printf '  %s PASS, %s FAIL, %s PENDING\n' "$pass" "$fail" "$pending"

((fail == 0)) || exit 1
