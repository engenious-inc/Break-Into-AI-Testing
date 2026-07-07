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
