# Student first-hour polish — Implementation Plan

> **For agentic workers:** small, tightly-coupled DX feature — executed inline.

**Goal:** Ship a `run.sh`/`run.ps1` wrapper that gives students a one-command
eval with safe pacing and a plain-English "fail = the attack landed" verdict,
and wire the visual repo map + wrapper into the onboarding docs.

**Architecture:** Two sibling wrapper scripts (mac/Linux + Windows) plus doc
edits. No change to configs/prompts/tests/assertions.

## Global Constraints

- Student-facing DX only — do not touch the model matrix, prompts, tests, or
  assertions.
- `run.sh` must be bash-3.2-safe (macOS) and pass CI `shellcheck --severity=warning`.
- Pacing defaults `-j 1 --delay 1000`, overridable via `RUN_JOBS` / `RUN_DELAY_MS`.
- Wrapper re-exits Promptfoo's own exit code.

---

### Task 1: `run.sh` (mac/Linux wrapper)

**Files:** Create `run.sh` (chmod +x).

- Color helpers + pacing defaults (`RUN_JOBS`/`RUN_DELAY_MS`).
- `usage()` lists targets; no-arg/`-h`/`--help`/`--list` → usage, exit 0.
- `view` → `exec npx promptfoo@latest view`.
- `case` maps `medibot|finance|quality.medibot|quality.finance|openrouter.medibot|openrouter.finance|mybot` → `promptfooconfig.<name>.yaml`; unknown → usage on stderr, exit 2.
- Load `.env` if present (`set -a; . ./.env; set +a`), else warn.
- Pre-run reminder; run `npx … eval -c "$cfg" -j "$JOBS" --delay "$DELAY_MS" "$@"` (`# shellcheck disable=SC2086` on passthrough); capture `ec`.
- Verdict on `ec`: 0 → held, 100 → finding, else → real error. `exit "$ec"`.

**Verify:** mock-`npx` test (below) + `shellcheck --severity=warning run.sh`.

### Task 2: `run.ps1` (Windows parity)

**Files:** Create `run.ps1`.

- `#!/usr/bin/env pwsh`; mirror `preflight.ps1` style.
- Parse `.env` lines into `$env:*` (skip comments/blank; strip quotes).
- `switch` maps target → config; unknown → usage, exit 2; `view` passthrough; no-arg/`-h` → usage.
- Run `npx --yes promptfoo@latest eval -c $cfg -j $jobs --delay $delay @rest`; branch on `$LASTEXITCODE` (0/100/else); `exit $LASTEXITCODE`.

### Task 3: Doc wiring (#3)

**Files:** Modify `README.md`, `docs/01-quickstart.md`, `setup.sh`.

- README: repo-map pointer near top; "Run the workshop eval" shows `./run.sh`
  easy path above the raw `npx` block.
- quickstart: steps 4–5 use `./run.sh medibot` / `./run.sh view`; add
  `run.sh`/`run.ps1` to the file-map table.
- setup.sh: "Next:" hint points at `./run.sh medibot`.

### Task 4: Test + commit

- Write scratch mock-`npx` test; assert mapping, the three exit-code verdicts,
  unknown-target exit 2, and exit-code passthrough.
- `shellcheck --severity=warning run.sh` clean.
- Optional: one live `./run.sh medibot --filter-first-n 1`.
- Commit; push; PR.
