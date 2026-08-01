# Rate-Limit Mitigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the maintainer sweep (`scripts/smoke-check.sh`) survive Groq's free-tier limits by caching + self-pacing, with a one-flag authoritative fresh mode — without touching anything students see.

**Architecture:** Three edits to `scripts/smoke-check.sh` (cache-on default, `--delay` pacing, `SMOKE_FRESH=1` fresh mode) plus one optional doc line in `docs/03-troubleshooting.md`. No new files, deps, or secrets.

**Tech Stack:** Bash (must run on macOS stock bash 3.2 and git-bash/WSL), promptfoo CLI, shellcheck.

## Global Constraints

- **No student-facing change.** Do not modify any `promptfooconfig*.yaml`, prompt, test set, assertion, `max_tokens`, or temperature. Every change is confined to `scripts/smoke-check.sh` and (optionally) `docs/03-troubleshooting.md`.
- **Portability:** the script runs under `set -uo pipefail` on macOS stock **bash 3.2**. No bash arrays for the optional flag (an empty array under `set -u` errors on 3.2). No GNU-only flags. Keep `shellcheck` CLEAN (0.11.0 is installed; the only permitted disable is an intentional, commented `SC2086` on the deliberately word-split flag, alongside the pre-existing `SC2329`).
- **No new Groq load in gating verification.** The must-pass checks use a mock `npx` and hit no API. A real cache-hit run is an optional, single-cheap-config confidence check to run only when Groq is calm.
- Preserve all existing `smoke-check.sh` behavior: `kill_tree` cleanup, `GAP_SECS` pause, per-config timeout, error-parse, SKIPPED/DEBUGGER handling, exit codes.

---

### Task 1: Cache-on default, `--delay` pacing, and `SMOKE_FRESH` mode in `smoke-check.sh`

**Files:**
- Modify: `scripts/smoke-check.sh` (header comment block; tunables block near `GAP_SECS`; the `npx promptfoo` eval line in `run_config`)

**Interfaces:**
- Consumes: promptfoo CLI flags `--delay <ms>` and `--no-cache` (both confirmed present in the installed promptfoo via `eval --help`).
- Produces: two new env knobs — `SMOKE_DELAY_MS` (default `1500`) and `SMOKE_FRESH` (default off). No function-signature changes.

- [ ] **Step 1: Update the header comment block to document pacing + the two modes**

Replace this block (currently lines ~16–20):

```bash
# Paced with a delay between configs (SMOKE_GAP_SECS, default 20s) to let Groq's
# free-tier per-minute budget recover; raise it if configs still time out. Each
# config is also bounded by a per-config timeout, and a timed-out eval — together
# with its node child — is killed as a whole process tree so it can't keep
# throttling the rest of the run.
```

with:

```bash
# Paced three ways to stay under Groq's free-tier limits: --delay between calls
# (SMOKE_DELAY_MS, default 1500ms), -j 1 serialization, and a pause between
# configs (SMOKE_GAP_SECS, default 20s). Each config is also bounded by a
# per-config timeout, and a timed-out eval — together with its node child — is
# killed as a whole process tree so it can't keep throttling the rest of the run.
#
# Two modes:
#   ./scripts/smoke-check.sh                default: reads/writes promptfoo's disk
#                                           cache, so a throttled re-run resumes
#                                           from cache instead of re-hammering
#                                           Groq; same-day re-runs are near-free.
#   SMOKE_FRESH=1 ./scripts/smoke-check.sh  authoritative: --no-cache forces every
#                                           call live end-to-end. Run once, when
#                                           Groq is calm (e.g. the cohort morning).
```

- [ ] **Step 2: Add the `DELAY_MS` and `CACHE_FLAG` tunables next to `GAP_SECS`**

After this block (currently lines ~35–37):

```bash
# Seconds to pause between configs so Groq's per-minute budget recovers. Raise
# it (e.g. SMOKE_GAP_SECS=45) if you still see timeouts under heavier load.
GAP_SECS="${SMOKE_GAP_SECS:-20}"
```

insert:

```bash

# Milliseconds to wait between each promptfoo call (passed as --delay). With
# -j 1 this sets a spacing floor so even a fast model stays under Groq's
# ~30 req/min. Raise it (e.g. SMOKE_DELAY_MS=2500) under heavier load.
DELAY_MS="${SMOKE_DELAY_MS:-1500}"

# Default: read/write promptfoo's disk cache so a throttled re-run resumes
# instead of re-hammering Groq. SMOKE_FRESH=1 adds --no-cache for the
# authoritative pre-cohort run that validates the live Groq path end-to-end.
CACHE_FLAG=""
[ "${SMOKE_FRESH:-0}" = "1" ] && CACHE_FLAG="--no-cache"
```

- [ ] **Step 3: Rewrite the eval invocation to add `--delay`, make caching conditional**

Replace this line (currently line ~125, inside `run_config`, immediately after the "Portable per-config timeout" comment):

```bash
  npx promptfoo@latest eval -c "$cfg" -j 1 --no-progress-bar --no-table --no-share --no-cache -o "$tmpfile" >"$outfile" 2>&1 &
```

with:

```bash
  # $CACHE_FLAG is intentionally word-split: "" -> nothing, "--no-cache" -> one
  # flag. A string var, not a bash array — an empty array under `set -u` errors
  # on macOS's stock bash 3.2, which this script must run on. The value has no
  # spaces/globs, so the split is safe and deliberate.
  # shellcheck disable=SC2086
  npx promptfoo@latest eval -c "$cfg" -j 1 --delay "$DELAY_MS" --no-progress-bar --no-table --no-share $CACHE_FLAG -o "$tmpfile" >"$outfile" 2>&1 &
```

- [ ] **Step 4: Syntax + lint gate**

Run:
```bash
bash -n scripts/smoke-check.sh
shellcheck scripts/smoke-check.sh
```
Expected: `bash -n` silent (exit 0); `shellcheck` clean (exit 0). If shellcheck flags `SC2086` anywhere other than the one commented line, fix it — do not add blanket disables.

- [ ] **Step 5: Flag-construction test with a mock `npx` (no Groq calls)**

This proves the constructed command line is correct in both modes without touching the API. The mock records its args to a log and returns a fake clean summary so the sweep proceeds fast.

```bash
MOCKBIN="$(mktemp -d)"
ARGLOG="$(mktemp)"
cat > "$MOCKBIN/npx" <<EOF
#!/usr/bin/env bash
echo "ARGS: \$*" >> "$ARGLOG"
echo "0 errors"    # so run_config's parse sees a clean summary
EOF
chmod +x "$MOCKBIN/npx"

# Default mode: expect --delay present, --no-cache ABSENT
: > "$ARGLOG"
PATH="$MOCKBIN:$PATH" SMOKE_GAP_SECS=0 bash scripts/smoke-check.sh >/dev/null 2>&1 || true
echo "default: delay=$(grep -c -- '--delay 1500' "$ARGLOG") nocache=$(grep -c -- '--no-cache' "$ARGLOG")"

# Fresh mode: expect --delay present AND --no-cache present on every eval
: > "$ARGLOG"
PATH="$MOCKBIN:$PATH" SMOKE_GAP_SECS=0 SMOKE_FRESH=1 bash scripts/smoke-check.sh >/dev/null 2>&1 || true
echo "fresh:   delay=$(grep -c -- '--delay 1500' "$ARGLOG") nocache=$(grep -c -- '--no-cache' "$ARGLOG")"
rm -rf "$MOCKBIN" "$ARGLOG"
```
Expected: `default:` line shows a positive `delay=` count and `nocache=0`. `fresh:` line shows the same positive `delay=` count and an equal positive `nocache=` count (one `--no-cache` per eval). (The script's own exit code is ignored — the mock makes debugger stages look "unexpectedly clean"; we assert only on the arg log.)

- [ ] **Step 6: Commit**

```bash
git add scripts/smoke-check.sh
git commit -m "feat(smoke-check): cache-on + --delay pacing by default; SMOKE_FRESH=1 for authoritative live run"
```

- [ ] **Step 7 (optional confidence check — run only when Groq is calm): real cache-hit resumability**

Not required to pass the task; skip if Groq is throttled. Confirms real cache behavior on the single cheapest config (1 model, tiny test set):

```bash
set -a; . ./.env; set +a
CFG=modules/00-promptfoo-basics/01-prompts/text/promptfooconfig.yaml
time npx promptfoo@latest eval -c "$CFG" -j 1 --delay 1500 --no-progress-bar --no-table --no-share >/dev/null 2>&1   # run 1 (populates cache)
time npx promptfoo@latest eval -c "$CFG" -j 1 --delay 1500 --no-progress-bar --no-table --no-share 2>&1 | grep -iE 'cache|token' | head   # run 2: expect cache hits, near-instant
```
Expected: run 2 is dramatically faster and/or reports cached results — demonstrating a throttled re-run would resume for free.

---

### Task 2 (optional/secondary): Doc note offering `--delay` as an anti-throttle knob

**Files:**
- Modify: `docs/03-troubleshooting.md` (the "Groq eval hangs or times out (free-tier rate limit)" section)

**Interfaces:**
- Consumes: nothing. Pure documentation. This is the only student-doc-facing change and may be dropped without affecting Task 1.

- [ ] **Step 1: Add the `--delay` alternative after the existing `-j` code block**

In the "Groq eval hangs or times out (free-tier rate limit)" section, immediately after this code block:

```bash
npx promptfoo@latest eval -c promptfooconfig.medibot.yaml -j 2   # or -j 1 for one call at a time
```

insert:

````markdown
Or space the calls out — with or without lowering concurrency — with `--delay` (milliseconds between calls):
```bash
npx promptfoo@latest eval -c promptfooconfig.medibot.yaml -j 1 --delay 1000
```
````

- [ ] **Step 2: Verify the rendered section**

Run:
```bash
sed -n '/Groq eval hangs or times out/,/^### /p' docs/03-troubleshooting.md
```
Expected: the new `--delay` sentence and code block appear once, correctly fenced, inside that section only. No other section changed.

- [ ] **Step 3: Commit**

```bash
git add docs/03-troubleshooting.md
git commit -m "docs(troubleshooting): offer --delay as an anti-throttle knob alongside -j"
```

## Self-Review

- **Spec coverage:** Change 1 (cache-on default) → Task 1 Steps 2–3. Change 2 (`--delay` + `-j 1`) → Task 1 Steps 2–3. Change 3 (`SMOKE_FRESH`) → Task 1 Step 2. Change 4 (optional doc note) → Task 2. Header/mode documentation → Task 1 Step 1. All spec changes are covered.
- **Placeholder scan:** none — every step has exact before/after text and runnable commands.
- **Type/name consistency:** env vars `SMOKE_DELAY_MS`/`DELAY_MS` and `SMOKE_FRESH`/`CACHE_FLAG` are used identically in the tunables block (Step 2) and the eval line (Step 3). `--delay 1500` in the flag-construction test (Step 5) matches the `1500` default in Step 2.
- **Portability:** the `set -u` bash-3.2 empty-array trap is avoided by using a string var + commented `SC2086` disable (Global Constraints + Task 1 Step 3).
