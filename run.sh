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
  medibot-multiturn   MediBot across a multi-turn conversation
  finance             FinanceBot red-team suite
  reverse             Magical Story Creator — reverse-engineered prompt hypothesis
  quality.medibot     MediBot quality challenges (bias / consistency / compliance)
  quality.finance     FinanceBot quality challenges (context / values)
  openrouter.medibot  MediBot via the OpenRouter fallback (needs OPENROUTER_API_KEY)
  openrouter.finance  FinanceBot via the OpenRouter fallback
  mybot               Your Challenge-3 build-it bot
  payflow             PayFlow app suite — guard, routing, citations (server must be up)
  payflow-api         PayFlow HTTP contract + two planted defects (those two fail on purpose)
  payflow-multiturn   PayFlow injection after 4 turns of legitimate context
  payflow-redteam     PayFlow generated red team (promptfoo redteam run — slow)
  payflow-serve       Start the PayFlow demo app on :8000 (foreground)
  payflow-health      Check the PayFlow app is answering before you eval
  financebot          FinanceBot app suite — guard, routing, citations (server must be up)
  financebot-api      FinanceBot HTTP contract + three planted defects (those three fail on purpose)
  financebot-multiturn  FinanceBot injection after cooperative context
  financebot-redteam  FinanceBot generated red team (writes redteam.financebot.yaml)
  financebot-serve    Start the FinanceBot demo app on :8001 (foreground)
  financebot-health   Check the FinanceBot app is answering before you eval
  chat <bot>          Talk to a bot directly (onboardbot, medibot, financebot, mybot)
  view                Open the results web UI

Examples:
  ./run.sh medibot
  ./run.sh finance --filter-first-n 1
  ./run.sh chat onboardbot    # Day 6 — explore a bot instead of evaluating it
  ./run.sh payflow-serve      # in one terminal
  ./run.sh payflow            # in another
  ./run.sh payflow-api
  ./run.sh payflow-multiturn
  ./run.sh payflow-redteam
  ./run.sh financebot-serve   # in one terminal (:8001)
  ./run.sh financebot         # in another
  ./run.sh financebot-api
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

# `chat` is an interactive session, not an eval. Day 6 uses it for black-box work.
if [ "$target" = "chat" ]; then
  [ -f .env ] && { set -a; . ./.env; set +a; }
  exec node scripts/chat.mjs "$@"
fi

PAYFLOW_URL="http://localhost:${PAYFLOW_PORT:-8000}"
FINANCEBOT_URL="http://localhost:${FINANCEBOT_PORT:-8001}"

# The PayFlow / FinanceBot apps are servers, not configs. These targets run them
# rather than eval them.
if [ "$target" = "payflow-serve" ]; then
  [ -f .env ] && { set -a; . ./.env; set +a; }
  exec node modules/03-app-testing/payflow/server.js "$@"
fi

if [ "$target" = "financebot-serve" ]; then
  [ -f .env ] && { set -a; . ./.env; set +a; }
  exec node modules/03-app-testing/financebot/server.js "$@"
fi

if [ "$target" = "payflow-health" ]; then
  if node -e "fetch('${PAYFLOW_URL}/health').then(r=>r.json()).then(j=>{console.log(JSON.stringify(j));process.exit(j.status==='ok'?0:1)}).catch(()=>process.exit(1))" 2>/dev/null; then
    printf "${GREEN}✓${NC} PayFlow app is up at %s\n" "$PAYFLOW_URL"
    exit 0
  fi
  printf "${RED}✗${NC} PayFlow app is not answering at %s — start it with ${BLUE}./run.sh payflow-serve${NC}\n" "$PAYFLOW_URL" >&2
  exit 1
fi

if [ "$target" = "financebot-health" ]; then
  if node -e "fetch('${FINANCEBOT_URL}/health').then(r=>r.json()).then(j=>{console.log(JSON.stringify(j));process.exit(j.status==='ok'?0:1)}).catch(()=>process.exit(1))" 2>/dev/null; then
    printf "${GREEN}✓${NC} FinanceBot app is up at %s\n" "$FINANCEBOT_URL"
    exit 0
  fi
  printf "${RED}✗${NC} FinanceBot app is not answering at %s — start it with ${BLUE}./run.sh financebot-serve${NC}\n" "$FINANCEBOT_URL" >&2
  exit 1
fi

# `redteam run` generates attacks before it evaluates them, so it is its own subcommand
# rather than an `eval -c`.
if [ "$target" = "payflow-redteam" ]; then
  [ -f .env ] && { set -a; . ./.env; set +a; }
  if ! node -e "fetch('${PAYFLOW_URL}/health').then(()=>process.exit(0)).catch(()=>process.exit(1))" 2>/dev/null; then
    printf "${RED}✗${NC} PayFlow app is not answering at %s.\n" "$PAYFLOW_URL" >&2
    printf "  Start it in another terminal first:  ${BLUE}./run.sh payflow-serve${NC}\n" >&2
    exit 2
  fi
  printf "${BLUE}▶${NC} Generating and running the PayFlow red team.  ${YELLOW}(-j %s --delay %sms)${NC}\n" "$JOBS" "$DELAY_MS"
  printf "  Every probe runs the full pipeline — three Groq calls each. Expect this to take a while.\n"
  printf "  Reminder: a ${YELLOW}failing${NC} check means the attack landed. That's the finding.\n\n"
  ec=0
  # OPENAI_API_KEY is unset for this run on purpose. Nothing here uses OpenAI — but
  # promptfoo treats the key's mere presence as "generate attacks locally" and switches
  # off its own remote generator, which several strategies require. The whole scan then
  # dies with "requires remote generation". The key is optional in this repo (only the
  # paid comparison block in promptfooconfig.medibot.yaml reads it), so dropping it here
  # costs nothing and keeps every strategy available.
  #
  # -j / --delay are passed explicitly. redteam.maxConcurrency in the YAML is a hint
  # promptfoo has been seen to ignore (redteam run defaulted to 4), and four concurrent
  # probes each make three Groq calls — that blows Groq's free-tier TPM and the scan
  # dies in 300s queue timeouts. Same defaults as every other target; override with
  # RUN_JOBS / RUN_DELAY_MS on a paid key.
  env -u OPENAI_API_KEY npx --yes promptfoo@latest redteam run -c promptfooconfig.payflow-redteam.yaml -j "$JOBS" --delay "$DELAY_MS" "$@" || ec=$?
  echo
  case "$ec" in
    0)   printf "${GREEN}🛡  Exit 0 — nothing landed on this run.${NC}\n" ;;
    100) printf "${YELLOW}⚠  Exit 100 — at least one attack landed. Triage it: ${BLUE}./run.sh view${NC}\n" ;;
    *)   printf "${RED}✗ Exit %s — an actual error.${NC}\n" "$ec" ;;
  esac
  exit "$ec"
fi

if [ "$target" = "financebot-redteam" ]; then
  [ -f .env ] && { set -a; . ./.env; set +a; }
  if ! node -e "fetch('${FINANCEBOT_URL}/health').then(()=>process.exit(0)).catch(()=>process.exit(1))" 2>/dev/null; then
    printf "${RED}✗${NC} FinanceBot app is not answering at %s.\n" "$FINANCEBOT_URL" >&2
    printf "  Start it in another terminal first:  ${BLUE}./run.sh financebot-serve${NC}\n" >&2
    exit 2
  fi
  printf "${BLUE}▶${NC} Generating and running the FinanceBot red team.  ${YELLOW}(-j %s --delay %sms)${NC}\n" "$JOBS" "$DELAY_MS"
  printf "  Writes ${BLUE}redteam.financebot.yaml${NC} (does not touch PayFlow's redteam.yaml).\n"
  printf "  Reminder: a ${YELLOW}failing${NC} check means the attack landed. That's the finding.\n\n"
  ec=0
  env -u OPENAI_API_KEY npx --yes promptfoo@latest redteam run -c promptfooconfig.financebot-redteam.yaml -o redteam.financebot.yaml -j "$JOBS" --delay "$DELAY_MS" "$@" || ec=$?
  echo
  case "$ec" in
    0)   printf "${GREEN}🛡  Exit 0 — nothing landed on this run.${NC}\n" ;;
    100) printf "${YELLOW}⚠  Exit 100 — at least one attack landed. Triage it: ${BLUE}./run.sh view${NC}\n" ;;
    *)   printf "${RED}✗ Exit %s — an actual error.${NC}\n" "$ec" ;;
  esac
  exit "$ec"
fi

case "$target" in
  medibot|medibot-multiturn|finance|reverse|quality.medibot|quality.finance|openrouter.medibot|openrouter.finance|mybot|payflow|payflow-api|payflow-multiturn|financebot|financebot-api|financebot-multiturn)
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

# Ordinary suites (pass = good): PayFlow / FinanceBot app evals and Challenge-3 mybot.
# Everything else here is inverted (fail = finding). Saying the wrong one teaches
# the opposite of the lesson, so the two verdicts are kept apart.
ordinary=0
if [ "$target" = "payflow" ] || [ "$target" = "payflow-api" ] || [ "$target" = "payflow-multiturn" ] || [ "$target" = "financebot" ] || [ "$target" = "financebot-api" ] || [ "$target" = "financebot-multiturn" ] || [ "$target" = "mybot" ]; then
  ordinary=1
fi

if [ "$ordinary" = 1 ]; then
  if [ "$target" = "payflow" ] || [ "$target" = "payflow-api" ] || [ "$target" = "payflow-multiturn" ]; then
    if ! node -e "fetch('${PAYFLOW_URL}/health').then(()=>process.exit(0)).catch(()=>process.exit(1))" 2>/dev/null; then
      printf "${RED}✗${NC} PayFlow app is not answering at %s.\n" "$PAYFLOW_URL" >&2
      printf "  Start it in another terminal first:  ${BLUE}./run.sh payflow-serve${NC}\n" >&2
      printf "  Without it every case fails with a connection error that looks like a bug in your tests.\n" >&2
      exit 2
    fi
    printf "  Testing the ${BLUE}application${NC}, not a model — assertions read output.route and output.citations.\n\n"
  elif [ "$target" = "financebot" ] || [ "$target" = "financebot-api" ] || [ "$target" = "financebot-multiturn" ]; then
    if ! node -e "fetch('${FINANCEBOT_URL}/health').then(()=>process.exit(0)).catch(()=>process.exit(1))" 2>/dev/null; then
      printf "${RED}✗${NC} FinanceBot app is not answering at %s.\n" "$FINANCEBOT_URL" >&2
      printf "  Start it in another terminal first:  ${BLUE}./run.sh financebot-serve${NC}\n" >&2
      printf "  Without it every case fails with a connection error that looks like a bug in your tests.\n" >&2
      exit 2
    fi
    printf "  Testing the ${BLUE}application${NC}, not a model — assertions read output.route and output.citations.\n\n"
  else
    printf "  Ordinary suite — a ${YELLOW}failing${NC} check is a defect in your bot, not a finding.\n\n"
  fi
else
  printf "  Reminder: these are red-team suites — a ${YELLOW}failing${NC} check means the model did the thing you were testing for. That's the finding, not an error.\n\n"
fi

ec=0
# shellcheck disable=SC2086
npx --yes promptfoo@latest eval -c "$cfg" -j "$JOBS" --delay "$DELAY_MS" "$@" || ec=$?

echo
if [ "$ordinary" = 1 ]; then
  case "$ec" in
    0)   printf "${GREEN}✓ Exit 0 — every case passed.${NC}\n"
         if [ "$target" = "mybot" ]; then
           printf "  Guardrails held where they should; benign and gray-area cases behaved.\n"
         else
           printf "  Guard fired where it should, routing picked the right specialist, citations lined up.\n"
         fi ;;
    100) printf "${YELLOW}✗ Exit 100 — one or more checks failed. Here that IS a defect.${NC}\n"
         printf "  Look at which assertion broke:  ${BLUE}./run.sh view${NC}\n" ;;
    *)   printf "${RED}✗ Exit %s — an actual error.${NC}\n" "$ec"
         if [ "$target" = "payflow" ] || [ "$target" = "payflow-api" ] || [ "$target" = "payflow-multiturn" ]; then
           printf "  Is the app still up?  ${BLUE}./run.sh payflow-health${NC}\n"
         elif [ "$target" = "financebot" ] || [ "$target" = "financebot-api" ] || [ "$target" = "financebot-multiturn" ]; then
           printf "  Is the app still up?  ${BLUE}./run.sh financebot-health${NC}\n"
         else
           printf "  Usually a key / network / throttle issue — see docs/03-troubleshooting.md.\n"
         fi ;;
  esac
  exit "$ec"
fi

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
