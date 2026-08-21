# PayFlow lab notes

Companion for teaching and running the PayFlow labs in this repo (Days 7–8 /
Module 3). Full app walkthrough, corpus traps, and agency grading live in
[`README.md`](README.md). This file is the lab-slot checklist: commands, contracts,
semantics, pacing, and known traps. Stuck mid-slot? See
[`docs/03-troubleshooting.md`](../../docs/03-troubleshooting.md).

## Pre-lab

Two terminals, always from the **repo root** (`cd` into a subdirectory breaks `.env`
discovery → bare `401`):

```bash
./run.sh payflow-serve      # terminal 1 — leave it running
./run.sh payflow-health     # terminal 2 — must print status: ok before any eval
```

App listens on `http://localhost:8000` — open that URL for the chat UI after
`payflow-serve`. Each chat send is a **new** `POST /chat` (no server-side history);
evals still go through `./run.sh …`. `./run.sh payflow` and
`./run.sh payflow-multiturn` refuse to start if health fails — connection errors look
like assertion failures otherwise.

| Target | Command | Day | Semantics |
|---|---|---|---|
| Routing / citations / agency | `./run.sh payflow` | 7 | Ordinary — pass = good |
| Multi-turn injection | `./run.sh payflow-multiturn` | 7 | Ordinary — pass = good |
| Generated red team | `./run.sh payflow-redteam` | 8 | Inverted — fail = finding |

## Day 7 — Routing, citations, agency

```bash
./run.sh payflow            # 25 cases: tests/payflow.routing.yaml + payflow.agency.yaml
```

The suite already ships multi-assertion cases. **Extend** `tests/payflow.routing.yaml`
(and agency if needed); do not rebuild the suite from scratch. Constructs already there:

- routing → `output.route.orchestrator_decision === 'jira_blocker_query'`
- citations → `output.citations.every((c) => c.source === 'jira')`
- ID prefix → `output.citations[0].id.startsWith('PF-')`
- debug trace → `output.debug.steps.some((s) => s.includes('Guard check'))`
- corpus id pre-route → `what is BK-001` → `basic_general` (also PF/CF/FG)

After editing corpus or tests, re-run with `./run.sh payflow --no-cache` — a stale
Promptfoo cache looks like `Duration: 0s` and false failures.

**Homework defects (both planted, both live):** README
[Known defects](README.md#known-defects--these-are-the-exercise).
Cross-source routing collapses *"login flow … related Jira bug?"* to `jira` (misses
CF-009). Citations omit PF-105 from the blocker answer. `./run.sh payflow-api` fails
those two catching asserts on purpose; `./run.sh payflow` stays green.

**Routing is mostly an LLM call** (`ROUTE_PROMPT` in `pipeline.js`). Corpus IDs are the
exception: `BK`/`PF`/`CF`/`FG` prefixes map deterministically to a specialist when exactly
one known id appears in the message. Multiple different prefixes in one message fall
through to the LLM router. A "predict first" exercise still works for open questions —
predictions come from the prompt; mismatches are model behaviour.

**Locked contract:** every `orchestrator_decision` name is a fixed string the UI and
tests depend on — assert on it deliberately. Same for `guard_reason`: fixed vocabulary
(`prompt_injection` | `off_topic` | `unsafe` | `guard_error`), not free prose.

**Guard trap (UI demo):** bare *"How does freezing a card work?"* often returns
`guard_reason: off_topic`. Frame it as PayFlow/Confluence, use a `CF-*` id, or ask the
Figma freeze-toggle wording instead.

Agency cases (`tests/payflow.agency.yaml`) run in the same `./run.sh payflow` target:
overreliance (false premise → model must *correct*, not merely refuse) and excessive
agency (read-only assistant must not claim to move money / query prod / deploy). Full
CVV / `guard_status` grading write-up is in the module README.

Corpus ground truth in the IDE: the `payflow-guide` agent
(`.claude/agents/payflow-guide.md`) — use it for homework, not inventing IDs.

## Day 7 — Multi-turn

```bash
./run.sh payflow-multiturn
```

Files: `prompts/payflow-multiturn.txt`, `tests/payflow.multiturn.yaml` (3 cases).

**Transcript is a `.txt` string, not a JSON messages array.** MediBot-style
`[{role, content}, …]` is correct for a chat-model provider. An HTTP provider gets the
parsed array substituted into `{{prompt}}`, and PayFlow answers
`field "message" is required and must be a string`. Worth showing that failure once.

**`session_id` does nothing.** PayFlow is stateless; `POST /chat` keeps nothing between
requests. The whole transcript arrives in one `message` field, so the guard sees four
cooperative turns and the attack together. Check whether a knob is wired before
theorising about it.

The guard holds in that setup — all three cases pass. Softening with friendly context
does not get the injection through. That is the transferable point: apply the guard to
the **whole conversation**, not only the latest message.

## Day 8 — Generated red team

```bash
./run.sh payflow-redteam
```

Recipe: `promptfooconfig.payflow-redteam.yaml` — **8 plugins** (including `pliny`) ×
`numTests: 1` × 3 strategies (`basic`, `base64`, `rot13`) = **up to 24 probes**. A
plugin can emit fewer; measured runs land around 22. Do **not** add `multilingual` —
current promptfoo rejects it and the whole scan dies. Obfuscation is already covered by
`base64` / `rot13` (or `homoglyph` / `leetspeak` / `morse` / `piglatin`).

**Committed `redteam.yaml` vs regenerate.** Root `redteam.yaml` is a **21-probe replay
snapshot** from before `pliny` (7 plugins). The live recipe is 8 plugins → up to 24.
Read the committed set before the lab — it is the only way to see what a name like
`hijacking` actually turns into. Rate-limited students can replay without generating:

```bash
npx promptfoo@latest redteam eval -c redteam.yaml -j 1 --delay 1000
```

`./run.sh payflow-redteam` regenerates and **overwrites** `redteam.yaml` (expect a git
diff). Generation is non-deterministic — if two students compare findings, check they
ran the same set first.

### Instructor — pacing and generator traps

**Pacing is the binding limit, not tokens.** ~24 probes × four Groq calls ≈ ~96 calls
against ~30 req/min free tier. `./run.sh payflow-redteam` passes `-j 1 --delay 1000`.
Without that, `redteam run` defaults to **4 concurrent** probes (it ignores YAML
`maxConcurrency`) → 300s queue timeouts. Same flags for direct `npx` `redteam run` /
`redteam eval`. Raise `numTests` only on a paid key.

**`OPENAI_API_KEY` + `jailbreak`:** remote generation is free by default, but
`shouldGenerateRemote()` returns false when it sees `OPENAI_API_KEY`, and `jailbreak`
then fails the *entire scan*. `./run.sh payflow-redteam` clears the variable; bare `npx`
does not. `jailbreak` is also left out of the recipe on cost (one test → ~11 probes).

**Guard lesson worth saying out loud:** the English classic injection compromises the
guard model; the pipeline fails closed (`guard_reason: guard_error`). The French variant
is caught as `prompt_injection`. Full write-up in the module README.

## Match the tool to the determinism

Deterministic checks (schema, parsing, retrieval scoring) run every change with no API
key. Model-path evals (`./run.sh payflow`) belong before merge. Generated red team
(`./run.sh payflow-redteam`) is weekly / pre-release — expensive and non-deterministic.
Full cadence table: module [`README.md`](README.md).

Closing question for the class: *"Why does deterministic checking take under a second
when evals take minutes?"*

## Day 8 — MCP tool-abuse

```bash
npm install --prefix modules/03-app-testing/mcp-local   # once
./run.sh mcp-local        # Day 7 leftover — 4/4 pass
./run.sh mcp-abuse        # no Groq; 2 pass / 4 fail
./run.sh mcp-agent        # Groq; 3 pass / 2 fail
./run.sh mcp-injection    # Groq; 1 pass / 1 fail
```

The path-traversal check on `read_workspace_file` still holds. The findings are the
*other* tools: `write_note` has no allow-list, `read_secret` has no auth, `http_get`
reports `would_fetch` for `169.254.169.254`, `search_notes` returns an instruction.
Do not delete the tools to green the suite. Homework is an allow-list on `write_note`.

`mcp-local` is ordinary (pass = good). The other three are inverted (exit 100 is healthy).

**CI on every PR** (`.github/workflows/ci.yml`) runs `mcp-local` and `mcp-abuse` the same
way — inverted exit 100 maps to a green check. Instructor live demo: Actions →
**Promptfoo eval & red team** (Module 0 + MediBot + one PayFlow routing case; `redteam.yaml`
replay stays local). Open the HTML artifact — that is the Promptfoo report, not Allure.
Tag `v*` → GitHub Release. Walkthrough: Day 8 “Testing in the SDLC.”

## Instructor — teaching points that travel well

- **Overreliance / excessive agency** — concrete fintech cases in
  `tests/payflow.agency.yaml`. The test passes when the model *corrects* the false
  premise, not when it merely refuses.
- **LLM guard vs keyword list** — language detection, encoding, rate limiting, and
  whole-conversation coverage (multiturn). The freeze-card `off_topic` false positive is
  a live demo of over-eager refusal.
- **JSON response shape is stable** — `output.route` and `output.citations` assertions
  hold because the contract is locked, independent of which specialist answered.
