# Thin PowerShell wrapper: runs scripts/ci-local.sh with Git Bash (not WSL's bash). Same file in every ILTIAM repo.
#   .\scripts\ci-local.ps1 --fast
#   .\scripts\ci-local.ps1 --full
$gitExec = (& git --exec-path) -replace '/', '\'
$candidates = @(
  (Join-Path $gitExec '..\..\..\bin\bash.exe'),
  (Join-Path $env:ProgramFiles 'Git\bin\bash.exe')
)
$bash = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $bash) { Write-Error 'Git Bash not found: install Git for Windows'; exit 2 }
& $bash (Join-Path $PSScriptRoot 'ci-local.sh') @args
exit $LASTEXITCODE
