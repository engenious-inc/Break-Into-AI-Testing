#!/usr/bin/env bash
# Every promptfooconfig in the repo must be reachable from exactly one day page in days/.
#
# Without this the day index is a hand-maintained list that silently rots, which is the
# problem it was created to solve. `modules/02-advanced-eval/observability/` sitting in a
# Day 4 folder while being Day 8 material went unnoticed for weeks because nothing
# compared the two.
#
# A config is "claimed" by a day page if that page mentions either the config path or the
# directory containing it. Root configs are matched on their ./run.sh target name too,
# since that is how the pages tell students to run them.
#
# Exit 1 if anything is unclaimed or claimed twice.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

DAYS_DIR="days"
if [ ! -d "$DAYS_DIR" ]; then
  echo "No $DAYS_DIR/ directory — nothing to check." >&2
  exit 1
fi

# Configs students are never pointed at from a day page, with the reason.
declare -a EXEMPT=(
  ".claude/skills/new-eval-suite/templates/promptfooconfig.template.yaml:a scaffold the skill copies from, not a suite"
)

unclaimed=0
duplicated=0
checked=0

is_exempt() {
  local cfg="$1" entry
  for entry in "${EXEMPT[@]}"; do
    [ "${entry%%:*}" = "$cfg" ] && return 0
  done
  return 1
}

echo "== Day index coverage =="

while IFS= read -r cfg; do
  cfg="${cfg#./}"
  is_exempt "$cfg" && continue
  checked=$((checked + 1))

  dir=$(dirname "$cfg")
  base=$(basename "$cfg")
  # promptfooconfig.payflow-redteam.yaml -> payflow-redteam (its ./run.sh target)
  target="${base#promptfooconfig.}"
  target="${target%.yaml}"

  hits=""
  for page in "$DAYS_DIR"/*.md; do
    [ "$(basename "$page")" = "README.md" ] && continue
    claimed=1
    if grep -qF -- "$cfg" "$page" 2>/dev/null; then
      claimed=0
    elif [ "$dir" = "." ]; then
      grep -qE "run\.sh $target( |\`|$)" "$page" 2>/dev/null && claimed=0
    else
      # Match the lesson directory, or one level above it. The debugger keeps its three
      # stages in subdirectories and listing all three on the page would be noise, so
      # `debugger/` claims them.
      #
      # The walk stops at THREE path components (modules/<module>/<lesson>). Anything
      # shorter is too generic to be a claim: every page links `../modules/...`
      # somewhere, so allowing a bare `modules` match makes every day claim every
      # config — which is exactly what happened the first time this was written.
      probe="$dir"
      for _ in 1 2; do
        depth=$(echo "$probe" | awk -F/ '{print NF}')
        [ "$depth" -lt 3 ] && break
        if grep -qF -- "$probe" "$page" 2>/dev/null; then claimed=0; break; fi
        probe=$(dirname "$probe")
      done
    fi
    [ "$claimed" -eq 0 ] && hits="$hits $(basename "$page" .md)"
  done

  count=$(echo "$hits" | wc -w | tr -d ' ')
  if [ "$count" -eq 0 ]; then
    echo "  UNCLAIMED   $cfg"
    unclaimed=$((unclaimed + 1))
  elif [ "$count" -gt 1 ]; then
    echo "  DUPLICATED  $cfg ->$hits"
    duplicated=$((duplicated + 1))
  fi
done < <(find . -name 'promptfooconfig*.yaml' -not -path './node_modules/*' | sort)

echo ""
echo "  $checked configs checked"
echo "  $unclaimed unclaimed (listed under no day)"
echo "  $duplicated duplicated (listed under more than one)"

if [ "$unclaimed" -gt 0 ] || [ "$duplicated" -gt 0 ]; then
  echo ""
  echo "DAY INDEX CHECK FAILED."
  echo "Add each unclaimed config to the right page in $DAYS_DIR/, or to EXEMPT in this"
  echo "script with a reason. A duplicated config means two days claim it — pick one."
  exit 1
fi

echo ""
echo "DAY INDEX CHECK PASSED."
exit 0
