# Observability Lesson (Arato.ai + OTel-shaped tracing) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new Module 2 lesson (`modules/02-advanced-eval/observability/`) that wraps a real Groq API call with hand-rolled OTel-shaped tracing and a real Arato.ai REST log call — zero npm dependencies, matching this repo's "no package.json anywhere" rule.

**Architecture:** One self-contained lesson subfolder following Module 2's existing per-lesson pattern (own `prompts/`, `tests/`, `promptfooconfig.yaml`), plus a custom Promptfoo JS provider (`callApi`) that makes the LLM call itself instead of delegating to promptfoo's built-in `groq:` provider — that's the hook point for the tracing/logging code. Two small supporting-doc edits wire it into the existing course index.

**Tech Stack:** Node ≥ 20 built-ins only (`fetch`, `node:crypto`) — no npm packages, no `package.json`. Promptfoo custom-provider interface (`.mjs`, ESM, `callApi(prompt, context)`).

## Global Constraints

- Zero npm dependencies. No `package.json`, no `node_modules`, anywhere in this change.
- Single provider only (Module 2 convention) — no 3-model matrix.
- The Arato REST call must gracefully no-op (print why, don't throw) when `ARATO_API_URL`/`ARATO_API_KEY` are unset.
- Never log the raw prompt text — only its SHA-256 hash.
- `.env` already has a valid `GROQ_API_KEY` (confirmed working this session) — source it via `set -a; . ./.env; set +a` before any `npx promptfoo eval` call.
- Work happens on branch `feature/otel-observability-lesson` (already exists, has 2 commits: spec + revised spec). Never commit this work directly to `main`.

---

## File Structure

**New:**
- `modules/02-advanced-eval/observability/provider.mjs` — custom provider: real Groq call, real timing, real SHA-256 hash, console trace, real Arato POST
- `modules/02-advanced-eval/observability/promptfooconfig.yaml` — wires the provider + prompt + tests
- `modules/02-advanced-eval/observability/prompts/prompt.txt` — `{{query}}` passthrough
- `modules/02-advanced-eval/observability/tests/basic.yaml` — 2 simple ordinary-assertion cases
- `modules/02-advanced-eval/observability/README.md` — lesson doc: what's real, what's simplified, how to run, privacy note

**Modified:**
- `.env.example` — optional `ARATO_API_URL`/`ARATO_API_KEY` lines
- `modules/02-advanced-eval/README.md` — one new Lessons bullet

---

### Task 1: Build and verify the lesson

**Files:**
- Create: `modules/02-advanced-eval/observability/provider.mjs`
- Create: `modules/02-advanced-eval/observability/promptfooconfig.yaml`
- Create: `modules/02-advanced-eval/observability/prompts/prompt.txt`
- Create: `modules/02-advanced-eval/observability/tests/basic.yaml`
- Create: `modules/02-advanced-eval/observability/README.md`

**Interfaces:**
- Produces: a runnable `npx promptfoo@latest eval -c modules/02-advanced-eval/observability/promptfooconfig.yaml` command, used verbatim by Task 2's doc bullet and by the README itself.

- [ ] **Step 1: Create `provider.mjs`**

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

- [ ] **Step 2: Create `promptfooconfig.yaml`**

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

- [ ] **Step 3: Create `prompts/prompt.txt`**

```
{{query}}
```

- [ ] **Step 4: Create `tests/basic.yaml`**

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

- [ ] **Step 5: Create `README.md`**

```markdown
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
```

(Note: when writing this file, use a 4-backtick outer fence if wrapping this whole block in another markdown code fence for review purposes — the file itself just needs plain 3-backtick fences as shown.)

- [ ] **Step 6: Run the live eval**

```bash
cd /Users/gregory.goldshteyn/breaking-gpt-claude-workshop
set -a; . ./.env; set +a
npx promptfoo@latest eval -c modules/02-advanced-eval/observability/promptfooconfig.yaml --no-cache --no-progress-bar 2>&1 | tail -60
```

Expected: 0 errors, 2/2 passed, console output includes a `span`/`trace_id`/`span_id`/`duration_ms`/`tokens`/`prompt.sha256` JSON block for each case, and a `[arato] skipped — ARATO_API_URL/ARATO_API_KEY not set` line for each case (since Arato env vars are not set in this repo's `.env`).

- [ ] **Step 7: Spot-check the SHA-256 hash is correct**

```bash
printf '%s' "What is HTTP?" | shasum -a 256
```

Compare the output hash against the `prompt.sha256` value printed for the "Simple factual question" case in Step 6's output — they must match exactly (confirms `provider.mjs` hashes the actual rendered prompt, not something else).

- [ ] **Step 8: Confirm zero dependencies**

```bash
find /Users/gregory.goldshteyn/breaking-gpt-claude-workshop/modules/02-advanced-eval/observability -name "package.json" -o -name "node_modules"
```

Expected: no output (nothing found).

- [ ] **Step 9: Commit**

```bash
cd /Users/gregory.goldshteyn/breaking-gpt-claude-workshop
git add modules/02-advanced-eval/observability/
git commit -m "$(cat <<'EOF'
feat: add observability lesson (real Arato.ai + OTel-shaped tracing)

New Module 2 lesson: a custom, zero-npm-dependency Promptfoo provider
that wraps a real Groq call with hand-rolled OTel-shaped console tracing
(real trace/span IDs, real latency, real token counts, real SHA-256
prompt hash) and a real Arato.ai REST log call (gracefully no-ops if
ARATO_API_URL/ARATO_API_KEY aren't set). Live-verified: 0 errors, 2/2
passed, hash spot-checked against shasum.
EOF
)"
```

---

### Task 2: Wire into the course index and final checks

**Files:**
- Modify: `.env.example`
- Modify: `modules/02-advanced-eval/README.md`

**Interfaces:**
- Consumes: the run command produced by Task 1 (`npx promptfoo@latest eval -c modules/02-advanced-eval/observability/promptfooconfig.yaml`).

- [ ] **Step 1: Append to `.env.example`**

```env

# Optional — enables real REST logging in modules/02-advanced-eval/observability/ (Arato.ai account).
# ARATO_API_URL=https://api.arato.ai/<your-project>/log
# ARATO_API_KEY=ar-...
```

- [ ] **Step 2: Add a Lessons bullet to `modules/02-advanced-eval/README.md`**

Add to the end of the existing `## Lessons` bullet list (after the `debugger/` line):

```markdown
- `observability/` — real Arato.ai REST logging + hand-rolled OTel-shaped tracing via a custom zero-dependency provider; shows what production telemetry adds beyond eval-time quality checks
```

- [ ] **Step 3: Final consistency check**

```bash
cd /Users/gregory.goldshteyn/breaking-gpt-claude-workshop
grep -n "package.json\|node_modules" modules/02-advanced-eval/observability/README.md
```

Confirm the README's own claims about "no package.json" are still accurate (i.e., don't contradict Step 8 of Task 1).

- [ ] **Step 4: Commit**

```bash
cd /Users/gregory.goldshteyn/breaking-gpt-claude-workshop
git add .env.example modules/02-advanced-eval/README.md
git commit -m "docs: wire observability lesson into .env.example and Module 2 index"
```
