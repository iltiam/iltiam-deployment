# Thin PowerShell wrapper (issue #5): runs scripts/dev.sh reset with Git Bash, passing any other arguments.
#   .\scripts\dev-reset.ps1 [--all]
$gitExec = (& git --exec-path) -replace '/', '\'
$candidates = @(
  (Join-Path $gitExec '..\..\..\bin\bash.exe'),
  (Join-Path $env:ProgramFiles 'Git\bin\bash.exe')
)
$bash = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $bash) { Write-Error 'Git Bash not found: install Git for Windows'; exit 2 }
& $bash (Join-Path $PSScriptRoot 'dev.sh') reset @args
exit $LASTEXITCODE
