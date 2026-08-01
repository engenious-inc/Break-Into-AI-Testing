#!/usr/bin/env pwsh
# Read-only workshop readiness probe (Windows parity of preflight.sh). Changes nothing.
$ErrorActionPreference = 'Continue'
function Ok($m)   { Write-Host "$([char]0x2713) $m" -ForegroundColor Green }
function Warn($m) { Write-Host "! $m" -ForegroundColor Yellow }
function Bad($m)  { Write-Host "$([char]0x2717) $m" -ForegroundColor Red }

$base = if ($env:GROQ_API_BASE) { $env:GROQ_API_BASE } else { "https://api.groq.com/openai/v1" }
$fail = $false
$keyOk = $false

Write-Host "-- Promptfoo Red-Team Workshop . preflight --"

# 1. Node >= 20
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
  $ver = (& node -v) -replace 'v',''
  $maj = [int]($ver.Split('.')[0])
  if ($maj -lt 20) { Bad "Node v$ver found, need >= 20 — run .\setup.ps1"; $fail = $true }
  else { Ok "Node v$ver" }
} else { Bad "Node not found — run .\setup.ps1"; $fail = $true }

# 2. promptfoo resolves
& npx --yes promptfoo@latest --version *> $null
if ($LASTEXITCODE -eq 0) { Ok "Promptfoo ready" }
else { Bad "Promptfoo not available — run .\setup.ps1"; $fail = $true }

# 3. .env exists — parse it if so (does not source or modify it)
$key = $null
if (Test-Path .env) {
  Ok ".env present"
  foreach ($line in Get-Content .env) {
    if ($line -match '^\s*GROQ_API_KEY\s*=\s*(.*)$') {
      $v = $Matches[1].Trim()
      if ($v.Length -ge 2 -and
          ((($v[0] -eq '"') -and ($v[-1] -eq '"')) -or (($v[0] -eq "'") -and ($v[-1] -eq "'")))) {
        $v = $v.Substring(1, $v.Length - 2)
      }
      $key = $v
    }
  }
} else { Bad ".env missing — run .\setup.ps1"; $fail = $true }

# 4. GROQ_API_KEY sanity (never printed)
if (-not $key) { Bad "GROQ_API_KEY not set — run .\setup.ps1 or edit .env"; $fail = $true }
elseif ($key -eq 'gsk-replace-me') { Bad "GROQ_API_KEY is still the placeholder — paste your real key into .env"; $fail = $true }
else { Ok "GROQ_API_KEY present"; $keyOk = $true }

# 5. Starter files intact
$need = @('promptfooconfig.medibot.yaml','prompts/medibot.txt','tests/smoke.medibot.yaml',
          'promptfooconfig.mybot.yaml','prompts/mybot.txt','tests/mybot.yaml')
$missing = $need | Where-Object { -not (Test-Path $_) }
if ($missing.Count -eq 0) { Ok "Starter files intact" }
else {
  Bad "Missing starter files: $($missing -join ' ')"; $fail = $true
  $missing | ForEach-Object { Write-Host "    restore with: git checkout -- $_" }
}

# 6. Module config file references resolve (key-free structural check)
# Every shipped default config must reference prompt/test files that exist.
# Debugger fix-me configs are intentionally broken, and the new-eval-suite
# skill template still has unfilled placeholders — both are skipped.
$cfgMissing = $false
$configs = Get-ChildItem -Path . -Recurse -Filter 'promptfooconfig*.yaml' -File |
  Where-Object { $_.FullName -notmatch '[\\/]node_modules[\\/]' }
foreach ($cfg in $configs) {
  if ($cfg.FullName -match '[\\/]debugger[\\/]') { continue }   # intentionally broken — skip
  if ($cfg.Name -like '*.template.yaml') { continue }           # skill scaffold placeholder — skip
  $cfgDir = $cfg.DirectoryName
  $refs = Select-String -Path $cfg.FullName -Pattern 'file://([^" ]+)' -AllMatches |
    ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }
  foreach ($ref in $refs) {
    if (-not $ref) { continue }
    $target = Join-Path $cfgDir $ref
    if (-not (Test-Path $target) -and -not (Test-Path $ref)) {
      Write-Host "    $($cfg.FullName) references missing $ref"
      $cfgMissing = $true
    }
  }
}
if (-not $cfgMissing) { Ok "Module config file references resolve" }
else { Bad "Some module config references are missing (see above)"; $fail = $true }

# Phase 2 — live Groq check (only if the key looked usable)
if ($keyOk) {
  try {
    # No -SkipHttpErrorCheck: it doesn't exist on Windows PowerShell 5.1 (the
    # documented target). On 5.1 a non-2xx response throws; we read the status
    # from the exception in the catch. Invoke-WebRequest only returns here on 2xx.
    $resp = Invoke-WebRequest -Uri "$base/chat/completions" -Method Post -TimeoutSec 10 `
      -Headers @{ Authorization = "Bearer $key"; "Content-Type" = "application/json" } `
      -Body '{"model":"llama-3.1-8b-instant","messages":[{"role":"user","content":"ping"}],"max_tokens":1,"temperature":0}'
    $rem = $resp.Headers['x-ratelimit-remaining-requests']
    if ($rem -is [array]) { $rem = $rem[0] }
    $remInt = $rem -as [int]
    if (($null -ne $remInt) -and ($remInt -lt 5)) { Warn "Groq reachable, key valid — but only $rem requests left this window" }
    elseif ($null -ne $remInt) { Ok "Groq reachable, key valid ($rem requests remaining)" }
    else { Ok "Groq reachable, key valid" }
  } catch {
    # Non-2xx (or transport failure): dig the HTTP status out of the exception.
    # $_.Exception.Response.StatusCode is a [System.Net.HttpStatusCode] enum on
    # both Windows PowerShell 5.1 and pwsh 7, so [int] gives the numeric code.
    $status = $null
    $exResp = $_.Exception.Response
    if ($exResp) { try { $status = [int]$exResp.StatusCode } catch { $status = $null } }
    if ($null -eq $status) {
      Bad "Couldn't reach $base ($($_.Exception.Message)) — check your network / VPN"; $fail = $true
    }
    elseif ($status -eq 401) {
      Bad "Groq rejected your key (401) — check GROQ_API_KEY in .env or regenerate at https://console.groq.com/keys"; $fail = $true
    }
    elseif ($status -eq 429) {
      $ra = $null
      try { $ra = $exResp.Headers['Retry-After'] } catch { $ra = $null }
      if ($ra -is [array]) { $ra = $ra[0] }
      $wait = if ($ra) { " — wait ${ra}s" } else { "" }
      Warn "Configured correctly, but currently throttled (429)$wait; add -j 2 to your evals"
    }
    else {
      Bad "Unexpected response from Groq (HTTP $status) — see docs/03-troubleshooting.md"; $fail = $true
    }
  }
}

Write-Host ""
if (-not $fail) { Ok "READY — you're set for the workshop"; exit 0 }
else { Bad "NOT READY — fix the marked items above (see docs/03-troubleshooting.md)"; exit 1 }
