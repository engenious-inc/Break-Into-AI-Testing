# Design — `preflight.sh` readiness check

**Date:** 2026-07-07
**Status:** Approved (design), pending implementation plan
**Scope:** One facilitator/attendee utility script (plus Windows parity). Single implementation plan.

## Problem

Running the workshop for ~20 attendees on Groq's free tier, the day-of failures are
predictable — a bad or missing API key, transient rate-limiting, or an environment
that drifted since setup. Today there is no fast, repeatable way to confirm "am I
ready?" right before kickoff.

`setup.sh` already installs and configures everything, but it is the wrong tool for a
readiness check:

- It **mutates state** — installs Node, prompts for keys, writes `.env`. You don't
  want attendees re-running an installer to check readiness.
- Its smoke test **swallows output** (`>/dev/null 2>&1`) and reports only
  `failed (exit N) — see troubleshooting`. A bad key (401), a throttle (429), and a
  network failure are indistinguishable.

## Goal

A **read-only, side-effect-free, re-runnable** probe — `preflight.sh` — that gives a
clear green/red readiness verdict and, on failure, names the **specific** problem and
its fix. Prioritized failure modes (chosen with the requester):

1. **Bad / missing key** — no key, the `gsk-replace-me` placeholder, or an invalid key.
2. **Rate-limit / throttle** — transient 429s or low remaining budget on the free tier.
3. **Environment not ready** — Node missing/<20, promptfoo cache cold, `.env` or
   starter files missing.

## Non-goals

- **Corporate-proxy / TLS-intercept diagnostics** — de-prioritized by the requester. A
  generic "couldn't reach api.groq.com" line still falls out of the network-error path.
- **Installing or fixing anything** — preflight only *reports*; `setup.sh` remains the
  tool that mutates state.
- **An automated test suite** — see Testing; a manual matrix plus a mock seam is the
  agreed approach.
- **The OpenRouter fallback key** — not checked. Groq is the primary path; OpenRouter
  matters only in the rare "Groq is down" case and has its own config already.

## Positioning vs. `setup.sh`

| | `setup.sh` | `preflight.sh` |
|---|---|---|
| Purpose | one-time installer | readiness probe |
| Side effects | installs Node, writes `.env` | none (read-only) |
| Run cadence | once | anytime, esp. morning-of |
| On failure | `exit N`, see troubleshooting | specific cause + exact fix |
| Live check | hidden `promptfoo` smoke | one classified `curl` |

## Approach (decided)

Environment checks in plain shell (no network, no side effects), then **one direct
`curl`** to Groq's chat endpoint for the live verdict. A single request cleanly
separates all three prioritized failure modes by HTTP status — which `promptfoo`
cannot, because it abstracts the HTTP layer away. Rejected alternatives: reusing
`promptfoo --filter-first-n 1` (can't distinguish 401/429/network); a hybrid that adds
a `promptfoo` pass (re-adds the latency `curl` avoids — better as an opt-in `--deep`
flag, out of scope here).

## Design

### Phase 1 — Environment (plain shell, no network)

Each check emits a `✓`/`✗` line using `setup.sh`'s existing `ok`/`warn`/`err` helpers
and glyphs, for visual consistency.

1. **Node** present and `>= 20`. Read-only — if missing/old, instruct `run ./setup.sh`;
   never install.
2. **promptfoo** resolves: `npx --yes promptfoo@latest --version` prints → `✓`. (A cold
   cache warms here; that is acceptable and itself informative.)
3. **`.env`** exists → else `✗ run ./setup.sh`.
4. **`GROQ_API_KEY`** — three distinct outcomes: *missing/empty*, *still the
   `gsk-replace-me` placeholder*, or *present*. The key value is never printed or logged.
5. **Starter files intact** — existence check on the files the challenges need:
   `promptfooconfig.medibot.yaml`, `prompts/medibot.txt`, `tests/smoke.medibot.yaml`,
   `promptfooconfig.mybot.yaml`, `prompts/mybot.txt`, `tests/mybot.yaml`. Any missing →
   `✗` listing them with `git checkout -- <file>` to restore.

If the key check (4) fails, Phase 2 is skipped (nothing valid to call with).

### Phase 2 — Live Groq check (one `curl`)

`POST {GROQ_API_BASE}/chat/completions`, model `llama-3.1-8b-instant`,
`messages:[{role:"user",content:"ping"}]`, `max_tokens:1`, `temperature:0`,
`--max-time 10`. Capture HTTP status and response headers.

| Status | Verdict | Message |
|--------|---------|---------|
| **200** | `✓` | "Groq reachable, key valid." Parse `x-ratelimit-remaining-requests`; report headroom; `warn` if low (threshold: < 5 remaining). |
| **401** | `✗` | "Groq rejected your key (401) — check `GROQ_API_KEY` in `.env` or regenerate at console.groq.com/keys." |
| **429** | `!` | "Configured correctly, but currently throttled — wait `<retry-after>`s and add `-j 2` to evals." (Transient, not a setup failure.) |
| other 4xx/5xx | `✗` | Status code + a short body snippet. |
| connection/timeout | `✗` | "Couldn't reach api.groq.com — check your network / VPN." |

### Verdict & exit codes

Final line: green **`READY ✓ — you're set for the workshop`** or red
**`NOT READY`** with the `✗` items repeated.

- **Exit 0** — ready. A 429 throttle counts as ready-with-warning, because
  configuration is correct and the condition is transient.
- **Exit 1** — not ready (any hard `✗`: env, key, files, 401, network).

Scriptable so a facilitator can sweep a room. No secret is ever emitted.

### Configuration seam

`GROQ_API_BASE` env var, default `https://api.groq.com/openai/v1`. Lets a tester point
Phase 2 at a local mock to exercise every status-code branch without live calls (also
the future CI hook). This is the only injected dependency.

## Windows parity

`preflight.ps1` mirrors `preflight.sh` exactly — same checks, same messages, same
verdict and exit codes — using `Invoke-RestMethod` / `$LASTEXITCODE` and following the
conventions already in `setup.ps1`. The repo ships `setup.ps1` and the README has a
PowerShell path, so parity is expected.

## Docs integration

- **README** and **`docs/01-quickstart.md`**: add "Morning-of, run `./preflight.sh`
  (`.\preflight.ps1` on Windows) to confirm you're ready." Add both scripts to the
  quickstart file map.
- **`docs/03-troubleshooting.md`**: each preflight `✗` message references the matching
  troubleshooting section (401 → "401 Unauthorized", 429 → "Rate limit", etc.).
- **`setup.sh` / `setup.ps1`**: the closing "Next:" block suggests running preflight
  before the session (light touch — no behavior change).

## Testing

The value is live-API classification, which cannot be meaningfully unit-tested without
over-engineering a workshop utility. Plan:

- Structure each check as a small, single-purpose function.
- **Manual test matrix** (documented in the PR): valid key → 200 + headroom; corrupted
  key → 401; missing/placeholder key → Phase-1 `✗`, Phase 2 skipped; deleted starter
  file → `✗` with restore hint; offline (airplane mode / unresolvable `GROQ_API_BASE`)
  → network `✗`.
- **Mock seam**: point `GROQ_API_BASE` at a local stub returning 200/401/429/5xx to
  exercise every Phase-2 branch offline. This doubles as a future CI hook if wanted.
- No automated suite ships with this change (YAGNI for a facilitator script).

## Files

| File | Change |
|------|--------|
| `preflight.sh` | new — the readiness probe |
| `preflight.ps1` | new — Windows parity |
| `README.md` | edit — morning-of note + parity mention |
| `docs/01-quickstart.md` | edit — file map + readiness note |
| `docs/03-troubleshooting.md` | edit — cross-link `✗` messages to sections |
| `setup.sh` / `setup.ps1` | edit — closing "Next:" suggests preflight |

## Open assumptions (confirmed with requester)

- Windows `.ps1` parity **is** in scope.
- **No** automated test suite — manual matrix + `GROQ_API_BASE` mock seam instead.
