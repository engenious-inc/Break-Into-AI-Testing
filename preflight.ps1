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

# Phase 2 — live Groq check (only if the key looked usable)
if ($keyOk) {
  try {
    $resp = Invoke-WebRequest -Uri "$base/chat/completions" -Method Post -TimeoutSec 10 `
      -Headers @{ Authorization = "Bearer $key"; "Content-Type" = "application/json" } `
      -Body '{"model":"llama-3.1-8b-instant","messages":[{"role":"user","content":"ping"}],"max_tokens":1,"temperature":0}' `
      -SkipHttpErrorCheck
    $status = [int]$resp.StatusCode
    switch ($status) {
      200 {
        $rem = $resp.Headers['x-ratelimit-remaining-requests']
        if ($rem -is [array]) { $rem = $rem[0] }
        $remInt = $rem -as [int]
        if (($null -ne $remInt) -and ($remInt -lt 5)) { Warn "Groq reachable, key valid — but only $rem requests left this window" }
        elseif ($null -ne $remInt) { Ok "Groq reachable, key valid ($rem requests remaining)" }
        else { Ok "Groq reachable, key valid" }
      }
      401 { Bad "Groq rejected your key (401) — check GROQ_API_KEY in .env or regenerate at https://console.groq.com/keys"; $fail = $true }
      429 {
        $ra = $resp.Headers['retry-after']; if ($ra -is [array]) { $ra = $ra[0] }
        $wait = if ($ra) { " — wait ${ra}s" } else { "" }
        Warn "Configured correctly, but currently throttled (429)$wait; add -j 2 to your evals"
      }
      default { Bad "Unexpected response from Groq (HTTP $status) — see docs/03-troubleshooting.md"; $fail = $true }
    }
  } catch {
    Bad "Couldn't reach $base ($($_.Exception.Message)) — check your network / VPN"; $fail = $true
  }
}

Write-Host ""
if (-not $fail) { Ok "READY — you're set for the workshop"; exit 0 }
else { Bad "NOT READY — fix the marked items above (see docs/03-troubleshooting.md)"; exit 1 }
