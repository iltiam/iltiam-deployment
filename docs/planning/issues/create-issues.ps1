<#
  Creates milestones v1.0 and v1.1 in every repo, creates new issues and updates existing ones in dependency
  order, then rewrites plan IDs (BE-06, DEP#7 ...) in every body into real cross-repo references.
  Review first, then run from this folder:
      powershell -ExecutionPolicy Bypass -File .\create-issues.ps1 -DryRun   # print what would happen
      powershell -ExecutionPolicy Bypass -File .\create-issues.ps1           # do it
  Needs: gh authenticated with write access to every iltiam repo (gh auth status).
  Re-runnable: created issues are recorded in created-map.json and skipped next time.
#>
param([switch]$DryRun)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$Org = 'iltiam'
$MapFile = Join-Path $PSScriptRoot 'created-map.json'
$Map = @{}
if (Test-Path $MapFile) { (Get-Content $MapFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $Map[$_.Name] = $_.Value } }
function Save-Map { if (-not $DryRun) { [System.IO.File]::WriteAllText($MapFile, ($Map | ConvertTo-Json), (New-Object System.Text.UTF8Encoding $false)) } }
function Run([string[]]$GhArgs) {
  if ($DryRun) { Write-Host "gh $($GhArgs -join ' ')"; return 'https://github.com/iltiam/dry-run/issues/0' }
  $out = & gh @GhArgs
  if ($LASTEXITCODE -ne 0) { throw "gh failed: $($GhArgs -join ' ')" }
  return $out
}

# ---------------------------------------------------------------- 1. milestones v1.0 and v1.1 (all repos)
$Repos = @('iltiam-ai-service', 'iltiam-backend', 'iltiam-deployment', 'iltiam-mobile', 'iltiam-web')
foreach ($repo in $Repos) {
  $existing = (& gh api "repos/$Org/$repo/milestones?state=all&per_page=100" --jq '.[].title') -split "`n"
  if ($existing -notcontains 'v1.0') { Run @('api', "repos/$Org/$repo/milestones", '-f', 'title=v1.0', '-f', 'description=Production release: every SRS feature for every actor on web, Android (patient + doctor) and backend/AI, deployed on Oracle Cloud Riyadh behind Cloudflare, with CI/CD, backups and monitoring.', '-f', 'due_on=2026-11-30T20:59:59Z') | Out-Null }
  if ($existing -notcontains 'v1.1') { Run @('api', "repos/$Org/$repo/milestones", '-f', 'title=v1.1', '-f', 'description=After v1.0: iOS builds, TestFlight and the App Store release.') | Out-Null }
}
# Optional housekeeping (uncomment): close the old milestones v0.1.0-v0.4.0 once their issues have moved.
# foreach ($repo in $Repos) { foreach ($t in @('v0.1.0 contract skeleton','v0.2.0 critical path','v0.3.0 hackathon-ready','v0.4.0 SWE496 demo')) {
#   $n = & gh api "repos/$Org/$repo/milestones?state=open" --jq ".[] | select(.title==\"$t\") | .number"
#   if ($n) { Run @('api', '-X', 'PATCH', "repos/$Org/$repo/milestones/$n", '-f', 'state=closed') | Out-Null } } }

# ---------------------------------------------------------------- 2. issues in dependency order
$Map['BE#55'] = "$Org/iltiam-backend#55"
Run @('issue', 'edit', '55', '--repo', "$Org/iltiam-backend", '--milestone', 'v1.0') | Out-Null
$Map['BE#57'] = "$Org/iltiam-backend#57"
Run @('issue', 'edit', '57', '--repo', "$Org/iltiam-backend", '--milestone', 'v1.0') | Out-Null
$Map['BE#56'] = "$Org/iltiam-backend#56"
Run @('issue', 'edit', '56', '--repo', "$Org/iltiam-backend", '--milestone', 'v1.0') | Out-Null
$Map['DEP#7'] = "$Org/iltiam-deployment#7"
Run @('issue', 'edit', '7', '--repo', "$Org/iltiam-deployment", '--milestone', 'v1.0', '--title', 'Runbook 1: Oracle Always Free account (Riyadh), $10 budget alert, one Ampere A1 VM with Docker', '--body-file', 'updates/iltiam-deployment-7.md', '--add-label', 'area:deployment', '--add-label', 'type:feat', '--add-label', 'priority:p0', '--add-label', 'srs', '--remove-label', 'priority:p1', '--add-assignee', 'ben-fatah', '--remove-assignee', 'Omar-Nasri') | Out-Null
if (-not $Map.ContainsKey('AI-12')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-ai-service", '--title', 'ARM go/no-go: measure the analysis latency on the Ampere A1 VM against the 4 s budget', '--body-file', 'iltiam-ai-service/AI-12-arm-go-no-go-measure-the-analysis-latency-on-the-ampere-a1-v.md', '--label', 'area:ai', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'ben-fatah', '--milestone', 'v1.0')
  $Map['AI-12'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-01')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'OpenAPI as the single API contract: versioning, breaking-change check, published artifact', '--body-file', 'iltiam-backend/BE-01-openapi-as-the-single-api-contract-versioning-breaking-chang.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-01'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-02')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Health and readiness endpoints', '--body-file', 'iltiam-backend/BE-02-health-and-readiness-endpoints.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-02'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
$Map['DEP#1'] = "$Org/iltiam-deployment#1"
Run @('issue', 'edit', '1', '--repo', "$Org/iltiam-deployment", '--milestone', 'v1.0', '--title', 'Reusable GitHub Actions workflows (python-ci, node-ci, flutter-ci, multi-arch docker build+push to GHCR)', '--body-file', 'updates/iltiam-deployment-1.md', '--add-label', 'area:deployment', '--add-label', 'type:chore', '--add-label', 'priority:p0', '--add-label', 'srs', '--remove-label', 'hackathon', '--add-assignee', 'ben-fatah') | Out-Null
if (-not $Map.ContainsKey('BE-04')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Backend Dockerfile (web, worker, beat) and production entrypoint', '--body-file', 'iltiam-backend/BE-04-backend-dockerfile-web-worker-beat-and-production-entrypoint.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-04'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
$Map['DEP#3'] = "$Org/iltiam-deployment#3"
Run @('issue', 'edit', '3', '--repo', "$Org/iltiam-deployment", '--milestone', 'v1.0', '--title', 'Runbook 4: secrets and environment files (GitHub Environments, rotation, third-party keys)', '--body-file', 'updates/iltiam-deployment-3.md', '--add-label', 'area:deployment', '--add-label', 'type:chore', '--add-label', 'priority:p0', '--add-label', 'srs', '--remove-label', 'hackathon', '--remove-label', 'priority:p1', '--add-assignee', 'ben-fatah', '--remove-assignee', 'Omar-Nasri') | Out-Null
if (-not $Map.ContainsKey('DEP-01')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-deployment", '--title', 'Runbook 2: Cloudflare account, DNS for <DOMAIN>, SSL/TLS and email records', '--body-file', 'iltiam-deployment/DEP-01-runbook-2-cloudflare-account-dns-for-domain-ssl-tls-and-emai.md', '--label', 'area:deployment', '--label', 'type:chore', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'ben-fatah', '--milestone', 'v1.0')
  $Map['DEP-01'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-01')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Generated API client from the backend OpenAPI; replace guessed Dio paths', '--body-file', 'iltiam-mobile/MOB-01-generated-api-client-from-the-backend-openapi-replace-guesse.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-01'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-02')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Build flavors and platform config: dev/staging/prod, network security, no mock in production', '--body-file', 'iltiam-mobile/MOB-02-build-flavors-and-platform-config-dev-staging-prod-network-s.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-02'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-03')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Internal distribution: CI builds staging Android builds and ships them to testers', '--body-file', 'iltiam-mobile/MOB-03-internal-distribution-ci-builds-staging-android-builds-and-s.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-03'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-01')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Green CI on main and repo hygiene', '--body-file', 'iltiam-web/WEB-01-green-ci-on-main-and-repo-hygiene.md', '--label', 'area:web', '--label', 'type:chore', '--label', 'priority:p0', '--label', 'bug', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['WEB-01'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-02')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Generated API client from the backend OpenAPI, data layer, mocks only in tests', '--body-file', 'iltiam-web/WEB-02-generated-api-client-from-the-backend-openapi-data-layer-moc.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['WEB-02'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-03')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Production container: static build on NGINX, runtime config, CSP', '--body-file', 'iltiam-web/WEB-03-production-container-static-build-on-nginx-runtime-config-cs.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['WEB-03'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-06')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Doctor: patient list (search, filters, risk colours) and register patient on the API', '--body-file', 'iltiam-web/WEB-06-doctor-patient-list-search-filters-risk-colours-and-register.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['WEB-06'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-08')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Doctor: wound photo upload on the API (8 MP, 50 mm marker, duplicate confirm, queue position)', '--body-file', 'iltiam-web/WEB-08-doctor-wound-photo-upload-on-the-api-8-mp-50-mm-marker-dupli.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['WEB-08'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('AI-07')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-ai-service", '--title', 'Production image (linux/arm64) and weights delivery for staging and production', '--body-file', 'iltiam-ai-service/AI-07-production-image-linux-arm64-and-weights-delivery-for-stagin.md', '--label', 'area:ai', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'ben-fatah', '--milestone', 'v1.0')
  $Map['AI-07'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('AI-10')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-ai-service", '--title', 'Contract release process: versioned schemas/OpenAPI artifacts and a vendoring script', '--body-file', 'iltiam-ai-service/AI-10-contract-release-process-versioned-schemas-openapi-artifacts.md', '--label', 'area:ai', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'ben-fatah', '--milestone', 'v1.0')
  $Map['AI-10'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-03')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Production settings hardening, security headers, structured logs, request-id propagation', '--body-file', 'iltiam-backend/BE-03-production-settings-hardening-security-headers-structured-lo.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-03'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-05')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'File URLs reachable by web and mobile (public storage endpoint, absolute media URLs)', '--body-file', 'iltiam-backend/BE-05-file-urls-reachable-by-web-and-mobile-public-storage-endpoin.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-05'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-31')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Production bootstrap and staging test accounts', '--body-file', 'iltiam-backend/BE-31-production-bootstrap-and-staging-test-accounts.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-31'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-32')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Sync vendored AI contract to the released version and use realistic fixtures', '--body-file', 'iltiam-backend/BE-32-sync-vendored-ai-contract-to-the-released-version-and-use-re.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-32'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
$Map['DEP#9'] = "$Org/iltiam-deployment#9"
Run @('issue', 'edit', '9', '--repo', "$Org/iltiam-deployment", '--milestone', 'v1.0', '--title', 'Runbook 3: Cloudflare Tunnels for staging and production, cache and security rules (no public web ports)', '--body-file', 'updates/iltiam-deployment-9.md', '--add-label', 'area:deployment', '--add-label', 'type:feat', '--add-label', 'priority:p0', '--add-label', 'srs', '--remove-label', 'priority:p2', '--add-assignee', 'ben-fatah', '--remove-assignee', 'Omar-Nasri') | Out-Null
if (-not $Map.ContainsKey('DEP-02')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-deployment", '--title', 'Runbook 8: object storage within the free 20 GB, software Vault keys, S3 credentials', '--body-file', 'iltiam-deployment/DEP-02-runbook-8-object-storage-within-the-free-20-gb-software-vaul.md', '--label', 'area:deployment', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'ben-fatah', '--milestone', 'v1.0')
  $Map['DEP-02'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('DEP-13')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-deployment", '--title', 'Runbook 11: Firebase project for FCM push on Android (service account and app configs)', '--body-file', 'iltiam-deployment/DEP-13-runbook-11-firebase-project-for-fcm-push-on-android-service.md', '--label', 'area:deployment', '--label', 'type:chore', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'ben-fatah', '--milestone', 'v1.0')
  $Map['DEP-13'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('DEP-14')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-deployment", '--title', 'Runbook 12: Authentica account, sender name and API key for phone codes', '--body-file', 'iltiam-deployment/DEP-14-runbook-12-authentica-account-sender-name-and-api-key-for-ph.md', '--label', 'area:deployment', '--label', 'type:chore', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'ben-fatah', '--milestone', 'v1.0')
  $Map['DEP-14'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-04')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Sign-in on the real backend: phone + password + OTP (SMS/email/authenticator), tokens, refresh, role routing', '--body-file', 'iltiam-mobile/MOB-04-sign-in-on-the-real-backend-phone-password-otp-sms-email-aut.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-04'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-05')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Sign-in security: CAPTCHA after 3 failures, remember device 30 days, biometric unlock, 15-min timeout', '--body-file', 'iltiam-mobile/MOB-05-sign-in-security-captcha-after-3-failures-remember-device-30.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-05'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-28a')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Google Play Console: app, Play App Signing, internal testing, and a 14-day closed test with 12 testers', '--body-file', 'iltiam-mobile/MOB-28a-google-play-console-app-play-app-signing-internal-testing-an.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-28a'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-04')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Real sign-in: password, OTP (SMS/email/authenticator), resend, CAPTCHA, lockout, timeout, role routing', '--body-file', 'iltiam-web/WEB-04-real-sign-in-password-otp-sms-email-authenticator-resend-cap.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['WEB-04'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-05')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Account activation, invitations, authenticator setup, password reset and change', '--body-file', 'iltiam-web/WEB-05-account-activation-invitations-authenticator-setup-password.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['WEB-05'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-11')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Doctor: analyses needing attention, retry, and failure notifications', '--body-file', 'iltiam-web/WEB-11-doctor-analyses-needing-attention-retry-and-failure-notifica.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['WEB-11'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-13')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Doctor: alerts panel, acknowledge with justification, risk-ranked dashboard', '--body-file', 'iltiam-web/WEB-13-doctor-alerts-panel-acknowledge-with-justification-risk-rank.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['WEB-13'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('AI-01')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-ai-service", '--title', '/capabilities: registry metrics, release date and registry name of the loaded model', '--body-file', 'iltiam-ai-service/AI-01-capabilities-registry-metrics-release-date-and-registry-name.md', '--label', 'area:ai', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'ben-fatah', '--milestone', 'v1.0')
  $Map['AI-01'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-06')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Doctor visit detail: photo and mask URLs, measurement and applied threshold', '--body-file', 'iltiam-backend/BE-06-doctor-visit-detail-photo-and-mask-urls-measurement-and-appl.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-06'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-07')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'List a wound''s visits for doctor and patient (submission history and image timeline)', '--body-file', 'iltiam-backend/BE-07-list-a-wound-s-visits-for-doctor-and-patient-submission-hist.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-07'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-07')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Doctor: patient profile with wounds and image timeline', '--body-file', 'iltiam-web/WEB-07-doctor-patient-profile-with-wounds-and-image-timeline.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['WEB-07'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-26')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Clinic-scoped account event log for Clinic Admins', '--body-file', 'iltiam-backend/BE-26-clinic-scoped-account-event-log-for-clinic-admins.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['BE-26'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-39')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Patient result: "wound not found" asks for a retake and says the doctor will review', '--body-file', 'iltiam-backend/BE-39-patient-result-wound-not-found-asks-for-a-retake-and-says-th.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-39'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
$Map['DEP#2'] = "$Org/iltiam-deployment#2"
Run @('issue', 'edit', '2', '--repo', "$Org/iltiam-deployment", '--milestone', 'v1.0', '--title', 'Runbook 5: staging and production as two Compose projects on one ARM VM (memory budget, private AI)', '--body-file', 'updates/iltiam-deployment-2.md', '--add-label', 'area:deployment', '--add-label', 'type:feat', '--add-label', 'priority:p0', '--add-label', 'srs', '--remove-label', 'hackathon', '--add-assignee', 'ben-fatah', '--remove-assignee', 'Omar-Nasri') | Out-Null
if (-not $Map.ContainsKey('MOB-07')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Patient photo upload on the real backend (fields, duplicate 409, idempotency, offline queue)', '--body-file', 'iltiam-mobile/MOB-07-patient-photo-upload-on-the-real-backend-fields-duplicate-40.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-07'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-08')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Patient result screen on the real backend (5 states, tips, overlay, disclaimer)', '--body-file', 'iltiam-mobile/MOB-08-patient-result-screen-on-the-real-backend-5-states-tips-over.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-08'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-09')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Doctor: AI result view on the API (statuses, reasons, overlay toggle, measurement, risk, versions)', '--body-file', 'iltiam-web/WEB-09-doctor-ai-result-view-on-the-api-statuses-reasons-overlay-to.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['WEB-09'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-10')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Doctor: review (approve / override with justification), side-by-side, feedback consent', '--body-file', 'iltiam-web/WEB-10-doctor-review-approve-override-with-justification-side-by-si.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['WEB-10'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('AI-02')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-ai-service", '--title', 'Per-request manual-review threshold for FR-D-5 governance', '--body-file', 'iltiam-ai-service/AI-02-per-request-manual-review-threshold-for-fr-d-5-governance.md', '--label', 'area:ai', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'ben-fatah', '--milestone', 'v1.0')
  $Map['AI-02'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('AI-04')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-ai-service", '--title', 'Observability: Prometheus /metrics, JSON logs, job timing histograms', '--body-file', 'iltiam-ai-service/AI-04-observability-prometheus-metrics-json-logs-job-timing-histog.md', '--label', 'area:ai', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'ben-fatah', '--milestone', 'v1.0')
  $Map['AI-04'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-08')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Wound images: strip EXIF (GPS) and normalise orientation on upload', '--body-file', 'iltiam-backend/BE-08-wound-images-strip-exif-gps-and-normalise-orientation-on-upl.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-08'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-09')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Dev/staging command: seed a real dated analysis series through the AI pipeline', '--body-file', 'iltiam-backend/BE-09-dev-staging-command-seed-a-real-dated-analysis-series-throug.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-09'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-12')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Doctor: progression timeline on the API (chart, healing rate, colours, alerts, model-change warning)', '--body-file', 'iltiam-web/WEB-12-doctor-progression-timeline-on-the-api-chart-healing-rate-co.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['WEB-12'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-12')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Step-up verification (re-enter OTP) for sensitive actions', '--body-file', 'iltiam-backend/BE-12-step-up-verification-re-enter-otp-for-sensitive-actions.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-12'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-27')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Backend metrics endpoint (django-prometheus, Celery queue metrics)', '--body-file', 'iltiam-backend/BE-27-backend-metrics-endpoint-django-prometheus-celery-queue-metr.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['BE-27'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('DEP-03')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-deployment", '--title', 'Runbook 9: continuous deployment to the staging project on merge to main', '--body-file', 'iltiam-deployment/DEP-03-runbook-9-continuous-deployment-to-the-staging-project-on-me.md', '--label', 'area:deployment', '--label', 'type:feat', '--label', 'priority:p0', '--assignee', 'ben-fatah', '--milestone', 'v1.0')
  $Map['DEP-03'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('DEP-10')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-deployment", '--title', 'Cross-repo end-to-end smoke after every staging deploy', '--body-file', 'iltiam-deployment/DEP-10-cross-repo-end-to-end-smoke-after-every-staging-deploy.md', '--label', 'area:deployment', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['DEP-10'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-09')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Patient wounds list and submission history (filters, thumbnails, AI summary)', '--body-file', 'iltiam-mobile/MOB-09-patient-wounds-list-and-submission-history-filters-thumbnail.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-09'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('AI-03')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-ai-service", '--title', 'Threshold re-evaluation report from stored validation predictions', '--body-file', 'iltiam-ai-service/AI-03-threshold-re-evaluation-report-from-stored-validation-predic.md', '--label', 'area:ai', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'ben-fatah', '--milestone', 'v1.0')
  $Map['AI-03'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-19')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Push notifications in production: FCM (Android), device lifecycle, test push', '--body-file', 'iltiam-backend/BE-19-push-notifications-in-production-fcm-android-device-lifecycl.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-19'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-11')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Push notifications with FCM on Android (setup and device registration)', '--body-file', 'iltiam-mobile/MOB-11-push-notifications-with-fcm-on-android-setup-and-device-regi.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-11'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-20')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Phone codes through Authentica, email provider, and the OTP fallback prompt', '--body-file', 'iltiam-backend/BE-20-phone-codes-through-authentica-email-provider-and-the-otp-fa.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-20'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-25')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Super Admin doctor lifecycle across clinics: deactivate, archive, soft delete', '--body-file', 'iltiam-backend/BE-25-super-admin-doctor-lifecycle-across-clinics-deactivate-archi.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['BE-25'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-37')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Doctor dashboard summary endpoint (risk-ranked worklist)', '--body-file', 'iltiam-backend/BE-37-doctor-dashboard-summary-endpoint-risk-ranked-worklist.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-37'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
$Map['DEP#6'] = "$Org/iltiam-deployment#6"
Run @('issue', 'edit', '6', '--repo', "$Org/iltiam-deployment", '--milestone', 'v1.0', '--title', 'PDPL mapping, ROPA, retention schedule, consent texts and user agreement', '--body-file', 'updates/iltiam-deployment-6.md', '--add-label', 'area:deployment', '--add-label', 'type:docs', '--add-label', 'priority:p0', '--add-label', 'srs', '--remove-label', 'priority:p1', '--add-assignee', 'ben-fatah') | Out-Null
$Map['DEP#8'] = "$Org/iltiam-deployment#8"
Run @('issue', 'edit', '8', '--repo', "$Org/iltiam-deployment", '--milestone', 'v1.0', '--title', 'Runbook 6: free backups and a weekly tested restore on the VM (Postgres dumps, volume backups)', '--body-file', 'updates/iltiam-deployment-8.md', '--add-label', 'area:deployment', '--add-label', 'type:chore', '--add-label', 'priority:p0', '--add-label', 'srs', '--remove-label', 'priority:p1', '--add-assignee', 'ben-fatah', '--remove-assignee', 'Omar-Nasri') | Out-Null
if (-not $Map.ContainsKey('DEP-07')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-deployment", '--title', 'Security scanning in CI: images, dependencies, secrets, DAST baseline', '--body-file', 'iltiam-deployment/DEP-07-security-scanning-in-ci-images-dependencies-secrets-dast-bas.md', '--label', 'area:deployment', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['DEP-07'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-12')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Doctor: patient list, search/filters, profile and register new patient', '--body-file', 'iltiam-mobile/MOB-12-doctor-patient-list-search-filters-profile-and-register-new.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-12'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-13')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Doctor: capture/upload for a patient and analysis status (6 statuses, 10 reasons)', '--body-file', 'iltiam-mobile/MOB-13-doctor-capture-upload-for-a-patient-and-analysis-status-6-st.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-13'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-20')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Clinic Admin: doctors list, add doctor, deactivate on the API', '--body-file', 'iltiam-web/WEB-20-clinic-admin-doctors-list-add-doctor-deactivate-on-the-api.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['WEB-20'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-11a')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'FR-D-5: Super Admin changes the manual-review threshold (OTP, 40 % floor, audit, applied to analyses)', '--body-file', 'iltiam-backend/BE-11a-fr-d-5-super-admin-changes-the-manual-review-threshold-otp-4.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-11a'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-13')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Patient data export as background jobs (JSON/PDF) with status and download', '--body-file', 'iltiam-backend/BE-13-patient-data-export-as-background-jobs-json-pdf-with-status.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-13'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-16')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'MFA manual recovery workflow when every OTP method fails', '--body-file', 'iltiam-backend/BE-16-mfa-manual-recovery-workflow-when-every-otp-method-fails.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['BE-16'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-21')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Production object storage wiring and key rotation support', '--body-file', 'iltiam-backend/BE-21-production-object-storage-wiring-and-key-rotation-support.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-21'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-15')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Doctor: AI result view (overlay toggle, area ± uncertainty, dimensions, confidence, risk factors, versions)', '--body-file', 'iltiam-mobile/MOB-15-doctor-ai-result-view-overlay-toggle-area-uncertainty-dimens.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-15'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-16')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Doctor: review (approve / override with justification) and side-by-side', '--body-file', 'iltiam-mobile/MOB-16-doctor-review-approve-override-with-justification-and-side-b.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-16'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-24')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Deep links, in-app notification centre and read state', '--body-file', 'iltiam-mobile/MOB-24-deep-links-in-app-notification-centre-and-read-state.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-24'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-21')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Clinic Admin: reassign patients (single, bulk, unassigned)', '--body-file', 'iltiam-web/WEB-21-clinic-admin-reassign-patients-single-bulk-unassigned.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['WEB-21'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-23')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Super Admin: clinics directory, provisioning and lifecycle (activate/deactivate/archive)', '--body-file', 'iltiam-web/WEB-23-super-admin-clinics-directory-provisioning-and-lifecycle-act.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['WEB-23'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-11b')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Threshold change: doctor notification and re-evaluation report', '--body-file', 'iltiam-backend/BE-11b-threshold-change-doctor-notification-and-re-evaluation-repor.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-11b'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-14')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Patient can cancel a pending deletion request', '--body-file', 'iltiam-backend/BE-14-patient-can-cancel-a-pending-deletion-request.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-14'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-15')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Prescriptions: COMPLETED status, detail fields and refill requests', '--body-file', 'iltiam-backend/BE-15-prescriptions-completed-status-detail-fields-and-refill-requ.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-15'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('DEP-04')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-deployment", '--title', 'Runbook 10: production project on the same VM, release with approval, rollback, and when to split', '--body-file', 'iltiam-deployment/DEP-04-runbook-10-production-project-on-the-same-vm-release-with-ap.md', '--label', 'area:deployment', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'ben-fatah', '--milestone', 'v1.0')
  $Map['DEP-04'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-18')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Doctor: dashboard and worklist (needs review, failed with retry)', '--body-file', 'iltiam-mobile/MOB-18-doctor-dashboard-and-worklist-needs-review-failed-with-retry.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-18'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-19')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Doctor: wound progression timeline and deterioration alerts', '--body-file', 'iltiam-mobile/MOB-19-doctor-wound-progression-timeline-and-deterioration-alerts.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-19'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-10')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'AI model panel: join on checksum/registry_name and show metrics, threshold, tissue status', '--body-file', 'iltiam-backend/BE-10-ai-model-panel-join-on-checksum-registry-name-and-show-metri.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-10'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-17')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Breach notification to affected patients within 72 hours', '--body-file', 'iltiam-backend/BE-17-breach-notification-to-affected-patients-within-72-hours.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['BE-17'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('DEP-12')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-deployment", '--title', 'System-level SRS divergence register (decisions that differ from the SRS PDF)', '--body-file', 'iltiam-deployment/DEP-12-system-level-srs-divergence-register-decisions-that-differ-f.md', '--label', 'area:deployment', '--label', 'type:docs', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['DEP-12'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-06')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Password reset and change on the real backend', '--body-file', 'iltiam-mobile/MOB-06-password-reset-and-change-on-the-real-backend.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-06'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-33')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Security and performance budget: CSP compliance, no unsafe-inline, bundle budget, error monitoring', '--body-file', 'iltiam-web/WEB-33-security-and-performance-budget-csp-compliance-no-unsafe-inl.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['WEB-33'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-14')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Notification centre with deep links (all roles)', '--body-file', 'iltiam-web/WEB-14-notification-centre-with-deep-links-all-roles.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['WEB-14'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-10')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Patient progression chart with the five ALG-04 statuses', '--body-file', 'iltiam-mobile/MOB-10-patient-progression-chart-with-the-five-alg-04-statuses.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-10'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-15')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Doctor: SOAP clinical notes on the API', '--body-file', 'iltiam-web/WEB-15-doctor-soap-clinical-notes-on-the-api.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['WEB-15'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-16')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Doctor: prescriptions upload and list (expiry, completed, refill requests)', '--body-file', 'iltiam-web/WEB-16-doctor-prescriptions-upload-and-list-expiry-completed-refill.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['WEB-16'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-18')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Doctor: appointments and next-visit reminders on the API', '--body-file', 'iltiam-web/WEB-18-doctor-appointments-and-next-visit-reminders-on-the-api.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['WEB-18'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('AI-09')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-ai-service", '--title', 'Field photo set: printed dataset wounds with the 50 mm marker photographed by phones', '--body-file', 'iltiam-ai-service/AI-09-field-photo-set-printed-dataset-wounds-with-the-50-mm-marker.md', '--label', 'area:ai', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'ben-fatah', '--milestone', 'v1.0')
  $Map['AI-09'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-14')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Patient appointments on the backend (request, cancel, history, reminders)', '--body-file', 'iltiam-mobile/MOB-14-patient-appointments-on-the-backend-request-cancel-history-r.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-14'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-17')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Doctor: care plan editor and shared notes control', '--body-file', 'iltiam-web/WEB-17-doctor-care-plan-editor-and-shared-notes-control.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['WEB-17'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-19')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Doctor: secure messaging on the API', '--body-file', 'iltiam-web/WEB-19-doctor-secure-messaging-on-the-api.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['WEB-19'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-24')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Super Admin: cross-clinic doctors (create, deactivate, archive, soft delete)', '--body-file', 'iltiam-web/WEB-24-super-admin-cross-clinic-doctors-create-deactivate-archive-s.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['WEB-24'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
$Map['DEP#10'] = "$Org/iltiam-deployment#10"
Run @('issue', 'edit', '10', '--repo', "$Org/iltiam-deployment", '--milestone', 'v1.0', '--title', 'Runbook 7: lightweight monitoring, logs, alerts and uptime (fits the free VM)', '--body-file', 'updates/iltiam-deployment-10.md', '--add-label', 'area:deployment', '--add-label', 'type:feat', '--add-label', 'priority:p1', '--add-label', 'srs', '--remove-label', 'priority:p2', '--add-assignee', 'ben-fatah') | Out-Null
$Map['DEP#5'] = "$Org/iltiam-deployment#5"
Run @('issue', 'edit', '5', '--repo', "$Org/iltiam-deployment", '--milestone', 'v1.0', '--title', 'Local full-stack development environment (one command, seed, reset)', '--body-file', 'updates/iltiam-deployment-5.md', '--add-label', 'area:deployment', '--add-label', 'type:chore', '--add-label', 'priority:p1', '--remove-label', 'hackathon', '--remove-label', 'priority:p0', '--add-assignee', 'ben-fatah') | Out-Null
if (-not $Map.ContainsKey('MOB-17')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Patient care plan on the backend (versions, acknowledgement)', '--body-file', 'iltiam-mobile/MOB-17-patient-care-plan-on-the-backend-versions-acknowledgement.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-17'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-22')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Clinic Admin: statistics with PDF export and account events log', '--body-file', 'iltiam-web/WEB-22-clinic-admin-statistics-with-pdf-export-and-account-events-l.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['WEB-22'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-25')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Super Admin: system dashboard (5-minute refresh, date range, PDF export)', '--body-file', 'iltiam-web/WEB-25-super-admin-system-dashboard-5-minute-refresh-date-range-pdf.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['WEB-25'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-22')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Retention jobs from the PDPL retention schedule', '--body-file', 'iltiam-backend/BE-22-retention-jobs-from-the-pdpl-retention-schedule.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['BE-22'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('DEP-09')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-deployment", '--title', 'Threat model, incident response and 72-hour breach notification runbook', '--body-file', 'iltiam-deployment/DEP-09-threat-model-incident-response-and-72-hour-breach-notificati.md', '--label', 'area:deployment', '--label', 'type:docs', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'ben-fatah', '--milestone', 'v1.0')
  $Map['DEP-09'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-20')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Doctor: messaging with patients', '--body-file', 'iltiam-mobile/MOB-20-doctor-messaging-with-patients.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['MOB-20'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-25')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Patient privacy on the backend: consents, export jobs, access log, deletion request and cancel, step-up', '--body-file', 'iltiam-mobile/MOB-25-patient-privacy-on-the-backend-consents-export-jobs-access-l.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-25'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-26')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Offline read-only access to recent history and results (FR-P-7.2)', '--body-file', 'iltiam-mobile/MOB-26-offline-read-only-access-to-recent-history-and-results-fr-p.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-26'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-27')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Super Admin: audit log viewer with filters and CSV/PDF export', '--body-file', 'iltiam-web/WEB-27-super-admin-audit-log-viewer-with-filters-and-csv-pdf-export.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['WEB-27'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('AI-05')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-ai-service", '--title', 'Model update without downtime (NFR-MAI-01)', '--body-file', 'iltiam-ai-service/AI-05-model-update-without-downtime-nfr-mai-01.md', '--label', 'area:ai', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'ben-fatah', '--milestone', 'v1.0')
  $Map['AI-05'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-24')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Security fixes from scans and review (ZAP, dependency audit)', '--body-file', 'iltiam-backend/BE-24-security-fixes-from-scans-and-review-zap-dependency-audit.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['BE-24'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-34')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Idempotency-Key on uploads (offline retries never double-submit)', '--body-file', 'iltiam-backend/BE-34-idempotency-key-on-uploads-offline-retries-never-double-subm.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-34'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('DEP-08')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-deployment", '--title', 'Load and performance tests (NFR-PERF, NFR-SCA) without hurting production on the shared VM', '--body-file', 'iltiam-deployment/DEP-08-load-and-performance-tests-nfr-perf-nfr-sca-without-hurting.md', '--label', 'area:deployment', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['DEP-08'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-23')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Performance fixes from the staging load test', '--body-file', 'iltiam-backend/BE-23-performance-fixes-from-the-staging-load-test.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['BE-23'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-21')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Patient messaging with the assigned doctor', '--body-file', 'iltiam-mobile/MOB-21-patient-messaging-with-the-assigned-doctor.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['MOB-21'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-22')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Patient prescriptions: list, detail, PDF download, expiry, refill request', '--body-file', 'iltiam-mobile/MOB-22-patient-prescriptions-list-detail-pdf-download-expiry-refill.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-22'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-23')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Patient profile and preferences (medical background, photo, language, notification preferences)', '--body-file', 'iltiam-mobile/MOB-23-patient-profile-and-preferences-medical-background-photo-lan.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-23'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-29')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Arabic/RTL, accessibility and plain-language audit of all new screens', '--body-file', 'iltiam-mobile/MOB-29-arabic-rtl-accessibility-and-plain-language-audit-of-all-new.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-29'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-27')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Integration tests against staging on an Android device matrix', '--body-file', 'iltiam-mobile/MOB-27-integration-tests-against-staging-on-an-android-device-matri.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-27'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-28')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Google Play production release: listing AR/EN, data safety, review, rollout', '--body-file', 'iltiam-mobile/MOB-28-google-play-production-release-listing-ar-en-data-safety-rev.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-28'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-26')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Super Admin: AI model panel and confidence-threshold governance', '--body-file', 'iltiam-web/WEB-26-super-admin-ai-model-panel-and-confidence-threshold-governan.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['WEB-26'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-28')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Super Admin: team invitations and Full/Read-only roles', '--body-file', 'iltiam-web/WEB-28-super-admin-team-invitations-and-full-read-only-roles.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['WEB-28'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-29')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Super Admin: data requests, MFA recovery requests and breach notification console', '--body-file', 'iltiam-web/WEB-29-super-admin-data-requests-mfa-recovery-requests-and-breach-n.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['WEB-29'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-31')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Arabic/RTL, accessibility and plain-language audit (all pages)', '--body-file', 'iltiam-web/WEB-31-arabic-rtl-accessibility-and-plain-language-audit-all-pages.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['WEB-31'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-32')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Playwright E2E suite against staging (all actors)', '--body-file', 'iltiam-web/WEB-32-playwright-e2e-suite-against-staging-all-actors.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['WEB-32'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-34')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Cross-browser verification (latest two Chrome, Firefox, Safari)', '--body-file', 'iltiam-web/WEB-34-cross-browser-verification-latest-two-chrome-firefox-safari.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['WEB-34'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('DEP-11')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-deployment", '--title', 'Go-live checklist and production launch', '--body-file', 'iltiam-deployment/DEP-11-go-live-checklist-and-production-launch.md', '--label', 'area:deployment', '--label', 'type:feat', '--label', 'priority:p0', '--assignee', 'ben-fatah', '--milestone', 'v1.0')
  $Map['DEP-11'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-30')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Consented feedback dataset export for retraining (anonymised)', '--body-file', 'iltiam-backend/BE-30-consented-feedback-dataset-export-for-retraining-anonymised.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p2', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['BE-30'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-42')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Structured patient notes on upload (pain level, odour, discharge colour)', '--body-file', 'iltiam-backend/BE-42-structured-patient-notes-on-upload-pain-level-odour-discharg.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p2', '--label', 'srs', '--assignee', 'Mn9p', '--milestone', 'v1.0')
  $Map['BE-42'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-29')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Clinician-corrected wound boundary (FR-D-7) with recomputed area', '--body-file', 'iltiam-backend/BE-29-clinician-corrected-wound-boundary-fr-d-7-with-recomputed-ar.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p2', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['BE-29'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('WEB-30')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-web", '--title', 'Doctor: corrected wound boundary editor (FR-D-7)', '--body-file', 'iltiam-web/WEB-30-doctor-corrected-wound-boundary-editor-fr-d-7.md', '--label', 'area:web', '--label', 'type:feat', '--label', 'priority:p2', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['WEB-30'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('BE-18')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-backend", '--title', 'Bilingual clinician texts for AI decision reasons and warnings', '--body-file', 'iltiam-backend/BE-18-bilingual-clinician-texts-for-ai-decision-reasons-and-warnin.md', '--label', 'area:backend', '--label', 'type:feat', '--label', 'priority:p2', '--label', 'srs', '--assignee', 'Omar-Nasri', '--milestone', 'v1.0')
  $Map['BE-18'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-30')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Crash and error reporting (privacy-safe)', '--body-file', 'iltiam-mobile/MOB-30-crash-and-error-reporting-privacy-safe.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p2', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.0')
  $Map['MOB-30'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-31')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Doctor (mobile): SOAP clinical notes', '--body-file', 'iltiam-mobile/MOB-31-doctor-mobile-soap-clinical-notes.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p2', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['MOB-31'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-32')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Doctor (mobile): prescription upload and next-visit reminder', '--body-file', 'iltiam-mobile/MOB-32-doctor-mobile-prescription-upload-and-next-visit-reminder.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p2', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['MOB-32'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-33')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'Doctor (mobile): care plan editor and appointment requests (confirm/reject/reschedule)', '--body-file', 'iltiam-mobile/MOB-33-doctor-mobile-care-plan-editor-and-appointment-requests-conf.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p2', '--label', 'srs', '--assignee', 'aalbabtain', '--milestone', 'v1.0')
  $Map['MOB-33'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('AI-06')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-ai-service", '--title', 'Drift monitoring from production aggregates (SRS 5.6.3)', '--body-file', 'iltiam-ai-service/AI-06-drift-monitoring-from-production-aggregates-srs-5-6-3.md', '--label', 'area:ai', '--label', 'type:feat', '--label', 'priority:p2', '--label', 'srs', '--assignee', 'ben-fatah', '--milestone', 'v1.0')
  $Map['AI-06'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
$Map['DEP#4'] = "$Org/iltiam-deployment#4"
Run @('issue', 'edit', '4', '--repo', "$Org/iltiam-deployment", '--milestone', 'v1.0', '--title', 'System documentation: C4 context/container, integration guide, cross-repo ADR index', '--body-file', 'updates/iltiam-deployment-4.md', '--add-label', 'area:deployment', '--add-label', 'type:docs', '--add-label', 'priority:p2', '--remove-label', 'hackathon', '--remove-label', 'priority:p1', '--add-assignee', 'ben-fatah') | Out-Null
if (-not $Map.ContainsKey('MOB-34')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'iOS builds: signing, flavors and TestFlight', '--body-file', 'iltiam-mobile/MOB-34-ios-builds-signing-flavors-and-testflight.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.1')
  $Map['MOB-34'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-35')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'iOS push notifications: APNs key in Firebase, capabilities, permission flow', '--body-file', 'iltiam-mobile/MOB-35-ios-push-notifications-apns-key-in-firebase-capabilities-per.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p0', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.1')
  $Map['MOB-35'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
if (-not $Map.ContainsKey('MOB-36')) {
  $url = Run @('issue', 'create', '--repo', "$Org/iltiam-mobile", '--title', 'App Store release: listing, privacy nutrition labels, review, iOS device tests', '--body-file', 'iltiam-mobile/MOB-36-app-store-release-listing-privacy-nutrition-labels-review-io.md', '--label', 'area:mobile', '--label', 'type:feat', '--label', 'priority:p1', '--label', 'srs', '--assignee', 'MYF25', '--milestone', 'v1.1')
  $Map['MOB-36'] = ("$url" -replace '^https://github.com/([^/]+/[^/]+)/issues/(\d+).*$', '$1#$2')
  Save-Map
}
Save-Map

# ---------------------------------------------------------------- 3. superseded issues
# None: iltiam-backend #55, #56, #57 are kept; iltiam-deployment #1-#10 are updated in place.

# ---------------------------------------------------------------- 4. replace plan IDs with real references
$KeyRe = '(?<![A-Za-z0-9#-])((?:AI|BE|WEB|MOB|DEP)-\d+[ab]?|(?:DEP|BE)#\d+)(?![A-Za-z0-9])'
$Files = [ordered]@{
  'DEP#7' = 'updates/iltiam-deployment-7.md'
  'AI-12' = 'iltiam-ai-service/AI-12-arm-go-no-go-measure-the-analysis-latency-on-the-ampere-a1-v.md'
  'BE-01' = 'iltiam-backend/BE-01-openapi-as-the-single-api-contract-versioning-breaking-chang.md'
  'BE-02' = 'iltiam-backend/BE-02-health-and-readiness-endpoints.md'
  'DEP#1' = 'updates/iltiam-deployment-1.md'
  'BE-04' = 'iltiam-backend/BE-04-backend-dockerfile-web-worker-beat-and-production-entrypoint.md'
  'DEP#3' = 'updates/iltiam-deployment-3.md'
  'DEP-01' = 'iltiam-deployment/DEP-01-runbook-2-cloudflare-account-dns-for-domain-ssl-tls-and-emai.md'
  'MOB-01' = 'iltiam-mobile/MOB-01-generated-api-client-from-the-backend-openapi-replace-guesse.md'
  'MOB-02' = 'iltiam-mobile/MOB-02-build-flavors-and-platform-config-dev-staging-prod-network-s.md'
  'MOB-03' = 'iltiam-mobile/MOB-03-internal-distribution-ci-builds-staging-android-builds-and-s.md'
  'WEB-01' = 'iltiam-web/WEB-01-green-ci-on-main-and-repo-hygiene.md'
  'WEB-02' = 'iltiam-web/WEB-02-generated-api-client-from-the-backend-openapi-data-layer-moc.md'
  'WEB-03' = 'iltiam-web/WEB-03-production-container-static-build-on-nginx-runtime-config-cs.md'
  'WEB-06' = 'iltiam-web/WEB-06-doctor-patient-list-search-filters-risk-colours-and-register.md'
  'WEB-08' = 'iltiam-web/WEB-08-doctor-wound-photo-upload-on-the-api-8-mp-50-mm-marker-dupli.md'
  'AI-07' = 'iltiam-ai-service/AI-07-production-image-linux-arm64-and-weights-delivery-for-stagin.md'
  'AI-10' = 'iltiam-ai-service/AI-10-contract-release-process-versioned-schemas-openapi-artifacts.md'
  'BE-03' = 'iltiam-backend/BE-03-production-settings-hardening-security-headers-structured-lo.md'
  'BE-05' = 'iltiam-backend/BE-05-file-urls-reachable-by-web-and-mobile-public-storage-endpoin.md'
  'BE-31' = 'iltiam-backend/BE-31-production-bootstrap-and-staging-test-accounts.md'
  'BE-32' = 'iltiam-backend/BE-32-sync-vendored-ai-contract-to-the-released-version-and-use-re.md'
  'DEP#9' = 'updates/iltiam-deployment-9.md'
  'DEP-02' = 'iltiam-deployment/DEP-02-runbook-8-object-storage-within-the-free-20-gb-software-vaul.md'
  'DEP-13' = 'iltiam-deployment/DEP-13-runbook-11-firebase-project-for-fcm-push-on-android-service.md'
  'DEP-14' = 'iltiam-deployment/DEP-14-runbook-12-authentica-account-sender-name-and-api-key-for-ph.md'
  'MOB-04' = 'iltiam-mobile/MOB-04-sign-in-on-the-real-backend-phone-password-otp-sms-email-aut.md'
  'MOB-05' = 'iltiam-mobile/MOB-05-sign-in-security-captcha-after-3-failures-remember-device-30.md'
  'MOB-28a' = 'iltiam-mobile/MOB-28a-google-play-console-app-play-app-signing-internal-testing-an.md'
  'WEB-04' = 'iltiam-web/WEB-04-real-sign-in-password-otp-sms-email-authenticator-resend-cap.md'
  'WEB-05' = 'iltiam-web/WEB-05-account-activation-invitations-authenticator-setup-password.md'
  'WEB-11' = 'iltiam-web/WEB-11-doctor-analyses-needing-attention-retry-and-failure-notifica.md'
  'WEB-13' = 'iltiam-web/WEB-13-doctor-alerts-panel-acknowledge-with-justification-risk-rank.md'
  'AI-01' = 'iltiam-ai-service/AI-01-capabilities-registry-metrics-release-date-and-registry-name.md'
  'BE-06' = 'iltiam-backend/BE-06-doctor-visit-detail-photo-and-mask-urls-measurement-and-appl.md'
  'BE-07' = 'iltiam-backend/BE-07-list-a-wound-s-visits-for-doctor-and-patient-submission-hist.md'
  'WEB-07' = 'iltiam-web/WEB-07-doctor-patient-profile-with-wounds-and-image-timeline.md'
  'BE-26' = 'iltiam-backend/BE-26-clinic-scoped-account-event-log-for-clinic-admins.md'
  'BE-39' = 'iltiam-backend/BE-39-patient-result-wound-not-found-asks-for-a-retake-and-says-th.md'
  'DEP#2' = 'updates/iltiam-deployment-2.md'
  'MOB-07' = 'iltiam-mobile/MOB-07-patient-photo-upload-on-the-real-backend-fields-duplicate-40.md'
  'MOB-08' = 'iltiam-mobile/MOB-08-patient-result-screen-on-the-real-backend-5-states-tips-over.md'
  'WEB-09' = 'iltiam-web/WEB-09-doctor-ai-result-view-on-the-api-statuses-reasons-overlay-to.md'
  'WEB-10' = 'iltiam-web/WEB-10-doctor-review-approve-override-with-justification-side-by-si.md'
  'AI-02' = 'iltiam-ai-service/AI-02-per-request-manual-review-threshold-for-fr-d-5-governance.md'
  'AI-04' = 'iltiam-ai-service/AI-04-observability-prometheus-metrics-json-logs-job-timing-histog.md'
  'BE-08' = 'iltiam-backend/BE-08-wound-images-strip-exif-gps-and-normalise-orientation-on-upl.md'
  'BE-09' = 'iltiam-backend/BE-09-dev-staging-command-seed-a-real-dated-analysis-series-throug.md'
  'WEB-12' = 'iltiam-web/WEB-12-doctor-progression-timeline-on-the-api-chart-healing-rate-co.md'
  'BE-12' = 'iltiam-backend/BE-12-step-up-verification-re-enter-otp-for-sensitive-actions.md'
  'BE-27' = 'iltiam-backend/BE-27-backend-metrics-endpoint-django-prometheus-celery-queue-metr.md'
  'DEP-03' = 'iltiam-deployment/DEP-03-runbook-9-continuous-deployment-to-the-staging-project-on-me.md'
  'DEP-10' = 'iltiam-deployment/DEP-10-cross-repo-end-to-end-smoke-after-every-staging-deploy.md'
  'MOB-09' = 'iltiam-mobile/MOB-09-patient-wounds-list-and-submission-history-filters-thumbnail.md'
  'AI-03' = 'iltiam-ai-service/AI-03-threshold-re-evaluation-report-from-stored-validation-predic.md'
  'BE-19' = 'iltiam-backend/BE-19-push-notifications-in-production-fcm-android-device-lifecycl.md'
  'MOB-11' = 'iltiam-mobile/MOB-11-push-notifications-with-fcm-on-android-setup-and-device-regi.md'
  'BE-20' = 'iltiam-backend/BE-20-phone-codes-through-authentica-email-provider-and-the-otp-fa.md'
  'BE-25' = 'iltiam-backend/BE-25-super-admin-doctor-lifecycle-across-clinics-deactivate-archi.md'
  'BE-37' = 'iltiam-backend/BE-37-doctor-dashboard-summary-endpoint-risk-ranked-worklist.md'
  'DEP#6' = 'updates/iltiam-deployment-6.md'
  'DEP#8' = 'updates/iltiam-deployment-8.md'
  'DEP-07' = 'iltiam-deployment/DEP-07-security-scanning-in-ci-images-dependencies-secrets-dast-bas.md'
  'MOB-12' = 'iltiam-mobile/MOB-12-doctor-patient-list-search-filters-profile-and-register-new.md'
  'MOB-13' = 'iltiam-mobile/MOB-13-doctor-capture-upload-for-a-patient-and-analysis-status-6-st.md'
  'WEB-20' = 'iltiam-web/WEB-20-clinic-admin-doctors-list-add-doctor-deactivate-on-the-api.md'
  'BE-11a' = 'iltiam-backend/BE-11a-fr-d-5-super-admin-changes-the-manual-review-threshold-otp-4.md'
  'BE-13' = 'iltiam-backend/BE-13-patient-data-export-as-background-jobs-json-pdf-with-status.md'
  'BE-16' = 'iltiam-backend/BE-16-mfa-manual-recovery-workflow-when-every-otp-method-fails.md'
  'BE-21' = 'iltiam-backend/BE-21-production-object-storage-wiring-and-key-rotation-support.md'
  'MOB-15' = 'iltiam-mobile/MOB-15-doctor-ai-result-view-overlay-toggle-area-uncertainty-dimens.md'
  'MOB-16' = 'iltiam-mobile/MOB-16-doctor-review-approve-override-with-justification-and-side-b.md'
  'MOB-24' = 'iltiam-mobile/MOB-24-deep-links-in-app-notification-centre-and-read-state.md'
  'WEB-21' = 'iltiam-web/WEB-21-clinic-admin-reassign-patients-single-bulk-unassigned.md'
  'WEB-23' = 'iltiam-web/WEB-23-super-admin-clinics-directory-provisioning-and-lifecycle-act.md'
  'BE-11b' = 'iltiam-backend/BE-11b-threshold-change-doctor-notification-and-re-evaluation-repor.md'
  'BE-14' = 'iltiam-backend/BE-14-patient-can-cancel-a-pending-deletion-request.md'
  'BE-15' = 'iltiam-backend/BE-15-prescriptions-completed-status-detail-fields-and-refill-requ.md'
  'DEP-04' = 'iltiam-deployment/DEP-04-runbook-10-production-project-on-the-same-vm-release-with-ap.md'
  'MOB-18' = 'iltiam-mobile/MOB-18-doctor-dashboard-and-worklist-needs-review-failed-with-retry.md'
  'MOB-19' = 'iltiam-mobile/MOB-19-doctor-wound-progression-timeline-and-deterioration-alerts.md'
  'BE-10' = 'iltiam-backend/BE-10-ai-model-panel-join-on-checksum-registry-name-and-show-metri.md'
  'BE-17' = 'iltiam-backend/BE-17-breach-notification-to-affected-patients-within-72-hours.md'
  'DEP-12' = 'iltiam-deployment/DEP-12-system-level-srs-divergence-register-decisions-that-differ-f.md'
  'MOB-06' = 'iltiam-mobile/MOB-06-password-reset-and-change-on-the-real-backend.md'
  'WEB-33' = 'iltiam-web/WEB-33-security-and-performance-budget-csp-compliance-no-unsafe-inl.md'
  'WEB-14' = 'iltiam-web/WEB-14-notification-centre-with-deep-links-all-roles.md'
  'MOB-10' = 'iltiam-mobile/MOB-10-patient-progression-chart-with-the-five-alg-04-statuses.md'
  'WEB-15' = 'iltiam-web/WEB-15-doctor-soap-clinical-notes-on-the-api.md'
  'WEB-16' = 'iltiam-web/WEB-16-doctor-prescriptions-upload-and-list-expiry-completed-refill.md'
  'WEB-18' = 'iltiam-web/WEB-18-doctor-appointments-and-next-visit-reminders-on-the-api.md'
  'AI-09' = 'iltiam-ai-service/AI-09-field-photo-set-printed-dataset-wounds-with-the-50-mm-marker.md'
  'MOB-14' = 'iltiam-mobile/MOB-14-patient-appointments-on-the-backend-request-cancel-history-r.md'
  'WEB-17' = 'iltiam-web/WEB-17-doctor-care-plan-editor-and-shared-notes-control.md'
  'WEB-19' = 'iltiam-web/WEB-19-doctor-secure-messaging-on-the-api.md'
  'WEB-24' = 'iltiam-web/WEB-24-super-admin-cross-clinic-doctors-create-deactivate-archive-s.md'
  'DEP#10' = 'updates/iltiam-deployment-10.md'
  'DEP#5' = 'updates/iltiam-deployment-5.md'
  'MOB-17' = 'iltiam-mobile/MOB-17-patient-care-plan-on-the-backend-versions-acknowledgement.md'
  'WEB-22' = 'iltiam-web/WEB-22-clinic-admin-statistics-with-pdf-export-and-account-events-l.md'
  'WEB-25' = 'iltiam-web/WEB-25-super-admin-system-dashboard-5-minute-refresh-date-range-pdf.md'
  'BE-22' = 'iltiam-backend/BE-22-retention-jobs-from-the-pdpl-retention-schedule.md'
  'DEP-09' = 'iltiam-deployment/DEP-09-threat-model-incident-response-and-72-hour-breach-notificati.md'
  'MOB-20' = 'iltiam-mobile/MOB-20-doctor-messaging-with-patients.md'
  'MOB-25' = 'iltiam-mobile/MOB-25-patient-privacy-on-the-backend-consents-export-jobs-access-l.md'
  'MOB-26' = 'iltiam-mobile/MOB-26-offline-read-only-access-to-recent-history-and-results-fr-p.md'
  'WEB-27' = 'iltiam-web/WEB-27-super-admin-audit-log-viewer-with-filters-and-csv-pdf-export.md'
  'AI-05' = 'iltiam-ai-service/AI-05-model-update-without-downtime-nfr-mai-01.md'
  'BE-24' = 'iltiam-backend/BE-24-security-fixes-from-scans-and-review-zap-dependency-audit.md'
  'BE-34' = 'iltiam-backend/BE-34-idempotency-key-on-uploads-offline-retries-never-double-subm.md'
  'DEP-08' = 'iltiam-deployment/DEP-08-load-and-performance-tests-nfr-perf-nfr-sca-without-hurting.md'
  'BE-23' = 'iltiam-backend/BE-23-performance-fixes-from-the-staging-load-test.md'
  'MOB-21' = 'iltiam-mobile/MOB-21-patient-messaging-with-the-assigned-doctor.md'
  'MOB-22' = 'iltiam-mobile/MOB-22-patient-prescriptions-list-detail-pdf-download-expiry-refill.md'
  'MOB-23' = 'iltiam-mobile/MOB-23-patient-profile-and-preferences-medical-background-photo-lan.md'
  'MOB-29' = 'iltiam-mobile/MOB-29-arabic-rtl-accessibility-and-plain-language-audit-of-all-new.md'
  'MOB-27' = 'iltiam-mobile/MOB-27-integration-tests-against-staging-on-an-android-device-matri.md'
  'MOB-28' = 'iltiam-mobile/MOB-28-google-play-production-release-listing-ar-en-data-safety-rev.md'
  'WEB-26' = 'iltiam-web/WEB-26-super-admin-ai-model-panel-and-confidence-threshold-governan.md'
  'WEB-28' = 'iltiam-web/WEB-28-super-admin-team-invitations-and-full-read-only-roles.md'
  'WEB-29' = 'iltiam-web/WEB-29-super-admin-data-requests-mfa-recovery-requests-and-breach-n.md'
  'WEB-31' = 'iltiam-web/WEB-31-arabic-rtl-accessibility-and-plain-language-audit-all-pages.md'
  'WEB-32' = 'iltiam-web/WEB-32-playwright-e2e-suite-against-staging-all-actors.md'
  'WEB-34' = 'iltiam-web/WEB-34-cross-browser-verification-latest-two-chrome-firefox-safari.md'
  'DEP-11' = 'iltiam-deployment/DEP-11-go-live-checklist-and-production-launch.md'
  'BE-30' = 'iltiam-backend/BE-30-consented-feedback-dataset-export-for-retraining-anonymised.md'
  'BE-42' = 'iltiam-backend/BE-42-structured-patient-notes-on-upload-pain-level-odour-discharg.md'
  'BE-29' = 'iltiam-backend/BE-29-clinician-corrected-wound-boundary-fr-d-7-with-recomputed-ar.md'
  'WEB-30' = 'iltiam-web/WEB-30-doctor-corrected-wound-boundary-editor-fr-d-7.md'
  'BE-18' = 'iltiam-backend/BE-18-bilingual-clinician-texts-for-ai-decision-reasons-and-warnin.md'
  'MOB-30' = 'iltiam-mobile/MOB-30-crash-and-error-reporting-privacy-safe.md'
  'MOB-31' = 'iltiam-mobile/MOB-31-doctor-mobile-soap-clinical-notes.md'
  'MOB-32' = 'iltiam-mobile/MOB-32-doctor-mobile-prescription-upload-and-next-visit-reminder.md'
  'MOB-33' = 'iltiam-mobile/MOB-33-doctor-mobile-care-plan-editor-and-appointment-requests-conf.md'
  'AI-06' = 'iltiam-ai-service/AI-06-drift-monitoring-from-production-aggregates-srs-5-6-3.md'
  'DEP#4' = 'updates/iltiam-deployment-4.md'
  'MOB-34' = 'iltiam-mobile/MOB-34-ios-builds-signing-flavors-and-testflight.md'
  'MOB-35' = 'iltiam-mobile/MOB-35-ios-push-notifications-apns-key-in-firebase-capabilities-per.md'
  'MOB-36' = 'iltiam-mobile/MOB-36-app-store-release-listing-privacy-nutrition-labels-review-io.md'
}
foreach ($k in $Files.Keys) {
  $text = Get-Content -Raw -Encoding utf8 $Files[$k]
  $new = [regex]::Replace($text, $KeyRe, { param($m) $v = $Map[$m.Groups[1].Value]; if ($v) { "$v ($($m.Groups[1].Value))" } else { $m.Value } })
  $tmp = [System.IO.Path]::GetTempFileName(); [System.IO.File]::WriteAllText($tmp, $new, (New-Object System.Text.UTF8Encoding $false))
  $parts = $Map[$k] -split '#'
  Run @('issue', 'edit', $parts[1], '--repo', $parts[0], '--body-file', $tmp) | Out-Null
  Remove-Item $tmp
}
Write-Host "Done. $($Map.Count) issues mapped; see created-map.json."
