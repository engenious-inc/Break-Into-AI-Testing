# Preflight Readiness Check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `preflight.sh` (+ `preflight.ps1`) — a read-only, re-runnable readiness probe that gives attendees a clear green/red verdict and names the specific fix for a bad key, a throttle, or a broken environment.

**Architecture:** Plain-shell environment checks (no network, no side effects) followed by one classified `curl` to Groq's chat endpoint. The single request separates the three prioritized failure modes by HTTP status (200 / 401 / 429 / connection error), which `promptfoo` cannot. A `GROQ_API_BASE` env seam lets every live-check branch be exercised against a local mock offline.

**Tech Stack:** Bash + `curl` (macOS/Linux); PowerShell 7 + `Invoke-WebRequest` (Windows). No new project dependencies. Python 3 stdlib is used only for a throwaway mock during verification (never committed).

## Global Constraints

Copied verbatim from the spec — every task implicitly includes these:

- **Read-only / no side effects** — preflight only reports; it never installs, writes, or mutates `.env`. `setup.sh` remains the only mutating tool.
- **Never print or log the API key.**
- **Exit codes:** `0` = ready (a 429 throttle is ready-with-warning); `1` = not ready (any hard `✗`).
- **`GROQ_API_BASE`** default `https://api.groq.com/openai/v1`; overridable via env.
- **Live call:** model `llama-3.1-8b-instant`, `max_tokens: 1`, `temperature: 0`, `curl --max-time 10`.
- **Visual style:** reuse `setup.sh`'s color scheme and `✓` / `!` / `✗` glyphs.
- **Node floor:** `>= 20` (report only; never install).
- **Cross-platform:** `preflight.sh` and `preflight.ps1` must be behaviourally identical — same checks, messages, verdict, and exit codes.
- **OpenRouter fallback key is NOT checked.**

**TDD note for this plan:** there is no committed test framework (spec decision — YAGNI for a workshop utility). Each task's red→green cycle is a **verification run**: first observe the absent/wrong behavior, implement, then re-run and observe the correct behavior. Phase-2 branches are driven by a throwaway Python mock (shown inline; never committed).

---

## File Structure

| File | Responsibility |
|------|----------------|
| `preflight.sh` | The readiness probe (Bash). Phase 1 env checks + Phase 2 live check + verdict. |
| `preflight.ps1` | Windows parity (PowerShell 7). Identical behavior. |
| `README.md` | Add the morning-of "run preflight" note. |
| `docs/01-quickstart.md` | Add both scripts to the file map + a readiness note. |
| `docs/03-troubleshooting.md` | Add a "preflight says NOT READY" section mapping outcomes to fixes. |
| `setup.sh`, `setup.ps1` | One added line in the closing "Next:" block suggesting preflight. |

**Task ordering:** Task 1 (Phase 1) → Task 2 (Phase 2, same file) → Task 3 (PowerShell parity) → Task 4 (docs + setup nudge). Tasks 3 and 4 depend only on the finished `preflight.sh` from Tasks 1–2.

---

## Task 1: `preflight.sh` — Phase 1 (environment checks + verdict scaffolding)

Produces a runnable, offline-testable script that checks the environment and prints a READY/NOT READY verdict. Phase 2 is added in Task 2.

**Files:**
- Create: `preflight.sh`

**Interfaces:**
- Produces: an executable `./preflight.sh` that sets an internal `fail` flag (0/1), prints `✓`/`✗` lines via `ok`/`warn`/`bad` helpers, exposes `GROQ_API_BASE` (default set here), sources `.env` when present, and exits `0` (ready) or `1` (not ready). Task 2 inserts its Phase-2 block immediately before the final verdict and relies on the `key_ok` variable (1 when a real key is present) and the `bad`/`ok`/`warn` helpers defined here.

- [ ] **Step 1: Establish the absent behavior**

Run: `./preflight.sh`
Expected: `zsh: no such file or directory: ./preflight.sh` (the script does not exist yet).

- [ ] **Step 2: Create `preflight.sh` with the Phase 1 implementation**

```bash
#!/usr/bin/env bash
# Read-only workshop readiness probe. Safe to re-run anytime; changes nothing.
set -uo pipefail   # deliberately NOT -e: run every check and tally, don't abort early

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { printf "${GREEN}\xe2\x9c\x93${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}!${NC} %s\n" "$1"; }
bad()  { printf "${RED}\xe2\x9c\x97${NC} %s\n" "$1"; }

GROQ_API_BASE="${GROQ_API_BASE:-https://api.groq.com/openai/v1}"
fail=0        # set to 1 on any hard problem
key_ok=0      # set to 1 when a usable key is present (drives Phase 2 in Task 2)

echo "-- Promptfoo Red-Team Workshop . preflight --"

# ── Phase 1 — environment (read-only, no network) ────────────────────────────

# 1. Node >= 20
if command -v node >/dev/null 2>&1; then
  major="$(node -v | sed 's/v//' | cut -d. -f1)"
  if [ "$major" -lt 20 ]; then
    bad "Node $(node -v) found, need >= 20 — run ./setup.sh"; fail=1
  else
    ok "Node $(node -v)"
  fi
else
  bad "Node not found — run ./setup.sh"; fail=1
fi

# 2. promptfoo resolves (may warm a cold npx cache — that is acceptable)
if npx --yes promptfoo@latest --version >/dev/null 2>&1; then
  ok "Promptfoo ready"
else
  bad "Promptfoo not available — run ./setup.sh"; fail=1
fi

# 3. .env exists — load it if so (does not create or modify it)
if [ -f .env ]; then
  ok ".env present"
  set -a; . ./.env; set +a
else
  bad ".env missing — run ./setup.sh"; fail=1
fi

# 4. GROQ_API_KEY sanity (never printed)
key="${GROQ_API_KEY:-}"
if [ -z "$key" ]; then
  bad "GROQ_API_KEY not set — run ./setup.sh or edit .env"; fail=1
elif [ "$key" = "gsk-replace-me" ]; then
  bad "GROQ_API_KEY is still the placeholder — paste your real key into .env"; fail=1
else
  ok "GROQ_API_KEY present"; key_ok=1
fi

# 5. Starter files intact
missing=""
for f in promptfooconfig.medibot.yaml prompts/medibot.txt tests/smoke.medibot.yaml \
         promptfooconfig.mybot.yaml prompts/mybot.txt tests/mybot.yaml; do
  [ -f "$f" ] || missing="$missing $f"
done
if [ -z "$missing" ]; then
  ok "Starter files intact"
else
  bad "Missing starter files:$missing"; fail=1
  for f in $missing; do echo "    restore with: git checkout -- $f"; done
fi

# ── Phase 2 inserted here in Task 2 ──────────────────────────────────────────

# ── Verdict ──────────────────────────────────────────────────────────────────
echo
if [ "$fail" -eq 0 ]; then
  ok "READY — you're set for the workshop"; exit 0
else
  bad "NOT READY — fix the marked items above (see docs/03-troubleshooting.md)"; exit 1
fi
```

- [ ] **Step 3: Make it executable**

Run: `chmod +x preflight.sh`
Expected: no output; `ls -l preflight.sh` shows the `x` bit.

- [ ] **Step 4: Verify the healthy path (real `.env` present)**

Run: `./preflight.sh; echo "exit=$?"`
Expected: `✓` lines for Node, Promptfoo, `.env`, GROQ_API_KEY, Starter files, then `✓ READY …` and `exit=0`. (Phase 2 not present yet, so no live-check line.)

- [ ] **Step 5: Verify the missing-key path**

Run:
```bash
cp .env .env.bak
sed -i.tmp 's/^GROQ_API_KEY=.*/GROQ_API_KEY=gsk-replace-me/' .env && rm -f .env.tmp
./preflight.sh; echo "exit=$?"
mv .env.bak .env
```
Expected: `✗ GROQ_API_KEY is still the placeholder …`, final `✗ NOT READY …`, `exit=1`. After the `mv`, `.env` is restored to your real key.

- [ ] **Step 6: Verify the missing-file path**

Run:
```bash
mv tests/mybot.yaml /tmp/mybot.yaml.hold
./preflight.sh; echo "exit=$?"
mv /tmp/mybot.yaml.hold tests/mybot.yaml
```
Expected: `✗ Missing starter files: tests/mybot.yaml` with a `restore with: git checkout -- tests/mybot.yaml` hint, final `✗ NOT READY …`, `exit=1`.

- [ ] **Step 7: Commit**

```bash
git add preflight.sh
git commit -m "feat: add preflight.sh Phase 1 environment checks"
```

---

## Task 2: `preflight.sh` — Phase 2 (live Groq check)

Adds the single classified `curl`. Depends on Task 1 (`key_ok`, helpers, `GROQ_API_BASE`).

**Files:**
- Modify: `preflight.sh` (replace the `# ── Phase 2 inserted here in Task 2 ──` marker line)

**Interfaces:**
- Consumes: `key_ok` (1 = call Groq), `key`, `GROQ_API_BASE`, `fail`, and the `ok`/`warn`/`bad` helpers from Task 1.
- Produces: nothing new for later tasks; finalizes `preflight.sh` behavior.

- [ ] **Step 1: Establish the absent behavior**

Run: `./preflight.sh`
Expected: the script prints Phase 1 lines then the verdict, with **no** "Groq reachable" / throttle / network line — Phase 2 is not implemented yet.

- [ ] **Step 2: Replace the Phase 2 marker with the implementation**

Replace the single line:
```bash
# ── Phase 2 inserted here in Task 2 ──────────────────────────────────────────
```
with:
```bash
# ── Phase 2 — live Groq check (one curl; only if the key looked usable) ──────
if [ "$key_ok" -eq 1 ]; then
  hdr="$(mktemp)"
  status="$(curl -sS -m 10 -o /dev/null -D "$hdr" -w '%{http_code}' \
    -X POST "$GROQ_API_BASE/chat/completions" \
    -H "Authorization: Bearer $key" \
    -H "Content-Type: application/json" \
    -d '{"model":"llama-3.1-8b-instant","messages":[{"role":"user","content":"ping"}],"max_tokens":1,"temperature":0}')"
  curl_exit=$?
  if [ "$curl_exit" -ne 0 ]; then
    bad "Couldn't reach ${GROQ_API_BASE} (curl exit ${curl_exit}) — check your network / VPN"; fail=1
  else
    case "$status" in
      200)
        remaining="$(grep -i '^x-ratelimit-remaining-requests:' "$hdr" | tr -d '\r' | awk '{print $2}')"
        if [ -n "$remaining" ] && [ "$remaining" -lt 5 ] 2>/dev/null; then
          warn "Groq reachable, key valid — but only ${remaining} requests left this window"
        elif [ -n "$remaining" ]; then
          ok "Groq reachable, key valid (${remaining} requests remaining)"
        else
          ok "Groq reachable, key valid"
        fi
        ;;
      401)
        bad "Groq rejected your key (401) — check GROQ_API_KEY in .env or regenerate at https://console.groq.com/keys"; fail=1
        ;;
      429)
        retry="$(grep -i '^retry-after:' "$hdr" | tr -d '\r' | awk '{print $2}')"
        warn "Configured correctly, but currently throttled (429)${retry:+ — wait ${retry}s}; add -j 2 to your evals"
        ;;
      *)
        bad "Unexpected response from Groq (HTTP ${status}) — see docs/03-troubleshooting.md"; fail=1
        ;;
    esac
  fi
  rm -f "$hdr"
fi
```

- [ ] **Step 3: Verify the live healthy path (real key, real Groq)**

Run: `./preflight.sh; echo "exit=$?"`
Expected: a `✓ Groq reachable, key valid (N requests remaining)` line, `✓ READY …`, `exit=0`.

- [ ] **Step 4: Start a local mock to drive the status-code branches**

Run (leave this in its own terminal, or background it):
```bash
MOCK_CODE=401 python3 - <<'PY' &
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
CODE = int(os.environ.get("MOCK_CODE", "200"))
class H(BaseHTTPRequestHandler):
    def do_POST(self):
        self.send_response(CODE)
        self.send_header("x-ratelimit-remaining-requests", "2")
        if CODE == 429:
            self.send_header("retry-after", "7")
        self.end_headers()
        self.wfile.write(b'{"choices":[{"message":{"content":"pong"}}]}')
    def log_message(self, *a):
        pass
HTTPServer(("127.0.0.1", 8899), H).serve_forever()
PY
MOCK_PID=$!
```
Expected: the mock is listening on `127.0.0.1:8899`, returning HTTP 401.

- [ ] **Step 5: Verify the 401 branch against the mock**

Run: `GROQ_API_BASE=http://127.0.0.1:8899/v1 ./preflight.sh; echo "exit=$?"`
Expected: `✗ Groq rejected your key (401) …`, `✗ NOT READY …`, `exit=1`.
(Note: sourcing `.env` supplies a present, non-placeholder key so Phase 2 runs; the mock ignores the key and returns its configured code.)

- [ ] **Step 6: Verify the 429 and low-headroom (200) branches**

Run:
```bash
kill $MOCK_PID 2>/dev/null
MOCK_CODE=429 python3 - <<'PY' &
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
CODE = int(os.environ.get("MOCK_CODE", "200"))
class H(BaseHTTPRequestHandler):
    def do_POST(self):
        self.send_response(CODE)
        self.send_header("x-ratelimit-remaining-requests", "2")
        if CODE == 429:
            self.send_header("retry-after", "7")
        self.end_headers(); self.wfile.write(b'{}')
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", 8899), H).serve_forever()
PY
MOCK_PID=$!
GROQ_API_BASE=http://127.0.0.1:8899/v1 ./preflight.sh; echo "exit=$?"
```
Expected: `! Configured correctly, but currently throttled (429) — wait 7s; add -j 2 …`, `✓ READY …`, `exit=0` (throttle is ready-with-warning). Re-run with `MOCK_CODE=200` to confirm the low-headroom warning: `! Groq reachable, key valid — but only 2 requests left this window`.

- [ ] **Step 7: Verify the network-error branch, then stop the mock**

Run:
```bash
kill $MOCK_PID 2>/dev/null
GROQ_API_BASE=http://127.0.0.1:9999/v1 ./preflight.sh; echo "exit=$?"
```
Expected: `✗ Couldn't reach http://127.0.0.1:9999/v1 (curl exit 7) — check your network / VPN`, `✗ NOT READY …`, `exit=1`.

- [ ] **Step 8: Commit**

```bash
git add preflight.sh
git commit -m "feat: add preflight.sh Phase 2 live Groq check with status classification"
```

---

## Task 3: `preflight.ps1` — Windows parity

A behaviourally identical PowerShell 7 port.

**Files:**
- Create: `preflight.ps1`

**Interfaces:**
- Produces: `.\preflight.ps1` with the same checks, messages, verdict, and exit codes as `preflight.sh`.

- [ ] **Step 1: Establish the absent behavior**

Run (Windows PowerShell 7, or `pwsh` if installed on macOS/Linux): `./preflight.ps1`
Expected: an error that the file does not exist.

- [ ] **Step 2: Create `preflight.ps1`**

```powershell
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

# 3. .env exists — load it if so (does not create or modify it)
$key = $null
if (Test-Path .env) {
  Ok ".env present"
  Get-Content .env | ForEach-Object {
    if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
      Set-Item -Path "Env:$($Matches[1])" -Value $Matches[2].Trim()
    }
  }
  $key = $env:GROQ_API_KEY
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
        if ($rem -and [int]$rem -lt 5) { Warn "Groq reachable, key valid — but only $rem requests left this window" }
        elseif ($rem) { Ok "Groq reachable, key valid ($rem requests remaining)" }
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
```

- [ ] **Step 3: Verify (Windows PowerShell 7, or `pwsh` if available)**

Run: `./preflight.ps1` with a healthy `.env`.
Expected: `✓` lines and `✓ READY …`; `echo $LASTEXITCODE` (or `$?`) reflects exit 0.
If no PowerShell runtime is available in the dev environment, perform a **line-by-line parity review** against `preflight.sh`: every check, message string, verdict, and exit code must match. Note in the PR which verification was done.

- [ ] **Step 4: Commit**

```bash
git add preflight.ps1
git commit -m "feat: add preflight.ps1 Windows parity"
```

---

## Task 4: Docs integration + setup nudge

Wire preflight into the docs and the closing lines of setup.

**Files:**
- Modify: `README.md`
- Modify: `docs/01-quickstart.md`
- Modify: `docs/03-troubleshooting.md`
- Modify: `setup.sh:92-99` (the closing "Next:" block)
- Modify: `setup.ps1` (its equivalent closing "Next:" block)

**Interfaces:** none (documentation and a print statement only).

- [ ] **Step 1: README — add a readiness note**

In `README.md`, immediately after the `## Run the workshop eval` section, insert:
```markdown
## Check you're ready

Anytime before the workshop (especially the morning of), run the read-only readiness probe:

```bash
./preflight.sh        # macOS / Linux
.\preflight.ps1       # Windows (PowerShell)
```

It changes nothing and re-runs safely. On a problem it names the exact fix — a bad or
missing key, a rate-limit throttle, or an environment that needs `./setup.sh` again.
```

- [ ] **Step 2: Quickstart — file map + note**

In `docs/01-quickstart.md`, under the `## File map` section add two entries:
```markdown
- `preflight.sh` / `preflight.ps1` — read-only readiness probe; run before the workshop to confirm your key, network, and environment are good.
```
And add a one-line pointer after the file map:
```markdown
> Not sure you're ready? Run `./preflight.sh` (`.\preflight.ps1` on Windows) — it's safe to run repeatedly.
```

- [ ] **Step 3: Troubleshooting — map preflight outcomes to fixes**

In `docs/03-troubleshooting.md`, add a new section:
```markdown
### `preflight.sh` (or `preflight.ps1`) says NOT READY

Fix the item(s) marked `✗`:

- **GROQ_API_KEY not set / still the placeholder** — run `./setup.sh`, or paste your key into `.env`. Get one free at https://console.groq.com/keys.
- **Groq rejected your key (401)** — the key is wrong or expired. Regenerate it and update `.env`.
- **Currently throttled (429)** — transient; wait the reported seconds and add `-j 2` to your evals. Your setup is fine.
- **Couldn't reach api.groq.com** — check your network / VPN; if Groq is down, use the OpenRouter fallback (see the section above).
- **Node / Promptfoo / .env missing** — run `./setup.sh` again.
- **Missing starter files** — restore with the `git checkout -- <file>` command preflight prints.
```

- [ ] **Step 4: setup.sh — suggest preflight in the "Next:" block**

In `setup.sh`, inside the closing block (currently ending at line 99), add after the `view` line:
```bash
echo
echo "Before the workshop, re-check you're ready anytime with:"
echo "  ./preflight.sh"
```

- [ ] **Step 5: setup.ps1 — mirror the suggestion**

In `setup.ps1`, in its equivalent closing "Next:" block, add after its `view` line:
```powershell
Write-Host ""
Write-Host "Before the workshop, re-check you're ready anytime with:"
Write-Host "  .\preflight.ps1"
```

- [ ] **Step 6: Verify the doc references resolve**

Run:
```bash
grep -n "preflight" README.md docs/01-quickstart.md docs/03-troubleshooting.md setup.sh setup.ps1
```
Expected: at least one hit in each of the five files. Skim each edit to confirm the surrounding markdown/section still reads correctly.

- [ ] **Step 7: Commit**

```bash
git add README.md docs/01-quickstart.md docs/03-troubleshooting.md setup.sh setup.ps1
git commit -m "docs: wire preflight into README, quickstart, troubleshooting, and setup"
```

---

## Self-Review

**1. Spec coverage:**
- Read-only/no-side-effects probe → Task 1 (`set -uo pipefail`, no writes) ✓
- Positioning vs setup.sh → Task 4 setup nudge + troubleshooting section ✓
- Phase 1 checks (Node≥20, promptfoo, .env, key missing/placeholder/present, starter files) → Task 1 Steps 2,4,5,6 ✓
- Phase 2 one curl, status table 200/401/429/other/network → Task 2 Step 2; verified Steps 3,5,6,7 ✓
- Headroom parse + low warning (<5) → Task 2 Step 2 (200 branch), verified Step 6 ✓
- Verdict + exit codes 0/1 (429 = ready-with-warning) → Task 1 verdict, Task 2 429 branch ✓
- `GROQ_API_BASE` seam + mock testing → Global Constraints + Task 2 Steps 4–7 ✓
- Never print key → Task 1 Step 2 (key never echoed) ✓
- Windows `.ps1` parity → Task 3 ✓
- Docs integration (README, quickstart, troubleshooting, setup) → Task 4 ✓
- OpenRouter not checked → honored (no key check present) ✓

**2. Placeholder scan:** No TBD/TODO/"handle edge cases"/"similar to Task N". All code shown in full; the only intentional literal placeholders are shell interpolations (`${remaining}`, `<file>`) inside real code. ✓

**3. Type/name consistency:** `ok`/`warn`/`bad` helpers, `fail`, `key_ok`, `key`, `GROQ_API_BASE`, `hdr`, `status` used identically across Tasks 1–2. PowerShell mirrors names (`$fail`, `$keyOk`, `$base`) consistently in Task 3. Glyphs/messages match between `.sh` and `.ps1`. ✓
