#!/usr/bin/env pwsh
# One-command workshop eval runner (Windows parity of run.sh).
#
# Maps a short target name to its Promptfoo config, bakes in free-tier-safe
# pacing (-j 1 --delay 1000 by default), and translates Promptfoo's exit code
# into a plain-English verdict — in these red-team suites a *failing* check
# means the attack landed. Extra args after the target pass through.
#
#   .\run.ps1 medibot
#   .\run.ps1 finance --filter-first-n 1
#   .\run.ps1 view
$ErrorActionPreference = 'Continue'

$jobs  = if ($env:RUN_JOBS)     { $env:RUN_JOBS }     else { '1' }
$delay = if ($env:RUN_DELAY_MS) { $env:RUN_DELAY_MS } else { '1000' }

function Show-Usage {
  @'
Usage: .\run.ps1 <target> [extra promptfoo args...]

Targets:
  medibot             MediBot red-team suite (free-tier-safe)
  finance             FinanceBot red-team suite
  quality.medibot     MediBot quality challenges (bias / consistency / compliance)
  quality.finance     FinanceBot quality challenges (context / values)
  openrouter.medibot  MediBot via the OpenRouter fallback (needs OPENROUTER_API_KEY)
  openrouter.finance  FinanceBot via the OpenRouter fallback
  mybot               Your Challenge-3 build-it bot
  chat <bot>          Talk to a bot directly (onboardbot, medibot, financebot, mybot)
  view                Open the results web UI

Examples:
  .\run.ps1 medibot
  .\run.ps1 finance --filter-first-n 1
  .\run.ps1 chat onboardbot    # Day 6 - explore a bot instead of evaluating it
  .\run.ps1 view

Pacing defaults to -j 1 --delay 1000 (override with RUN_JOBS / RUN_DELAY_MS).
'@ | Write-Host
}

function Import-DotEnv {
  if (-not (Test-Path .env)) { return $false }
  foreach ($line in Get-Content .env) {
    if ($line -match '^\s*#') { continue }
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
      $name = $Matches[1]; $val = $Matches[2].Trim()
      if ($val.Length -ge 2 -and
          ((($val[0] -eq '"') -and ($val[-1] -eq '"')) -or (($val[0] -eq "'") -and ($val[-1] -eq "'")))) {
        $val = $val.Substring(1, $val.Length - 2)
      }
      Set-Item -Path "env:$name" -Value $val
    }
  }
  return $true
}

$target = if ($args.Count -ge 1) { $args[0] } else { '' }
if ($target -in @('', '-h', '--help', '--list')) { Show-Usage; exit 0 }
$rest = if ($args.Count -ge 2) { $args[1..($args.Count - 1)] } else { @() }

if ($target -eq 'view') { & npx --yes promptfoo@latest view @rest; exit $LASTEXITCODE }

# `chat` is an interactive session, not an eval. Day 6 uses it for black-box work.
if ($target -eq 'chat') {
  Import-DotEnv | Out-Null
  & node scripts/chat.mjs @rest
  exit $LASTEXITCODE
}

$known = @('medibot','finance','quality.medibot','quality.finance','openrouter.medibot','openrouter.finance','mybot')
if ($target -notin $known) {
  Write-Host "$([char]0x2717) Unknown target: $target`n" -ForegroundColor Red
  Show-Usage
  exit 2
}
$cfg = "promptfooconfig.$target.yaml"
if (-not (Test-Path $cfg)) {
  Write-Host "$([char]0x2717) Config not found: $cfg - are you in the repo root?" -ForegroundColor Red
  exit 2
}

# Load .env so GROQ_API_KEY / OPENROUTER_API_KEY reach Promptfoo.
if (-not (Import-DotEnv)) {
  Write-Host "! No .env found - run .\setup.ps1 first (or set GROQ_API_KEY)." -ForegroundColor Yellow
}

Write-Host "$([char]0x25B6) Running $target  (-j $jobs --delay ${delay}ms)" -ForegroundColor Blue
Write-Host "  Reminder: these are red-team suites - a failing check means the model did the thing you were testing for. That's the finding, not an error.`n" -ForegroundColor Yellow

& npx --yes promptfoo@latest eval -c $cfg -j $jobs --delay $delay @rest
$ec = $LASTEXITCODE

Write-Host ""
switch ($ec) {
  0   { Write-Host "$([char]0x1F6E1)  Exit 0 - every guardrail held on this run." -ForegroundColor Green
        Write-Host "  Nothing landed. Try a tougher attack, a different model, or add your own case under tests/." }
  100 { Write-Host "$([char]0x2713) Exit 100 - one or more checks failed. That's the finding." -ForegroundColor Green
        Write-Host "  See which model broke on which case:  .\run.ps1 view" }
  default { Write-Host "$([char]0x2717) Exit $ec - that's an actual error, not a finding." -ForegroundColor Red
        Write-Host "  Usually a key / network / throttle issue - see docs/03-troubleshooting.md." }
}
exit $ec
