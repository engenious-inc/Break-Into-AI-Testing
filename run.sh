#!/usr/bin/env bash
# One-command workshop eval runner.
#
# Maps a short target name to its Promptfoo config, bakes in free-tier-safe
# pacing (-j 1 --delay 1000 by default, so a whole room stays under Groq's
# ~30 req/min limit), and — because these are RED-TEAM suites where a *failing*
# assertion means the attack landed — translates Promptfoo's exit code into a
# plain-English verdict. Extra args after the target pass straight through.
#
#   ./run.sh medibot                     # MediBot red-team suite
#   ./run.sh finance --filter-first-n 1  # extra args pass through to promptfoo
#   ./run.sh view                        # open the results web UI
#   ./run.sh --list                      # show all targets
set -uo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# Pacing defaults keep a full room under Groq's ~30 req/min free-tier limit.
JOBS="${RUN_JOBS:-1}"
DELAY_MS="${RUN_DELAY_MS:-1000}"

usage() {
  cat <<'EOF'
Usage: ./run.sh <target> [extra promptfoo args…]

Targets:
  medibot             MediBot red-team suite (free-tier-safe)
  finance             FinanceBot red-team suite
  quality.medibot     MediBot quality challenges (bias / consistency / compliance)
  quality.finance     FinanceBot quality challenges (context / values)
  openrouter.medibot  MediBot via the OpenRouter fallback (needs OPENROUTER_API_KEY)
  openrouter.finance  FinanceBot via the OpenRouter fallback
  mybot               Your Challenge-3 build-it bot
  view                Open the results web UI

Examples:
  ./run.sh medibot
  ./run.sh finance --filter-first-n 1
  ./run.sh view

Pacing defaults to -j 1 --delay 1000 (override with RUN_JOBS / RUN_DELAY_MS).
EOF
}

target="${1:-}"
case "$target" in
  ""|-h|--help|--list) usage; exit 0 ;;
esac
shift

# `view` opens the report UI — no eval, no verdict.
if [ "$target" = "view" ]; then
  exec npx --yes promptfoo@latest view "$@"
fi

case "$target" in
  medibot|finance|quality.medibot|quality.finance|openrouter.medibot|openrouter.finance|mybot)
    cfg="promptfooconfig.${target}.yaml" ;;
  *)
    printf "${RED}✗${NC} Unknown target: %s\n\n" "$target" >&2
    usage >&2
    exit 2 ;;
esac

if [ ! -f "$cfg" ]; then
  printf "${RED}✗${NC} Config not found: %s — are you in the repo root?\n" "$cfg" >&2
  exit 2
fi

# Load .env so GROQ_API_KEY / OPENROUTER_API_KEY reach Promptfoo.
if [ -f .env ]; then
  set -a; . ./.env; set +a
else
  printf "${YELLOW}!${NC} No .env found — run ./setup.sh first (or export GROQ_API_KEY).\n" >&2
fi

printf "${BLUE}▶${NC} Running ${BLUE}%s${NC}  ${YELLOW}(-j %s --delay %sms)${NC}\n" "$target" "$JOBS" "$DELAY_MS"
printf "  Reminder: these are red-team suites — a ${YELLOW}failing${NC} check means the model did the thing you were testing for. That's the finding, not an error.\n\n"

ec=0
# shellcheck disable=SC2086
npx --yes promptfoo@latest eval -c "$cfg" -j "$JOBS" --delay "$DELAY_MS" "$@" || ec=$?

echo
case "$ec" in
  0)
    printf "${GREEN}🛡  Exit 0 — every guardrail held on this run.${NC}\n"
    printf "  Nothing landed. Try a tougher attack, a different model, or add your own case under tests/.\n" ;;
  100)
    printf "${GREEN}✓ Exit 100 — one or more checks failed. That's the finding.${NC}\n"
    printf "  See which model broke on which case:  ${BLUE}./run.sh view${NC}\n" ;;
  *)
    printf "${RED}✗ Exit %s — that's an actual error, not a finding.${NC}\n" "$ec"
    printf "  Usually a key / network / throttle issue — see docs/03-troubleshooting.md.\n" ;;
esac
exit "$ec"
