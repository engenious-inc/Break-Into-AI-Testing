# Day 8: TutorBot as the traced subject, and a working Agenta path

**Date:** 2026-08-13
**Scope:** a new bot prompt, the observability lesson retargeted onto it, custom span
attributes, a `chat.mjs` guard, two Day 8 slides, and the Day 8 session page.

**Sessions affected:** Day 8 only. **Minutes added: zero.** Both blocks this touches
already exist and keep their slots.

## Why

Day 8 slide 23 already tells students the payoff line:

> "The same span goes to Arato.ai, Agenta.ai or anything else that speaks OTLP — only the
> endpoint changes."

Until now nothing backed that. Arato was wired; Agenta was a name on a slide. Worse,
breakout 2 (slide 27) reads *"no Arato account? it prints the span and tells you it
skipped"* — and Arato endpoints are per-tenant, so most of the room skips. A 25-minute
breakout degrades into reading a JSON blob in a terminal.

Agenta cloud is free to sign up. Making it work turns "if you have a key" from the
minority path into the default one.

The second problem is the breakout's own closing question:

> "What would you have to add to this span to debug a slow request in production? Name the
> field."

The traced subject today is `{{query}}` with two generic tests ("What is HTTP?"). There is
no honest answer to that question, because the span describes nothing in particular.

## What this is not

The obvious idea — rebuild the old Student Tutor Assistant deck's LLM-as-judge lesson — is
**rejected**. Day 8 slide 17 already teaches it, better:

> **When the Grader Is the Bug** — the CVV case passed its `llm-rubric` while teaching the
> opposite. The fix: assert `output.route.guard_status`, not the prose.

That uses a real defect from this repo. A TutorBot judge would be a toy restatement of a
lesson already told with a genuine finding, and it would cost minutes Day 8 does not have
(159 against 120).

Also out: the old deck's prompt-registry, human-review and dev→staging→prod screens. They
are Agenta UI tours, they go stale when the vendor redesigns, and the deck's numbers are
already frozen screenshots of one afternoon in March.

**What survives from the old deck is its subject matter** — a tutor parameterised by
subject and level — because that is exactly what makes a span worth slicing.

## Design

### 1. `prompts/tutorbot.txt`

Ported from the old deck's slide 4, same file shape as every other bot here
(`[{role:"system",…},{role:"user",content:"{{query}}"}]`):

- Guide, don't just answer
- Adapt to the student's level
- Use examples and analogies
- Encourage critical thinking
- Always end with a thought-provoking question

Two template variables beyond `{{query}}`: `{{subject}}` and `{{level}}`.

**Why no guardrail-breaking weakness.** Every other bot here exists to be attacked.
TutorBot does not — it is the subject of an *observability* lesson, and a bot that
misbehaves would drag the breakout back into red-teaming, which Day 8 already covers in
its first 55 minutes. TutorBot's job is to produce spans worth reading.

### 2. The observability lesson traces TutorBot

`modules/02-advanced-eval/observability/promptfooconfig.yaml` points at the shared bot
rather than its own throwaway prompt:

```yaml
prompts:
  - file://../../../prompts/tutorbot.txt
```

`observability/prompts/prompt.txt` is deleted — one source of truth for the bot.

`tests/basic.yaml` is replaced with the three cases from the old cohort's
`Student_Tutor_Demo_Testset_v5.json`, carrying their real subject/level pairs:

| subject | level | question |
|---|---|---|
| Mathematics | Beginner | what fractions are and how to add them |
| Biology | Intermediate | what photosynthesis is and why it matters |
| Mathematics | Advanced | solving a quadratic with the formula |

Assertions stay cheap and deterministic — this lesson is about the span, not the answer.
One `icontains` per case on a term the answer cannot avoid, plus a shared

```yaml
- type: regex
  value: '\?\s*$'      # the tutor must end on a question
```

**Not `ends-with`.** Promptfoo has `starts-with` and no `ends-with` — verified against the
installed package, where the string does not appear at all. It would fail at runtime.

That one line doubles as the cheapest possible demonstration that the old deck's
"closing question" criterion — 20% of an LLM judge's rubric, billed per call — is a regex.

### 3. `provider.mjs` — two changes

**Parse the chat format.** `callApi` currently wraps whatever string it is handed in a
single user message. A JSON chat prompt would be posted to Groq as literal JSON. It must
parse a `[{role,content},…]` array into `messages` and fall back to the single-user-message
behaviour for a plain string, so nothing else that uses this provider breaks.

**Emit the domain attributes.** `callApi(prompt, context)` reads `context.vars`:

```js
'tutor.subject': context?.vars?.subject ?? 'unknown',
'tutor.level':   context?.vars?.level   ?? 'unknown',
```

These are the point of the whole change. They are what makes slide 27's third question
answerable: with them you can ask Agenta whether University-level Physics costs more
tokens than Beginner Mathematics. Without them a span is a latency number.

Standard OpenInference attributes stay exactly as they are — `tutor.*` is additive.

**Privacy is unchanged.** Subject and level are *parameters of the exercise*, not user
content, so they ship raw. The question and answer keep going through
`redactForTelemetry()` and remain SHA-256 unless `LOG_RAW_PROMPTS=true`. That contrast is
worth pointing at in the room: the dimensions you slice by are usually safe; the payload
is what leaks.

### 4. `scripts/chat.mjs` — a template-variable guard

`./run.sh chat tutorbot` would print `{{subject}}` and `{{level}}` literally, because
`chat.mjs` only ever substitutes the user turn. Someone will try it in the first five
minutes.

If a system prompt contains unfilled `{{vars}}`, the CLI names them and exits non-zero:

```
tutorbot needs variables chat cannot supply: subject, level
It is a suite subject, not a chat subject — see modules/02-advanced-eval/observability/
```

Three lines, and it turns a confusing broken bot into a signpost.

### 5. Deck — `day8/build.py`, two slides

**Slide 23** keeps its claim and its structure. The "OpenTelemetry / vendor-neutral" column
gains the evidence: the same hand-encoded bytes are accepted by both vendors, and the only
differences are the URL and the auth header (`Bearer` vs `ApiKey`).

**Slide 27** gains a working Agenta path — free signup, one environment variable, watch it
land — while keeping the no-account fallback for anyone who does not sign up. The breakout's
three tasks stay; the third ("name the field") now has `tutor.subject` as its answer.

No slide is added. Deck stays at 29.

### 6. Session page

`days/08-advanced-redteam-sdlc-observability.md` documents the Agenta env vars alongside
the existing run command.

## Verified before writing this

Run against the live endpoint, not assumed:

| Claim | Evidence |
|---|---|
| Agenta accepts this repo's hand-encoded OTLP protobuf | `HTTP 200`, `/api/otlp/v1/traces` |
| The auth scheme is `ApiKey`, not `Bearer` | `Bearer` → `401 Unauthorized` |
| The lesson still runs end-to-end with Agenta configured | `2 passed (100%)`, two `[agenta] OTLP 200` lines |
| It still runs with no observability keys at all | `[otlp] skipped — …`, eval passes |
| Custom `tutor.*` attributes are accepted on ingest | `HTTP 200` on a span carrying them |

## The one risk, and its fallback

**Accepted is not the same as queryable.** A `200` proves Agenta took the bytes. It does
not prove `tutor.subject` is stored as a filterable dimension rather than dropped or
flattened into an opaque blob. Agenta's read API is not at any of the paths probed
(`/api/tracing/traces` is a *write* endpoint — it answers `{"detail":"Missing spans"}`), so
this cannot be settled programmatically from here.

This must be confirmed **by eye in the Agenta UI** before the change is called done. That
is not a gap in the spec; it is the lesson's own rule turned on itself — the README already
says *"a `200` proves the request was accepted, not that the span was stored the way you
meant."*

**If `tutor.*` does not survive:** fall back to standard OpenInference metadata naming
(`metadata.subject` / `metadata.level`, or `llm.prompt_template.variables` carrying the
pair as JSON) and re-check. If no custom dimension survives at all, slide 27's third
question reverts to its current rhetorical form and the lesson keeps every other gain —
the breakout still lands real traces in a real tool. **The Agenta path does not depend on
this risk resolving.**

## Verification

1. `npx promptfoo@latest eval -c modules/02-advanced-eval/observability/promptfooconfig.yaml`
   passes with no observability keys set, printing the skip line.
2. With `AGENTA_API_KEY` set, three `[agenta] OTLP 200` lines, one per test case.
3. With both `AGENTA_API_KEY` and Arato's pair set, both backends log `200` for the same
   `trace_id` — the span is encoded once.
4. The three traces appear in the Agenta UI, and `tutor.subject` is visible on them.
   **Look at the screen.** (See the risk above.)
5. `./run.sh chat tutorbot` exits non-zero and names `subject, level`.
6. `./run.sh chat onboardbot` still works — the guard must not fire on prompts whose only
   variable is the user turn.
7. Deck at 29 slides; slides 23 and 27 render clean; all three checkers report 0.
8. `./scripts/check-day-index.sh` passes.

## Out of scope

- **A TutorBot red-team suite.** It is not an attack target; slide 17 owns that lesson.
- **The old deck's registry / human-eval / deployment-stage screens.** Vendor UI tours.
- **Rebuilding the "Testing in the SDLC" block.** It is Day 8's weakest 15 minutes and the
  runbook already says to compress it first, but changing it is a separate decision on a
  session that is 39 minutes over budget.
- **A `run.sh` target for TutorBot.** It is reached through the observability lesson. A
  second entry point would imply it is a suite of its own.
- **Day 7.** Its homework — *"write one case that passes on text but fails on route"* — is
  the best assignment in the course and is not being diluted.
