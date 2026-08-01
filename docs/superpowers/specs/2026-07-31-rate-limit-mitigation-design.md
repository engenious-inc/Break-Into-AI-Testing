# Rate-Limit Mitigation for the Maintainer Sweep — Design

**Date:** 2026-07-31
**Status:** Approved for planning
**Scope owner:** workshop maintainers (instructors preparing a cohort)

## Problem

The workshop already has a solid rate-limit story for the path that matters
to students — one person running one config against their own free Groq key:
free-tier-safe defaults (curated 4–6 case subsets, `max_tokens` caps), `-j`
guidance, an OpenRouter shared fallback, an LM Studio local path, and
promptfoo's disk cache on by default for the student `eval` command.

The residual pain is concentrated in one place: **`scripts/smoke-check.sh`**,
the maintainer pre-cohort sweep. It runs ~22 configs back-to-back on a single
key, and today it passes `--no-cache` on every eval. Two consequences:

1. **No resumability.** A mid-sweep throttle forces a full fresh re-run, which
   re-hammers Groq and cascades into deeper throttling (the observed
   death-spiral during verification).
2. **Per-day quota burn.** Every sweep is a full-price live run against the
   ~14,400 req/day quota, so iterating during authoring exhausts the budget.

There is also a per-minute pressure: with fast models a serialized run can
still burst past Groq's ~30 req/min inside a single config.

## Constraint (non-negotiable)

**No change may alter what students see or learn.** The model matrix, test
cases, assertions, prompts, `max_tokens`, and temperatures in every
student-facing config stay byte-for-byte identical. All changes are confined
to maintainer tooling (`scripts/smoke-check.sh`) plus one optional
documentation note. Coverage of the curriculum is unaffected.

## Approach

Attack **consumption** and **pacing**, never the matrix. Three changes to
`smoke-check.sh`, plus one small doc note.

### Change 1 — Cache-on by default (resumability)

Remove `--no-cache` from the default eval invocation in `smoke-check.sh`.
promptfoo's disk cache is keyed on the exact `(prompt, provider, params)`
tuple, so a cache hit still exercises everything a smoke-check verifies: the
config loads, the `file://` refs resolve, and the assertions compile and run.
After a throttle you re-run; already-passed configs return as free cache hits
and the sweep converges instead of cascading. Same-day re-runs during
authoring cost ~0 new Groq calls for unchanged configs.

### Change 2 — Self-pace with `--delay` (per-minute safety)

Add `--delay "${SMOKE_DELAY_MS:-1500}"` to every eval invocation and keep the
existing `-j 1`. `-j 1` serializes calls; `--delay` guarantees a minimum
spacing floor so even a fast 8B model cannot burst past ~30 req/min. At the
1500 ms default, effective throughput is ~17–24 calls/min (delay + call
latency), comfortably under the limit. `SMOKE_DELAY_MS` lets a maintainer
raise it under heavier load. This replaces "add `-j 2` if it throttles" with a
run that does not throttle by construction. Results are identical — the calls
are merely spaced.

### Change 3 — `SMOKE_FRESH=1` authoritative mode

When `SMOKE_FRESH=1` is set, add `--no-cache` back so the eval neither reads
nor writes cache — a true live end-to-end validation of the Groq path, run
once when Groq is calm (e.g. the morning of the cohort). Because Changes 1 and
2 still apply (delay + `-j 1`), even this fresh run is paced and will not
cascade. Without the flag, the sweep uses the cheap cached/resumable default.

One flag, two modes:
- **default** — cached, resumable, paced. The everyday "did I break a config"
  run. Safe to run repeatedly.
- **`SMOKE_FRESH=1`** — fresh, paced. The once-per-cohort authoritative check.

### Change 4 (optional, secondary) — Doc note on `--delay`

In `docs/03-troubleshooting.md` ("Groq eval hangs or times out"), add one line
presenting `--delay 1000` as a robustness knob alongside `-j`, e.g.:

> Or space the calls out instead of (or with) lowering concurrency:
> `npx promptfoo@latest eval -c promptfooconfig.medibot.yaml -j 1 --delay 1000`

Non-breaking and optional; no student command changes. This is the only
student-doc-facing change and may be dropped without affecting Changes 1–3.

## What changes in `scripts/smoke-check.sh`

The eval line today (in both the `CONFIGS` and `DEBUGGER_CONFIGS` loops via
`run_config`) is:

```bash
npx promptfoo@latest eval -c "$cfg" -j 1 --no-progress-bar --no-table --no-share --no-cache -o "$tmpfile" >"$outfile" 2>&1 &
```

It becomes a constructed argument list so the cache flag is conditional:

```bash
# Near the top, with the other tunables:
DELAY_MS="${SMOKE_DELAY_MS:-1500}"
# Default: cached + resumable. SMOKE_FRESH=1: fresh live validation.
CACHE_FLAG=""
[ "${SMOKE_FRESH:-0}" = "1" ] && CACHE_FLAG="--no-cache"

# In run_config — $CACHE_FLAG is intentionally word-split (empty string ->
# nothing, "--no-cache" -> one flag). A string var, not a bash array: an empty
# array under `set -u` is an "unbound variable" error on macOS's stock bash
# 3.2, which this script must run on. The value has no spaces/globs, so
# word-splitting is safe and deliberate.
# shellcheck disable=SC2086
npx promptfoo@latest eval -c "$cfg" -j 1 --delay "$DELAY_MS" \
  --no-progress-bar --no-table --no-share $CACHE_FLAG -o "$tmpfile" >"$outfile" 2>&1 &
```

Everything else in `smoke-check.sh` is unchanged: the `kill_tree` cleanup, the
`GAP_SECS` between-config pause (default 20), the per-config timeout, the
error-parse logic, the SKIPPED/DEBUGGER handling, and the exit codes.

The header comment block is updated to document the two modes and the
`SMOKE_DELAY_MS` / `SMOKE_FRESH` env vars.

## Data flow

- **Everyday sweep** (`./scripts/smoke-check.sh`): each config runs `-j 1`
  with a 1.5 s inter-call delay; responses read/write the disk cache. First
  run of the day populates cache; re-runs are near-instant cache hits for
  unchanged configs. A throttle is survivable — re-run and resume.
- **Authoritative sweep** (`SMOKE_FRESH=1 ./scripts/smoke-check.sh`): identical
  pacing, but `--no-cache` forces every call live. Run once when Groq is calm.

## Error handling

- **Throttle mid-sweep (default mode):** already-completed configs are cache
  hits on re-run, so the sweep resumes rather than re-hammering. The existing
  per-config `TIMEOUT` branch and `kill_tree` still bound any stuck eval.
- **`SMOKE_FRESH=1` with an exhausted daily quota:** the fresh run will report
  errors/timeouts exactly as today; the operator reads the existing
  inconclusive-exit guidance and retries when the quota resets. No new failure
  mode is introduced.
- **`SMOKE_DELAY_MS` set to a non-numeric value:** promptfoo validates
  `--delay`; an invalid value surfaces as a promptfoo error on the first
  config, caught by the existing CRASHED/ERRORS parse. Not defended against
  further — it is maintainer-set.

## Rejected alternatives

- **Single-model sweep via `--filter-providers`** — evidence killed it: 19 of
  22 configs already run a single model, so filtering only touches 3 configs
  (~20% fewer calls). On the cached everyday run that saving is ~zero (hits are
  already free); on the authoritative fresh run you *want* the full matrix on
  the flagship configs. It also risks a false "clean" when a regex matches zero
  providers in a config. Cache + delay make it pointless.
- **Multi-key rotation / parallel-provider budgets** — raises the ceiling but
  introduces secrets management and an infosec surface. Unnecessary once
  consumption drops; the kind of complexity not worth its maintenance cost.
- **Shrinking the student matrix, trimming cases, or lowering `max_tokens`** —
  directly violates the coverage constraint; lower token caps can even flip
  which attacks land. Off the table.
- **Changing `setup.sh`'s 1-test smoke check to cached** — that check exists to
  prove the *live* key works during setup; it must stay `--no-cache`.
  Unchanged.

## Testing / verification (low-API)

1. `bash -n scripts/smoke-check.sh` — syntax.
2. `shellcheck scripts/smoke-check.sh` — clean (or only pre-existing
   suppressions).
3. **Flag construction** — with `SMOKE_FRESH` unset the constructed eval args
   contain `--delay` and omit `--no-cache`; with `SMOKE_FRESH=1` they contain
   `--no-cache`. Verified by echoing the arg list, not by hitting Groq.
4. **Resumability (one config, cheap)** — run one config in default mode:
   first run populates cache; a second immediate run is a cache hit
   (near-instant, ~0 new Groq calls), proving resume behavior.
5. `--delay` acceptance already confirmed against the installed promptfoo
   (`eval --help`).

## Out of scope

- No changes to any student-facing config, prompt, test set, or assertion.
- No changes to `preflight.sh` / `preflight.ps1`, `setup.sh` / `setup.ps1`
  (beyond leaving the setup smoke check fresh), or the OpenRouter/local
  fallback configs.
- No new dependencies, no new secrets, no new files (other than this spec and
  its plan).
