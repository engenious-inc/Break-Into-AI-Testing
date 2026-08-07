# Observability: Arato.ai + OTel-shaped tracing

> **This is a Day 8 lesson**, taught with Arato.ai and Agenta.ai — not part of the
> Day 4 metrics exercises. It lives in Module 2 because it is shaped like a Module 2
> lesson (single provider, ordinary pass=good assertions), not because it is taught
> alongside them.

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
and the last line should become `[arato] POST https://api.arato.ai/<your-project>/log -> 200`.

### What Arato receives

```json
{
  "model": "llama-3.3-70b-versatile",
  "id": "msg-1a2b3c4d5e6f7a8b",
  "messages": [{ "role": "user", "content": "sha256:8f3a2b1c... (len=61)" }],
  "response": "sha256:c4d5e6f7... (len=284)",
  "variables": { "trace_id": "...", "span_id": "...", "prompt_sha256": "..." },
  "usage": { "prompt_tokens": 12, "completion_tokens": 34 },
  "performance": { "ttft": 412, "ttlt": 412 },
  "tool_calls": null,
  "arato_thread_id": null,
  "prompt_id": "observability-lesson",
  "prompt_version": "1.0",
  "tags": { "environment": "development", "feature": "eval" }
}
```

These field names are Arato's, not ours — the wire format is snake_case and matches a
working production integration ([`Jaimeman84/financial-chat-bot`](https://github.com/Jaimeman84/financial-chat-bot),
`lib/arato.ts`). That matters, because a schema mismatch here would very likely still
answer `200` and silently drop the record, which is the worst failure mode there is: the
lesson looks like it worked.

**Still confirm the record landed in the Arato UI the first time.** A status code proves
the request was accepted, not that the data was stored the way you meant.

`ttft` and `ttlt` are equal because this provider does not stream. Time-to-first-token is
only a distinct measurement when tokens arrive incrementally.

### The privacy trade-off is a switch, and it has a cost

By default `messages[].content` and `response` are **not** your text — they're
`sha256:<hash> (len=N)`. That keeps the telemetry sink from becoming a copy of every
prompt your users typed.

It also means Arato's UI will show you hashes instead of conversations. That is the real
tension in production observability, and it's worth naming out loud in class: the tool is
more useful the more it knows, and more dangerous for exactly the same reason. Flip it
when you need to read the conversations back:

```env
LOG_RAW_PROMPTS=true
```

Worth noting: the reference integration ships this same `LOG_RAW_PROMPTS` switch for its
OTel spans, but sends raw text to Arato regardless of it. Redacting one sink and not the
other is an easy inconsistency to introduce — a good thing to have students go find.

## Why MediBot/FinanceBot don't have any of this

Module 1's bots call Groq directly via Promptfoo's built-in `groq:` provider
— there's no code of ours in that path to instrument. This lesson swaps in a
*custom* provider specifically so there's somewhere to put that
instrumentation. In a real deployment, your own API layer is that somewhere.

> Extension lesson — not part of the original `how-to-test-ai` day-03-promptfoo-advanced
> curriculum. Taught on **Day 8** (Advanced Red Teaming, SDLC Testing + Arato.ai &
> Agenta.ai).
