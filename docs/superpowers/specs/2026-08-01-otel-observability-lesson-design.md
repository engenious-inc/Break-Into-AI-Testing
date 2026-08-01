# Production observability lesson (OTel + Arato.ai), doc-only

**Date:** 2026-08-01
**Source:** [github.com/Jaimeman84/financial-chat-bot](https://github.com/Jaimeman84/financial-chat-bot) (legacy repo) — its OpenTelemetry + Arato.ai instrumentation, deferred from the earlier "port cohort lessons" design (`2026-08-01-financebot-legacy-lessons-design.md`) because it requires a running service to instrument, which no part of this workshop has.

## Context

Since that earlier design, `engenious-inc/breaking-gpt-claude-workshop` was restructured into a 3-module course (Module 0: Promptfoo Basics, Module 1: Red-Team Fundamentals, Module 2: Advanced Eval) plus a hackathon — see `CLAUDE.md` and `modules/README.md`. There is still no running app anywhere in this workshop; every lesson is a `prompts/*.txt` + `tests/*.yaml` + `promptfooconfig.*.yaml` triplet read directly by `npx promptfoo`, zero-install.

## Decisions (from brainstorming)

1. **Depth:** conceptual doc-only. No runnable code, no new Node dependency, no new install step — matches how "automated redteam generation" was added to Module 1 earlier.
2. **Placement:** appended to the end of `modules/02-advanced-eval/README.md` as a new `## Going further: production observability` section. Module 2 has no separate exercises doc the way Module 1 does (`docs/02-redteam-exercises.md`) — its README is the single doc for the whole module — so this follows that module's existing pattern rather than introducing a new file.
3. **Arato.ai:** featured prominently, matching the legacy repo's actual usage — named specifically, with its real env var names, not genericized away.

## Content to add

Append to `modules/02-advanced-eval/README.md`, immediately after the existing "Maps to `how-to-test-ai` day-03-promptfoo-advanced." line:

````markdown

## Going further: production observability

Everything above is about evaluation quality — did the model answer well, by some
scored, weighted, F-score-y measure. None of it tells you what a *deployed* system
is actually doing once it's live: how slow is it, how many tokens is it burning,
is one user hitting errors nobody else is. That's a different discipline —
observability — and the standard for it is OpenTelemetry (OTel).

- **Trace** — one user request end-to-end.
- **Span** — one step within a trace (the LLM call itself, a DB lookup, ...).
- **OTLP** — the wire format traces/metrics ship in, to any OTLP-compatible backend.

### A real worked example

A production financial-education chatbot we've worked with instruments every LLM
call with both: an OTel span (model, token usage, TTFT/TTLT latency, conversation
ID) exported via OTLP, *and* a parallel REST log to **[Arato.ai](https://www.arato.ai)**,
an LLM-observability platform built for exactly this. Wiring looks like:

```env
OTEL_SERVICE_NAME=financial-chatbot
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel.arato.ai
OTEL_EXPORTER_OTLP_HEADERS=Authorization=Bearer <your-api-key>

ARATO_API_URL=https://api.arato.ai/<your-project>/log
ARATO_API_KEY=ar-...
```

Illustrative shape (not runnable here — no app exists in this workshop to attach
this to):

```ts
// One call, two destinations: an OTel span for the trace pipeline,
// and a direct Arato log call for their dashboard.
const span = tracer.startSpan('llm.chat.completion')
const response = await llm.chat(messages)
span.setAttributes({
  'llm.model': modelName,
  'llm.tokens.prompt': response.usage.promptTokens,
  'llm.tokens.completion': response.usage.completionTokens,
  'llm.latency_ms': Date.now() - start,
})
span.end()

await logToArato({
  model: modelName,
  tokenUsage: response.usage,
  latencyMs: Date.now() - start,
  conversationId,
})
```

### Privacy is part of the observability surface, not an afterthought

That same app logs `LOG_RAW_PROMPTS=false` by default — telemetry gets message
*length* and a SHA-256 *hash*, never the raw text, unless a developer explicitly
flips it on for local debugging. Observability tooling is itself a place user
data can leak; treat it with the same care as any other data sink.

### Why none of this exists in MediBot/FinanceBot

This workshop's bots call Groq directly — there's no wrapping service, so there's
nothing to instrument. The moment you put a real API in front of an LLM (which
almost every production deployment does), you inherit this whole surface: what do
you log, where does it go, who can see it, and what happens when the vendor you
send it to is down.

**Further reading:** [OpenTelemetry docs](https://opentelemetry.io/docs/) ·
[Arato.ai](https://www.arato.ai)
````

## Files touched

**Modified:**
- `modules/02-advanced-eval/README.md` — one new section appended, as above

**Not touched:** everything else. No new files, no dependency changes, no `CLAUDE.md` update (that file's "Course layout" list operates at module granularity, not per-subsection — adding a subsection to Module 2's existing doc doesn't change it).

## Verification plan

This is prose-only — no live eval, no code to run. Verification is a read-through:
1. Confirm the section renders correctly as Markdown (headings, code fences, links).
2. Confirm it doesn't imply any of this is runnable in the current workshop (the "not runnable here" caveat on the code snippet is load-bearing — must survive any later editing).
3. Confirm the `modules/02-advanced-eval/README.md` file still reads coherently end-to-end after the append (no abrupt tone shift from the terse "Lessons" index into a long-form essay without a clear section break — the `##` heading should carry that transition).
