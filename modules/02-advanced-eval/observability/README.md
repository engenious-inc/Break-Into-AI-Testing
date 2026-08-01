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
