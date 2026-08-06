# Providers 2/3 — A Local Model (optional)

Run an open-weights model on your own machine and point Promptfoo at it. Nothing leaves
the laptop, nothing is billed, and there is no rate limit.

**This lesson is off the key-free default path** — it needs LM Studio running locally.
Skip it if you are just working through Module 0; come back when you want an offline
baseline.

## Setup

1. **Install LM Studio** — [lmstudio.ai](https://lmstudio.ai). Free, on macOS, Windows and Linux.
2. **Download a model** — `llama-3.2-3b-instruct` runs on a laptop with 8 GB of RAM.
   Larger models work if you have the memory; start small.
3. **Start the server** — Developer tab → *Start Server*. It serves an OpenAI-compatible
   API on `localhost:1234`. Leave it running.
4. **Run the lesson** (from the repo root, as always):

```bash
npx promptfoo@latest eval -c modules/00-promptfoo-basics/02-providers/local-model/promptfooconfig.yaml
```

## The provider block

```yaml
providers:
  - id: openai:chat
    config:
      apiBaseUrl: http://localhost:1234/v1
      apiKey: lmstudio           # any non-empty string; LM Studio does not check it
      model: llama-3.2-3b-instruct
```

`openai:chat` is the generic OpenAI-compatible client — the `apiBaseUrl` is what points it
at LM Studio instead of OpenAI. The model name must match what LM Studio has loaded.

> Promptfoo also accepts `openai:chat:<model>`, which folds the model into the provider
> id. Both work. This lesson keeps `model` in `config` so every knob lives in one block.

**Compare against Groq, not against paid models.** Only `GROQ_API_KEY` is set up in this
course (see `.env.example`). A config listing `openai:gpt-4o` or `anthropic:messages:…`
fails with a 401 for anyone who has not added a card, and bills anyone who has. The
commented Groq provider in the config is the intended comparison.

## When it is not running

```
API call error: Error: Request failed after 4 retries:
TypeError: fetch failed (Cause: Error: connect ECONNREFUSED 127.0.0.1:1234)
```

That is the expected failure when the LM Studio server is down, and it is easy to read:
the config is fine, the server is not up. Start it and re-run.

## What to look for

Run the same prompt against the local model and `groq:llama-3.3-70b-versatile` and
compare latency, answer quality, and refusal behaviour. The local 3B model will be slower
on a laptop and weaker on reasoning. The useful question is not which one wins — it is
**which categories of test you would be comfortable running entirely offline**, and why.
