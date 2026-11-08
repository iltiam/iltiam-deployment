#!/usr/bin/env bash
# Safe manual test of an Authentica API key (Runbook 12, issue #15). Run it on its own, not from CI or a deploy.
#
# Usage, on the VM (copy it with scp, Runbook 12, section 6) or on a laptop:
#   bash check-authentica.sh balance    read the balance. Sends nothing
#   bash check-authentica.sh send-otp   send ONE real SMS with a random test code. Costs 1 point
#
# send-otp is what the backend will send once iltiam-backend#103 is deployed: POST /send-otp with method sms and our
# own code, no sender name, so Authentica's default sender is used. It reads the balance before and after, and prints
# the code the SMS must show. A code in the SMS that differs from it is a FAIL, whatever the HTTP status says.
#
# Every value is asked for at a prompt, never taken as an argument. The key is read without showing it, and it reaches
# curl through a pipe (curl --config -), so it isn't in the shell history, in `ps` or in any file. Never add `set -x`.
# Exit 0 when Authentica accepted every call; 1 otherwise. An accepted call doesn't prove the SMS arrived: look at the
# phone.

set -euo pipefail

API=https://api.authentica.sa/api/v2

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 1 && ("$1" == balance || "$1" == send-otp) ]] || die "usage: $0 <balance|send-otp>"
mode="$1"
command -v curl >/dev/null 2>&1 || die "curl not found"

# Print Authentica's answer and the HTTP status; fail unless the status is 2xx. $1 is the path after /api/v2/, and $2 a
# JSON body with its double quotes escaped for curl's config format.
request() {
  local path="$1" body="${2:-}" answer
  answer="$(
    {
      printf 'header = "X-Authorization: %s"\n' "$api_key"
      if [[ -n "$body" ]]; then
        printf 'header = "Content-Type: application/json"\n'
        printf 'data-binary = "%s"\n' "$body"
      fi
    } | curl -sS --max-time 20 --config - -H 'Accept: application/json' -w '\nHTTP %{http_code}\n' "$API/$path"
  )" || die "could not reach Authentica (see the curl error above)"
  printf '%s\n' "$answer"
  [[ "$answer" =~ HTTP\ 2[0-9][0-9]$ ]]
}

read -rsp 'API key (hidden): ' api_key
echo
[[ -n "$api_key" ]] || die "no key entered"
[[ "$api_key" != *[\"\\]* ]] || die "the key contains a quote or a backslash, so it was probably not copied cleanly"

if [[ "$mode" == balance ]]; then
  echo '--- balance'
  request balance || die "Authentica refused the call. HTTP 401 means a wrong key"
  exit 0
fi

read -rp 'Your phone (+9665XXXXXXXX): ' phone
[[ "$phone" =~ ^\+9665[0-9]{8}$ ]] || die "the phone must look like +9665XXXXXXXX"
read -rp 'Template ID (press Enter for the default): ' template
[[ "$template" =~ ^[0-9]*$ ]] || die "the template ID must be a whole number"

code="$(shuf -i 100000-999999 -n 1)"
body="{\\\"method\\\":\\\"sms\\\",\\\"phone\\\":\\\"$phone\\\",\\\"otp\\\":\\\"$code\\\""
if [[ -n "$template" ]]; then body+=",\\\"template_id\\\":$template"; fi
body+="}"

echo '--- balance before'
request balance || die "Authentica refused the call, so nothing was sent. HTTP 401 means a wrong key"
printf -- '--- sending. THE SMS MUST SHOW THIS CODE: %s\n' "$code"
request send-otp "$body" || die "Authentica refused the send (see the answer above)"
echo '--- waiting 20 seconds'
sleep 20
echo '--- balance after'
request balance || die "the balance call failed; check the balance in the dashboard"
printf -- '--- the code we sent: %s\n' "$code"
echo 'PASS only if the SMS shows exactly this code. Now run: clear'
