# Observability lesson: real Arato.ai + hand-rolled OTel-shaped tracing

**Date:** 2026-08-01
**Source:** [github.com/Jaimeman84/financial-chat-bot](https://github.com/Jaimeman84/financial-chat-bot) (legacy repo) — its OpenTelemetry + Arato.ai instrumentation, deferred from the earlier "port cohort lessons" design because it requires a running service to instrument, which no part of this workshop has.

**Revision note:** this replaces an earlier doc-only draft of this same spec. After presenting that draft, the user clarified they want *real* Arato.ai wiring, not just prose describing it — while still avoiding the complications (npm install, a running server) that made a fully faithful port seem to require those. This version is the resolution: a real, runnable, zero-dependency lesson.

## Context

`engenious-inc/breaking-gpt-claude-workshop` is a 3-module course (Module 0: Promptfoo Basics, Module 1: Red-Team Fundamentals, Module 2: Advanced Eval) plus a hackathon — see `CLAUDE.md` and `modules/README.md`. Module 2's lessons each live in a self-contained subfolder (`modules/02-advanced-eval/<lesson>/`) with their own `prompts/`, `tests/`, `promptfooconfig.yaml` — e.g. `csv-driven-data/`, `fscore-classification/`. `CLAUDE.md` states two hard constraints this design must respect: **no root `package.json`** (Promptfoo is always invoked via `npx promptfoo@latest`) and Module 2 lessons are **single-provider by design** (not the 3-model matrix Module 1 uses).

## Decisions (from brainstorming)

1. **Real, not simulated.** The Groq call, its latency, its token counts, and the prompt's SHA-256 hash are all genuinely measured/computed at request time. The Arato.ai REST log call is a real HTTP POST — it fires for real if `ARATO_API_KEY`/`ARATO_API_URL` are set, and gracefully no-ops (printing why) if they aren't.
2. **Zero npm dependencies.** A custom Promptfoo JS provider (`callApi`) can use only Node built-ins (`fetch`, `node:crypto`) — no `@opentelemetry/api` SDK, no `package.json` anywhere in the repo. The OTel *span shape* (trace_id/span_id/attributes) is hand-rolled and honestly labeled as such — real data, not the official SDK.
3. **Placement:** a new lesson subfolder, `modules/02-advanced-eval/observability/`, matching every other Module 2 lesson's structure. Gets a new bullet in `modules/02-advanced-eval/README.md`'s Lessons list — it's a real runnable lesson now, not a doc-only appendix.
4. **Arato.ai featured prominently and for real** — its actual REST endpoint shape and env var names, matching the legacy repo's actual usage.
5. **Single provider**, per Module 2's documented convention — one Groq model (`llama-3.3-70b-versatile`), not the 3-model block.

## Files to create

### `modules/02-advanced-eval/observability/provider.mjs`

```js
// Custom Promptfoo provider that wraps a REAL Groq chat-completion call with
// hand-rolled OTel-shaped tracing (console output, no SDK — this repo has no
// package.json anywhere) and a REAL Arato.ai REST log call (skipped
// gracefully if ARATO_API_URL/ARATO_API_KEY aren't set). Zero npm
// dependencies: only Node builtins (fetch, node:crypto).

import { randomBytes, createHash } from 'node:crypto';

function hex(bytes) {
  return randomBytes(bytes).toString('hex');
}

async function logToArato(entry) {
  const url = process.env.ARATO_API_URL;
  const key = process.env.ARATO_API_KEY;
  if (!url || !key) {
    console.log('[arato] skipped — ARATO_API_URL/ARATO_API_KEY not set');
    return;
  }
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
      body: JSON.stringify(entry),
    });
    console.log(`[arato] POST ${url} -> ${res.status}`);
  } catch (err) {
    console.log(`[arato] request failed: ${err.message}`);
  }
}

export default class ObservedGroqProvider {
  constructor(options) {
    this.providerId = options.id || 'observed-groq';
    this.config = options.config || {};
  }

  id() {
    return this.providerId;
  }

  async callApi(prompt) {
    const model = this.config.model || 'llama-3.3-70b-versatile';
    const traceId = hex(16);
    const spanId = hex(8);
    const start = Date.now();

    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${process.env.GROQ_API_KEY}`,
      },
      body: JSON.stringify({
        model,
        messages: [{ role: 'user', content: prompt }],
        temperature: this.config.temperature ?? 0,
        max_tokens: this.config.max_tokens ?? 400,
      }),
    });

    const durationMs = Date.now() - start;
    const data = await response.json();

    if (!response.ok) {
      return { error: `Groq API error ${response.status}: ${JSON.stringify(data)}` };
    }

    const output = data.choices[0].message.content;
    const promptHash = createHash('sha256').update(prompt).digest('hex');

    console.log(JSON.stringify({
      span: 'llm.chat.completion',
      trace_id: traceId,
      span_id: spanId,
      model,
      duration_ms: durationMs,
      tokens: data.usage,
      'prompt.sha256': promptHash,
    }, null, 2));

    await logToArato({
      model,
      tokenUsage: data.usage,
      latencyMs: durationMs,
      traceId,
      spanId,
      promptHash,
    });

    return {
      output,
      tokenUsage: {
        total: data.usage?.total_tokens,
        prompt: data.usage?.prompt_tokens,
        completion: data.usage?.completion_tokens,
      },
    };
  }
}
```

### `modules/02-advanced-eval/observability/promptfooconfig.yaml`

```yaml
description: "Module 2 — Observability: real Arato.ai logging + OTel-shaped tracing (single provider, zero npm dependencies)"

prompts:
  - file://prompts/prompt.txt

providers:
  - id: file://provider.mjs
    config:
      model: llama-3.3-70b-versatile
      temperature: 0
      max_tokens: 400

tests:
  - file://tests/basic.yaml
```

### `modules/02-advanced-eval/observability/prompts/prompt.txt`

```
{{query}}
```

### `modules/02-advanced-eval/observability/tests/basic.yaml`

```yaml
- description: "Simple factual question"
  vars:
    query: "What is HTTP?"
  assert:
    - type: icontains
      value: "protocol"

- description: "Simple definitional question"
  vars:
    query: "In one sentence, what is OpenTelemetry?"
  assert:
    - type: icontains-any
      value: ["trace", "observability", "telemetry"]
```

### `modules/02-advanced-eval/observability/README.md`

````markdown
# Observability: Arato.ai + OTel-shaped tracing

Every other lesson in this module asks "did the model answer well?" This one
asks a different question: once a system like this is *deployed*, what is it
doing — how slow, how many tokens, which requests are erroring? That's
observability, and the standard for it is OpenTelemetry (OTel).

## What's real here

- **Trace/span IDs, latency, token counts** — genuinely measured from a real
  Groq API call, not simulated.
- **The prompt hash** — a real SHA-256 of the actual prompt, computed at
  request time.
- **The Arato.ai log call** — a real REST POST to
  [Arato.ai](https://www.arato.ai)'s logging endpoint, if you set
  `ARATO_API_URL`/`ARATO_API_KEY` in `.env` (both optional — sample output
  below shows what happens either way).

## What's simplified

There's no official `@opentelemetry/api` SDK here — this repo has no
`package.json` anywhere (see `CLAUDE.md`), so adding one would mean an
`npm install` step that breaks that convention for one lesson. Instead,
`provider.mjs` prints a trace/span-*shaped* JSON object by hand, using real
measured data. It's not wire-compatible OTLP output — it's the same
information, shown honestly as a simplified stand-in for what the real SDK
would emit.

## Why privacy is part of this, not an afterthought

`provider.mjs` never logs the raw prompt text — only its SHA-256 hash. This
mirrors a real production pattern: telemetry is itself a place user data can
leak, so it gets the same "don't log what you don't need" treatment as any
other data sink.

## Run it

```bash
npx promptfoo@latest eval -c modules/02-advanced-eval/observability/promptfooconfig.yaml
```

Sample output (Arato unset):
```
{
  "span": "llm.chat.completion",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "model": "llama-3.3-70b-versatile",
  "duration_ms": 412,
  "tokens": { "prompt_tokens": 12, "completion_tokens": 34, "total_tokens": 46 },
  "prompt.sha256": "8f3a2b1c..."
}
[arato] skipped — ARATO_API_URL/ARATO_API_KEY not set
```

With a real Arato account, add to `.env`:
```env
ARATO_API_URL=https://api.arato.ai/<your-project>/log
ARATO_API_KEY=ar-...
```
and the last line becomes `[arato] POST https://api.arato.ai/<your-project>/log -> 200`.

## Why MediBot/FinanceBot don't have any of this

Module 1's bots call Groq directly via Promptfoo's built-in `groq:` provider
— there's no code of ours in that path to instrument. This lesson swaps in a
*custom* provider specifically so there's somewhere to put that
instrumentation. In a real deployment, your own API layer is that somewhere.

> Extension lesson — not part of the original `how-to-test-ai` day-03-promptfoo-advanced curriculum.
````

## Files to modify

### `.env.example` — append

```env

# Optional — enables real REST logging in modules/02-advanced-eval/observability/ (Arato.ai account).
# ARATO_API_URL=https://api.arato.ai/<your-project>/log
# ARATO_API_KEY=ar-...
```

### `modules/02-advanced-eval/README.md` — add one bullet to the Lessons list

```markdown
- `observability/` — real Arato.ai REST logging + hand-rolled OTel-shaped tracing via a custom zero-dependency provider; shows what production telemetry adds beyond eval-time quality checks
```

## Verification plan

1. Run `npx promptfoo@latest eval -c modules/02-advanced-eval/observability/promptfooconfig.yaml` live against the real `GROQ_API_KEY`, with `ARATO_API_URL`/`ARATO_API_KEY` unset — confirm: 0 errors, both test cases pass, console shows real span-shaped JSON with plausible `duration_ms`/`tokens`, and `[arato] skipped — ...` prints exactly once per case.
2. Confirm the printed `prompt.sha256` is deterministic and correct by spot-checking one value against `shasum -a 256` on the actual rendered prompt text.
3. Read through `README.md` for internal consistency between the "what's real" / "what's simplified" claims and the actual `provider.mjs` code.
4. Grep the whole new lesson folder for stray `package.json` or `node_modules` — must not exist (zero-dependency claim must hold).

## Files touched (summary)

**New:** `modules/02-advanced-eval/observability/{provider.mjs, promptfooconfig.yaml, prompts/prompt.txt, tests/basic.yaml, README.md}`
**Modified:** `.env.example`, `modules/02-advanced-eval/README.md`
