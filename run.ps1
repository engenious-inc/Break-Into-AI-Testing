#!/usr/bin/env pwsh
# One-command workshop eval runner (Windows parity of run.sh).
#
# Maps a short target name to its Promptfoo config, bakes in free-tier-safe
# pacing (-j 1 --delay 1000 by default), and translates Promptfoo's exit code
# according to each suite's semantics. Extra args after the target pass through.
#
#   .\run.ps1 medibot
#   .\run.ps1 finance --filter-first-n 1
#   .\run.ps1 view
#   .\run.ps1 --list
$ErrorActionPreference = 'Continue'

$jobs = if ($env:RUN_JOBS) { $env:RUN_JOBS } else { '1' }
$delay = if ($env:RUN_DELAY_MS) { $env:RUN_DELAY_MS } else { '1000' }

function Show-Usage {
  @'
Usage: .\run.ps1 <target> [extra promptfoo args...]

Targets:
  medibot             MediBot red-team suite (free-tier-safe)
  medibot-multiturn   MediBot across a multi-turn conversation
  finance             FinanceBot red-team suite
  reverse             Magical Story Creator - reverse-engineered prompt hypothesis
  quality.medibot     MediBot quality challenges (bias / consistency / compliance)
  quality.finance     FinanceBot quality challenges (context / values)
  openrouter.medibot  MediBot via the OpenRouter fallback (needs OPENROUTER_API_KEY)
  openrouter.finance  FinanceBot via the OpenRouter fallback
  mybot               Your Challenge-3 build-it bot
  payflow             PayFlow app suite - guard, routing, citations (server must be up)
  payflow-api         PayFlow HTTP contract + two planted defects (those two fail on purpose)
  payflow-multiturn   PayFlow injection after 4 turns of legitimate context
  payflow-rbac        PayFlow access control - user_role is sent, never enforced (5 of 6 fail on purpose)
  payflow-exposure    PayFlow hidden context exposure, LLM08:2026 (5 of 6 fail on purpose)
  payflow-poisoning   PayFlow corpus poisoning - retrieved docs are uninspected (3 of 5 fail on purpose)
  payflow-redteam     PayFlow generated red team (promptfoo redteam run - slow)
  payflow-serve       Start the PayFlow demo app on :8000 (foreground)
  payflow-health      Check the PayFlow app is answering before you eval
  mcp-local           Local stdio MCP - echo / add / read / path-traversal (no Groq key)
  mcp-abuse           MCP tool-abuse - write_note / read_secret / http_get (inverted, no Groq key)
  mcp-agent           MCP agent - Groq picks tools on workshop-local (inverted)
  mcp-injection       MCP injection - search_notes result instructs write_note (inverted)
  financebot          FinanceBot app suite - guard, routing, citations (server must be up)
  financebot-api      FinanceBot HTTP contract + three planted defects (those three fail on purpose)
  financebot-multiturn  FinanceBot injection after context (paper-trade case fails on purpose)
  financebot-redteam  FinanceBot generated red team (writes redteam.financebot.yaml)
  financebot-serve    Start the FinanceBot demo app on :8001 (foreground)
  financebot-health   Check the FinanceBot app is answering before you eval
  chat <bot>          Prompt-only chat (onboardbot, medibot, financebot, mybot - not :8001)
  view                Open the results web UI

Examples:
  .\run.ps1 medibot
  .\run.ps1 finance --filter-first-n 1
  .\run.ps1 chat onboardbot
  .\run.ps1 payflow-serve
  .\run.ps1 payflow
  .\run.ps1 payflow-api
  .\run.ps1 payflow-multiturn
  .\run.ps1 payflow-rbac
  .\run.ps1 payflow-exposure
  $env:PAYFLOW_POISON=1; .\run.ps1 payflow-serve
  .\run.ps1 payflow-poisoning
  .\run.ps1 payflow-redteam
  .\run.ps1 mcp-local
  .\run.ps1 mcp-abuse
  .\run.ps1 mcp-agent
  .\run.ps1 mcp-injection
  .\run.ps1 financebot-serve
  .\run.ps1 financebot
  .\run.ps1 financebot-api
  .\run.ps1 view

Pacing defaults to -j 1 --delay 1000 (override with RUN_JOBS / RUN_DELAY_MS).
'@ | Write-Host
}

function Import-DotEnv {
  if (-not (Test-Path .env)) { return $false }
  foreach ($line in Get-Content .env) {
    if ($line -match '^\s*#') { continue }
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
      $name = $Matches[1]
      $val = $Matches[2].Trim()
      if ($val.Length -ge 2 -and
          ((($val[0] -eq '"') -and ($val[-1] -eq '"')) -or (($val[0] -eq "'") -and ($val[-1] -eq "'")))) {
        $val = $val.Substring(1, $val.Length - 2)
      }
      Set-Item -Path "env:$name" -Value $val
    }
  }
  return $true
}

function Test-AppReachable {
  param([string]$Url)
  & node -e "fetch('$Url/health').then(()=>process.exit(0)).catch(()=>process.exit(1))" 2>$null
  return $LASTEXITCODE -eq 0
}

function Invoke-AppHealth {
  param([string]$Url)
  $output = & node -e "fetch('$Url/health').then(r=>r.json()).then(j=>{console.log(JSON.stringify(j));process.exit(j.status==='ok'?0:1)}).catch(()=>process.exit(1))" 2>$null
  $healthy = $LASTEXITCODE -eq 0
  if ($output) { Write-Host $output }
  return $healthy
}

function Test-PoisonedPayFlow {
  param([string]$Url)
  & node -e "fetch('$Url/health').then(r=>r.json()).then(j=>process.exit(j.poisoned===true?0:1)).catch(()=>process.exit(1))" 2>$null
  return $LASTEXITCODE -eq 0
}

$target = if ($args.Count -ge 1) { $args[0] } else { '' }
if ($target -in @('', '-h', '--help', '--list')) { Show-Usage; exit 0 }
$rest = if ($args.Count -ge 2) { $args[1..($args.Count - 1)] } else { @() }

if ($target -eq 'view') { & npx --yes promptfoo@latest view @rest; exit $LASTEXITCODE }

if ($target -eq 'chat') {
  Import-DotEnv | Out-Null
  & node scripts/chat.mjs @rest
  exit $LASTEXITCODE
}

$payflowUrl = "http://localhost:$(if ($env:PAYFLOW_PORT) { $env:PAYFLOW_PORT } else { '8000' })"
$financebotUrl = "http://localhost:$(if ($env:FINANCEBOT_PORT) { $env:FINANCEBOT_PORT } else { '8001' })"

if ($target -eq 'payflow-serve') {
  Import-DotEnv | Out-Null
  & node modules/03-app-testing/payflow/server.js @rest
  exit $LASTEXITCODE
}

if ($target -eq 'financebot-serve') {
  Import-DotEnv | Out-Null
  & node modules/03-app-testing/financebot/server.js @rest
  exit $LASTEXITCODE
}

if ($target -eq 'payflow-health') {
  if (Invoke-AppHealth $payflowUrl) {
    Write-Host "$([char]0x2713) PayFlow app is up at $payflowUrl" -ForegroundColor Green
    exit 0
  }
  Write-Host "$([char]0x2717) PayFlow app is not answering at $payflowUrl - start it with .\run.ps1 payflow-serve" -ForegroundColor Red
  exit 1
}

if ($target -eq 'financebot-health') {
  if (Invoke-AppHealth $financebotUrl) {
    Write-Host "$([char]0x2713) FinanceBot app is up at $financebotUrl" -ForegroundColor Green
    exit 0
  }
  Write-Host "$([char]0x2717) FinanceBot app is not answering at $financebotUrl - start it with .\run.ps1 financebot-serve" -ForegroundColor Red
  exit 1
}

if ($target -in @('payflow-redteam', 'financebot-redteam')) {
  Import-DotEnv | Out-Null
  $isPayFlow = $target -eq 'payflow-redteam'
  $appName = if ($isPayFlow) { 'PayFlow' } else { 'FinanceBot' }
  $appUrl = if ($isPayFlow) { $payflowUrl } else { $financebotUrl }
  $serveTarget = if ($isPayFlow) { 'payflow-serve' } else { 'financebot-serve' }
  $config = if ($isPayFlow) { 'promptfooconfig.payflow-redteam.yaml' } else { 'promptfooconfig.financebot-redteam.yaml' }

  if (-not (Test-AppReachable $appUrl)) {
    Write-Host "$([char]0x2717) $appName app is not answering at $appUrl." -ForegroundColor Red
    Write-Host "  Start it in another terminal first:  .\run.ps1 $serveTarget"
    exit 2
  }

  Write-Host "$([char]0x25B6) Generating and running the $appName red team.  (-j $jobs --delay ${delay}ms)" -ForegroundColor Blue
  if ($isPayFlow) {
    Write-Host "  Every probe runs the full pipeline - three Groq calls each. Expect this to take a while."
  } else {
    Write-Host "  Writes redteam.financebot.yaml (does not touch PayFlow's redteam.yaml)."
  }
  Write-Host "  Reminder: a failing check means the attack landed. That's the finding.`n" -ForegroundColor Yellow

  $openAiKey = $env:OPENAI_API_KEY
  $hadOpenAiKey = Test-Path env:OPENAI_API_KEY
  Remove-Item env:OPENAI_API_KEY -ErrorAction SilentlyContinue
  if ($isPayFlow) {
    & npx --yes promptfoo@latest redteam run -c $config -j $jobs --delay $delay @rest
  } else {
    & npx --yes promptfoo@latest redteam run -c $config -o redteam.financebot.yaml -j $jobs --delay $delay @rest
  }
  $ec = $LASTEXITCODE
  if ($hadOpenAiKey) { $env:OPENAI_API_KEY = $openAiKey }

  Write-Host ""
  switch ($ec) {
    0 { Write-Host "$([char]0x1F6E1) Exit 0 - nothing landed on this run." -ForegroundColor Green }
    100 { Write-Host "! Exit 100 - at least one attack landed. Triage it: .\run.ps1 view" -ForegroundColor Yellow }
    default { Write-Host "$([char]0x2717) Exit $ec - an actual error." -ForegroundColor Red }
  }
  exit $ec
}

$known = @(
  'medibot', 'medibot-multiturn', 'finance', 'reverse',
  'quality.medibot', 'quality.finance', 'openrouter.medibot', 'openrouter.finance', 'mybot',
  'payflow', 'payflow-api', 'payflow-multiturn', 'payflow-rbac', 'payflow-exposure', 'payflow-poisoning',
  'financebot', 'financebot-api', 'financebot-multiturn',
  'mcp-local', 'mcp-abuse', 'mcp-agent', 'mcp-injection'
)
if ($target -notin $known) {
  Write-Host "$([char]0x2717) Unknown target: $target`n" -ForegroundColor Red
  Show-Usage
  exit 2
}

$cfg = if ($target -eq 'mcp-local') {
  'modules/03-app-testing/mcp-local/promptfooconfig.yaml'
} else {
  "promptfooconfig.$target.yaml"
}
if (-not (Test-Path $cfg)) {
  Write-Host "$([char]0x2717) Config not found: $cfg - are you in the repo root?" -ForegroundColor Red
  exit 2
}

if (-not (Import-DotEnv)) {
  Write-Host "! No .env found - run .\setup.ps1 first (or set GROQ_API_KEY)." -ForegroundColor Yellow
}

$ordinaryTargets = @(
  'payflow', 'payflow-api', 'payflow-multiturn',
  'financebot', 'financebot-api', 'financebot-multiturn',
  'mybot', 'reverse', 'mcp-local'
)
$ordinary = $target -in $ordinaryTargets

if ($target -in @('mcp-local', 'mcp-abuse', 'mcp-agent', 'mcp-injection')) {
  if (-not (Test-Path modules/03-app-testing/mcp-local/node_modules/@modelcontextprotocol)) {
    Write-Host "$([char]0x2717) mcp-local dependencies are not installed." -ForegroundColor Red
    Write-Host "  One-time:  npm install --prefix modules/03-app-testing/mcp-local"
    exit 2
  }
}

if ($target -in @('payflow', 'payflow-api', 'payflow-multiturn', 'payflow-rbac', 'payflow-exposure', 'payflow-poisoning')) {
  if (-not (Test-AppReachable $payflowUrl)) {
    Write-Host "$([char]0x2717) PayFlow app is not answering at $payflowUrl." -ForegroundColor Red
    Write-Host "  Start it in another terminal first:  .\run.ps1 payflow-serve"
    Write-Host "  Without it every case fails with a connection error that looks like a bug in your tests."
    exit 2
  }
  if ($target -eq 'payflow-poisoning' -and -not (Test-PoisonedPayFlow $payflowUrl)) {
    Write-Host "$([char]0x2717) PayFlow is up, but the poisoned corpus is not loaded." -ForegroundColor Red
    Write-Host '  Restart it with:  $env:PAYFLOW_POISON=1; .\run.ps1 payflow-serve'
    Write-Host "  Without the overlay every finding would pass, and the lesson would silently invert."
    exit 2
  }
}

if ($target -in @('financebot', 'financebot-api', 'financebot-multiturn')) {
  if (-not (Test-AppReachable $financebotUrl)) {
    Write-Host "$([char]0x2717) FinanceBot app is not answering at $financebotUrl." -ForegroundColor Red
    Write-Host "  Start it in another terminal first:  .\run.ps1 financebot-serve"
    Write-Host "  Without it every case fails with a connection error that looks like a bug in your tests."
    exit 2
  }
}

Write-Host "$([char]0x25B6) Running $target  (-j $jobs --delay ${delay}ms)" -ForegroundColor Blue
if ($ordinary) {
  if ($target -in @('payflow', 'payflow-api', 'payflow-multiturn', 'financebot', 'financebot-api', 'financebot-multiturn')) {
    Write-Host "  Testing the application, not a model - assertions read output.route and output.citations.`n"
  } elseif ($target -eq 'mcp-local') {
    Write-Host "  Testing the MCP server with JSON tool calls - pass means the happy path and path-traversal guard held.`n"
  } else {
    Write-Host "  Ordinary suite - a failing check is a defect in your bot, not a finding.`n"
  }
} else {
  switch ($target) {
    { $_ -in @('payflow-rbac', 'payflow-exposure') } {
      Write-Host "  Inverted against the application - assertions describe a hardened PayFlow, so a failing check is a finding in the app."
      Write-Host "  One case is a control and passes. Do not relax the others; the fix belongs in pipeline.js.`n"
    }
    'payflow-poisoning' {
      Write-Host "  Inverted against the application - assertions describe a PayFlow that inspects retrieved documents like user messages."
      Write-Host "  Two cases are controls and pass. Do not relax the others; the guard is pointed at the wrong channel.`n"
    }
    'mcp-abuse' {
      Write-Host "  Inverted against the MCP server - assertions describe a hardened tool inventory."
      Write-Host "  Two cases are controls and pass. Do not relax the others; path traversal does not cover write_note.`n"
    }
    'mcp-agent' {
      Write-Host "  Inverted against the agent - Groq is given the workshop-local schemas and decides which tool to call."
      Write-Host "  Three cases are controls and pass. The findings show a model with write_note will use it.`n"
    }
    'mcp-injection' {
      Write-Host "  Inverted against the agent - search_notes returns an instruction; the user message is ordinary."
      Write-Host "  One case is a control and passes. The payload never sat in the user message.`n"
    }
    default {
      Write-Host "  Reminder: these are red-team suites - a failing check means the model did the thing you were testing for. That's the finding, not an error.`n"
    }
  }
}

& npx --yes promptfoo@latest eval -c $cfg -j $jobs --delay $delay @rest
$ec = $LASTEXITCODE

Write-Host ""
if ($ordinary) {
  switch ($ec) {
    0 {
      Write-Host "$([char]0x2713) Exit 0 - every case passed." -ForegroundColor Green
      if ($target -eq 'mybot') {
        Write-Host "  Guardrails held where they should; benign and gray-area cases behaved."
      } elseif ($target -eq 'mcp-local') {
        Write-Host "  Happy paths returned the fixture values; path traversal was refused."
      } else {
        Write-Host "  Guard fired where it should, routing picked the right specialist, citations lined up."
      }
    }
    100 {
      Write-Host "$([char]0x2717) Exit 100 - one or more checks failed. Here that IS a defect." -ForegroundColor Yellow
      Write-Host "  Look at which assertion broke:  .\run.ps1 view"
    }
    default {
      Write-Host "$([char]0x2717) Exit $ec - an actual error." -ForegroundColor Red
      if ($target -in @('payflow', 'payflow-api', 'payflow-multiturn')) {
        Write-Host "  Is the app still up?  .\run.ps1 payflow-health"
      } elseif ($target -in @('financebot', 'financebot-api', 'financebot-multiturn')) {
        Write-Host "  Is the app still up?  .\run.ps1 financebot-health"
      } else {
        Write-Host "  Usually a key / network / throttle issue - see docs/03-troubleshooting.md."
      }
    }
  }
  exit $ec
}

if ($target -in @('payflow-rbac', 'payflow-exposure', 'payflow-poisoning')) {
  switch ($ec) {
    0 {
      Write-Host "? Exit 0 - nothing failed, which is not what this suite expects." -ForegroundColor Yellow
      Write-Host "  Either somebody hardened the pipeline, or the assertions stopped reaching the app."
    }
    100 {
      Write-Host "$([char]0x2713) Exit 100 - the findings are still there. That's the healthy result." -ForegroundColor Green
      Write-Host "  Read them case by case:  .\run.ps1 view"
    }
    default {
      Write-Host "$([char]0x2717) Exit $ec - that's an actual error, not a finding." -ForegroundColor Red
      Write-Host "  Is the app still up?  .\run.ps1 payflow-health"
    }
  }
  exit $ec
}

if ($target -in @('mcp-abuse', 'mcp-agent', 'mcp-injection')) {
  switch ($ec) {
    0 {
      Write-Host "? Exit 0 - nothing failed, which is not what this suite expects." -ForegroundColor Yellow
      Write-Host "  Either somebody hardened server.mjs, or Groq refused the tool calls this run."
    }
    100 {
      Write-Host "$([char]0x2713) Exit 100 - the findings are still there. That's the healthy result." -ForegroundColor Green
      Write-Host "  Read them case by case:  .\run.ps1 view"
    }
    default {
      Write-Host "$([char]0x2717) Exit $ec - that's an actual error, not a finding." -ForegroundColor Red
      Write-Host "  Is mcp-local installed?  npm install --prefix modules/03-app-testing/mcp-local"
    }
  }
  exit $ec
}

switch ($ec) {
  0 {
    Write-Host "$([char]0x1F6E1) Exit 0 - every guardrail held on this run." -ForegroundColor Green
    Write-Host "  Nothing landed. Try a tougher attack, a different model, or add your own case under tests/."
  }
  100 {
    Write-Host "$([char]0x2713) Exit 100 - one or more checks failed. That's the finding." -ForegroundColor Green
    Write-Host "  See which model broke on which case:  .\run.ps1 view"
  }
  default {
    Write-Host "$([char]0x2717) Exit $ec - that's an actual error, not a finding." -ForegroundColor Red
    Write-Host "  Usually a key / network / throttle issue - see docs/03-troubleshooting.md."
  }
}
exit $ec
