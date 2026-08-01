# Student first-hour polish: run wrapper + result verdict + orientation

**Date:** 2026-08-01
**Status:** Design
**Repo:** `breaking-gpt-claude-workshop`

## Overview

Coverage and rate-limiting are solid. The remaining friction is in a student's
first 30 minutes: long `npx` commands that are easy to get wrong (and that
self-throttle a whole room when the pacing flags are forgotten), and the
inverted red-team semantics (a *failing* assertion means the attack landed;
exit `100` is healthy) that lives in prose students have already skipped.

This bundles three additive, student-facing changes. **No change to any model
matrix, prompt, test, or assertion** — purely developer-experience.

1. **A one-command run wrapper** (`run.sh` / `run.ps1`) that maps a short target
   name to its config, bakes in free-tier-safe pacing, and passes extra args
   through to Promptfoo.
2. **A plain-English result verdict** printed by that wrapper — the wrapper reads
   Promptfoo's exit code and says what it means in this workshop's inverted
   terms, so "fail = the attack landed" is delivered exactly where the confusion
   happens: at the output.
3. **Orientation wiring** — link the visual `docs/repo-map.pdf` from the README,
   and point the README/quickstart/`setup.sh` "next steps" at the wrapper.

## Why one artifact for #1 + #2

The verdict (#2) must post-process Promptfoo's exit code — a `package.json`
one-liner cannot. A wrapper is therefore the right vehicle and delivers both #1
and #2 at once. Shipping `run.sh` + `run.ps1` matches the repo's existing
`setup.sh`/`setup.ps1` and `preflight.sh`/`preflight.ps1` cross-platform pairing.

## `run.sh` / `run.ps1` behavior

**Targets** (short name → root config; all are inverted-semantics suites):

| Target | Config |
|---|---|
| `medibot` | `promptfooconfig.medibot.yaml` |
| `finance` | `promptfooconfig.finance.yaml` |
| `quality.medibot` | `promptfooconfig.quality.medibot.yaml` |
| `quality.finance` | `promptfooconfig.quality.finance.yaml` |
| `openrouter.medibot` | `promptfooconfig.openrouter.medibot.yaml` |
| `openrouter.finance` | `promptfooconfig.openrouter.finance.yaml` |
| `mybot` | `promptfooconfig.mybot.yaml` |
| `view` | passthrough to `promptfoo view` |

- **No arg / `-h` / `--help` / `--list`** → usage listing the targets, exit 0.
- **Unknown target** → error + usage on stderr, exit 2.
- **Pacing defaults:** `-j 1 --delay 1000` (overridable via `RUN_JOBS` /
  `RUN_DELAY_MS`). This keeps a whole room under Groq's ~30 req/min free-tier
  limit — the single biggest avoidable support ticket.
- **Extra args pass through:** `./run.sh medibot --filter-first-n 1` appends
  `--filter-first-n 1` to the eval.
- **Loads `.env`** (so `GROQ_API_KEY` / `OPENROUTER_API_KEY` reach Promptfoo);
  missing `.env` → warning, continues (lets `export GROQ_API_KEY=…` work too).
- **Before the run:** one-line reminder that a failing check is the finding.
- **After the run**, branch on exit code:
  - `0` → "🛡 every guardrail held — try a tougher attack / another model".
  - `100` → "✓ one or more checks failed — that's the finding; open the report
    with `./run.sh view`".
  - anything else → "✗ an actual error (key/network/throttle) — see
    docs/03-troubleshooting.md".
- The wrapper **re-exits with Promptfoo's own code**, so scripting/CI semantics
  are unchanged.

Verdict wording is generic enough to be true for both the red-team roots and the
quality suites (in both, a failing assertion = the flaw/attack surfaced).

## Portability & style

- `run.sh`: `#!/usr/bin/env bash`, `set -uo pipefail`, the same `GREEN/RED/…`
  color helpers as `setup.sh`. **bash-3.2-safe** (macOS): a `case` statement for
  name→config mapping — no `mapfile`, no associative arrays, no non-empty arrays
  under `set -u`. Must pass the CI `shellcheck --severity=warning` floor;
  intentional word-splitting on the passthrough carries a scoped
  `# shellcheck disable=SC2086`.
- `run.ps1`: `#!/usr/bin/env pwsh`, mirrors `preflight.ps1` conventions —
  parses `.env` into `$env:*`, `switch` for the mapping, reads `$LASTEXITCODE`.

## Documentation changes (#3)

- **README.md**: (a) a "New here? → visual [repo map](docs/repo-map.pdf)" pointer
  near the top; (b) "Run the workshop eval" shows `./run.sh medibot` as the easy
  path, with the raw `npx` kept below as the under-the-hood equivalent.
- **docs/01-quickstart.md**: steps 4–5 use `./run.sh medibot` / `./run.sh view`;
  add `run.sh` / `run.ps1` to the file-map table.
- **setup.sh**: the "Next:" hint points at `./run.sh medibot` (safe pacing +
  explained result) instead of the raw `npx` lines.

## Testing

- **Deterministic wrapper test (no Groq):** a mock `npx` on `PATH` that records
  its args and exits a chosen code. Assert:
  - name→config+pacing mapping (`-c promptfooconfig.medibot.yaml -j 1 --delay 1000`),
  - exit `0` → "guardrail held", exit `100` → "finding", exit `1` → "actual error",
  - unknown target → exit 2 + usage,
  - the wrapper re-exits the mock's code.
- **shellcheck** `run.sh` at the warning floor (the CI gate).
- One optional live single-case run (`./run.sh medibot --filter-first-n 1`),
  budget permitting.

## Out of scope

- Module 0/2 lesson runners (ordinary pass=good; run fine with plain `npx`).
- Any change to configs, prompts, tests, assertions, or the model matrix.
- The other suggested improvements (debugger hints, `submissions/`, facilitator
  guide, offline config-lint CI) — separate follow-ups.
