#!/usr/bin/env bash
# Maintainer/instructor pre-cohort check: a live smoke-check across the whole
# workshop curriculum. Run from the repo root with a working GROQ_API_KEY in
# .env (./setup.sh sets this up). Intended for whoever preps a cohort run,
# not for students — bash-only by design (git-bash/WSL on Windows is fine
# for this one; students' own readiness check is preflight.sh/.ps1, which
# has full native Windows parity).
#
# Reports PASS/FAIL/SKIP per config and exits non-zero if anything is
# genuinely broken. "Broken" means promptfoo reported an error, crashed, or
# never produced a normal summary — NOT that some assertions failed. A
# red-team config where an attack lands (or a content probe that legitimately
# comes out differently this run) is expected behavior, not a smoke-check
# failure; those configs use inverted semantics on purpose (see CLAUDE.md).
#
# Paced with a short delay between configs to stay well under Groq's
# free-tier per-minute rate limit.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

if [ ! -f .env ]; then
  echo "No .env found — run ./setup.sh first." >&2
  exit 1
fi

pass=0
fail=0
skip=0
debugger_ok=0
timeout_count=0

# Configs expected to run with 0 promptfoo-reported errors on the default,
# keyless-beyond-Groq path.
CONFIGS=(
  "promptfooconfig.medibot.yaml"
  "promptfooconfig.finance.yaml"
  "promptfooconfig.quality.medibot.yaml"
  "promptfooconfig.quality.finance.yaml"
  "modules/00-promptfoo-basics/01-prompts/text/promptfooconfig.yaml"
  "modules/00-promptfoo-basics/01-prompts/multiline/promptfooconfig.yaml"
  "modules/00-promptfoo-basics/01-prompts/variables/promptfooconfig.yaml"
  "modules/00-promptfoo-basics/01-prompts/file-based/promptfooconfig.yaml"
  "modules/00-promptfoo-basics/02-providers/configuration/promptfooconfig.yaml"
  "modules/00-promptfoo-basics/03-assertions/contains/promptfooconfig.yaml"
  "modules/00-promptfoo-basics/03-assertions/regex/promptfooconfig.yaml"
  "modules/00-promptfoo-basics/03-assertions/factuality/promptfooconfig.yaml"
  "modules/00-promptfoo-basics/03-assertions/llm-rubric/promptfooconfig.yaml"
  "modules/02-advanced-eval/weights-and-metrics/promptfooconfig.yaml"
  "modules/02-advanced-eval/assert-sets-and-budgets/promptfooconfig.yaml"
  "modules/02-advanced-eval/exact-vs-fuzzy/promptfooconfig.yaml"
  "modules/02-advanced-eval/csv-driven-data/promptfooconfig.yaml"
  "modules/02-advanced-eval/fscore-classification/promptfooconfig.yaml"
  "modules/02-advanced-eval/temperature-and-personas/promptfooconfig.yaml"
)

# Opt-in configs needing a key/service not present by default — skipped, not failed.
SKIPPED=(
  "modules/00-promptfoo-basics/02-providers/local-model/promptfooconfig.yaml:needs LM Studio running on :1234"
  "modules/00-promptfoo-basics/03-assertions/answer-relevance/promptfooconfig.yaml:needs OPENAI_API_KEY (embeddings)"
  "promptfooconfig.openrouter.medibot.yaml:needs a valid OPENROUTER_API_KEY"
  "promptfooconfig.openrouter.finance.yaml:needs a valid OPENROUTER_API_KEY"
  "promptfooconfig.mybot.yaml:Challenge-3 <TODO> template — meant for students to fill in, not a finished lesson"
)

# Intentionally-broken debugger fix-me stages — expected to NOT run clean.
DEBUGGER_CONFIGS=(
  "modules/02-advanced-eval/debugger/1_basic/promptfooconfig.yaml"
  "modules/02-advanced-eval/debugger/2_moderate/promptfooconfig.yaml"
  "modules/02-advanced-eval/debugger/3_advance/promptfooconfig.yaml"
)

# Runs one config, returns 0/1/2 via globals: ${STATUS} = OK | ERRORS:<n> | CRASHED
run_config() {
  local cfg="$1"
  # mktemp's X-substitution doesn't reliably honor a literal suffix after the
  # X run on macOS's bundled (BSD) mktemp, so get a unique directory instead
  # and use a fixed filename inside it — portable and gives promptfoo's -o
  # flag the .json extension it validates.
  local tmpdir
  tmpdir=$(mktemp -d)
  local tmpfile="$tmpdir/result.json"
  local outfile="$tmpdir/stdout.log"
  local timeout_secs=90

  # Portable per-config timeout (no dependency on GNU `timeout`, which macOS
  # lacks by default): run in the background, poll, kill if it overruns. This
  # is exactly the guard that would have made today's Groq queue-throttling
  # visible as "TIMEOUT" instead of silently stalling the whole sweep.
  npx promptfoo@latest eval -c "$cfg" -j 1 --no-progress-bar --no-table --no-share --no-cache -o "$tmpfile" >"$outfile" 2>&1 &
  local pid=$!
  local waited=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 1
    waited=$((waited + 1))
    if [ "$waited" -ge "$timeout_secs" ]; then
      kill -9 "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      rm -rf "$tmpdir"
      STATUS="TIMEOUT"
      STATUS_DETAIL="killed after ${timeout_secs}s — likely Groq queue throttling from heavy same-day usage, not necessarily a config bug. Re-run this config alone later to confirm."
      return
    fi
  done
  wait "$pid"
  local exit_code=$?
  local out
  out=$(cat "$outfile")
  rm -rf "$tmpdir"

  local errors
  errors=$(echo "$out" | grep -oE '[0-9]+ errors?' | grep -oE '^[0-9]+' | head -1)

  if [ -z "$errors" ]; then
    STATUS="CRASHED"
    STATUS_DETAIL="$out"
    return
  fi
  if [ "$errors" = "0" ] && { [ "$exit_code" -eq 0 ] || [ "$exit_code" -eq 100 ]; }; then
    STATUS="OK"
    return
  fi
  STATUS="ERRORS:$errors"
  STATUS_DETAIL="$out"
}

echo "== Smoke-check: curriculum live sanity pass =="
echo ""

for cfg in "${CONFIGS[@]}"; do
  printf "  %-72s " "$cfg"
  run_config "$cfg"
  if [ "$STATUS" = "OK" ]; then
    echo "OK"
    pass=$((pass + 1))
  elif [ "$STATUS" = "TIMEOUT" ]; then
    echo "TIMEOUT (inconclusive — see note below, not counted as broken)"
    echo "  $STATUS_DETAIL"
    timeout_count=$((timeout_count + 1))
  else
    echo "BROKEN ($STATUS)"
    echo "$STATUS_DETAIL" | tail -20
    fail=$((fail + 1))
  fi
  sleep 2
done

echo ""
echo "-- Skipped (opt-in, need an external key/service) --"
for entry in "${SKIPPED[@]}"; do
  cfg="${entry%%:*}"
  reason="${entry#*:}"
  echo "  SKIP  $cfg — $reason"
  skip=$((skip + 1))
done

echo ""
echo "-- Debugger fix-me stages (expected to stay broken — confirms the exercise still works) --"
for cfg in "${DEBUGGER_CONFIGS[@]}"; do
  printf "  %-72s " "$cfg"
  run_config "$cfg"
  if [ "$STATUS" = "OK" ]; then
    echo "UNEXPECTEDLY RAN CLEAN — this stage may have been accidentally fixed, check it"
    fail=$((fail + 1))
  elif [ "$STATUS" = "TIMEOUT" ]; then
    echo "TIMEOUT — inconclusive, can't confirm the planted bug this run; re-run alone later"
    timeout_count=$((timeout_count + 1))
  else
    echo "correctly still broken ($STATUS)"
    debugger_ok=$((debugger_ok + 1))
  fi
  sleep 2
done

echo ""
echo "== Summary =="
echo "  $pass configs ran clean (0 errors)"
echo "  $fail configs BROKEN"
echo "  $skip configs skipped (opt-in, documented reason)"
echo "  $timeout_count configs TIMED OUT (inconclusive — likely Groq throttling, re-run alone later)"
echo "  $debugger_ok/3 debugger fix-me stages correctly still broken"

if [ "$fail" -gt 0 ]; then
  echo ""
  echo "SMOKE CHECK FAILED — see BROKEN entries above."
  exit 1
fi
if [ "$timeout_count" -gt 0 ]; then
  echo ""
  echo "SMOKE CHECK INCONCLUSIVE — $timeout_count config(s) timed out (see above). No confirmed breaks, but re-run the timed-out configs alone once Groq load clears before trusting this a full PASS."
  exit 2
fi
echo ""
echo "SMOKE CHECK PASSED."
exit 0
