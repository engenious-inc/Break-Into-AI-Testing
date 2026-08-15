# Providers 3/3 — Comparing Models

> **Day 3** · [session index](../../../../days/03-prompt-engineering-and-local-models.md)

Run one prompt against all three default Groq models and compare them on the three
things you can actually measure on a free tier: **latency**, **tokens**, and whether the
answer is clean.

```bash
npx promptfoo@latest eval -c modules/00-promptfoo-basics/02-providers/comparing-models/promptfooconfig.yaml
npx promptfoo@latest view
```

## This lesson fails on purpose — 4 pass, 2 fail

Both failures are `groq:openai/gpt-oss-20b`, and both are the same assertion:

```
Expected output to not contain "Thinking:"
```

That model prefixes its visible answer with its own chain of thought:

> **Thinking:** We need to explain diversification to a beginner in two sentences. Should
> be concise. Probably define diversification as spreading investments across different
> assets to…

This is not a hypothetical. It reproduced on every topic we tried. The reasoning tokens
show up in the usage numbers too — the 20B reports reasoning tokens, while Qwen
(`reasoning_effort: none`) and GPT-OSS 120B (`include_reasoning: false`) answer clean.

The neighbouring `configuration/` lesson runs the *same three models on the same prompt*
and reports **3 passed (100%)** — because it has no assertions at all. A green run and a
broken answer. That contrast is the point of this lesson: an eval only tells you about
the things you thought to assert.

## Why `not-icontains` and not an `llm-rubric`

A rubric would work here, but it fails in ways correlated with the model under test — and
our default grader is one of the three models in the matrix. `not-icontains` is free,
instant, and fails for a structural reason that has nothing to do with any model's
opinion. See the "pair every model-graded assertion with a deterministic one" rule in
[`CLAUDE.md`](../../../../CLAUDE.md).

## Why a latency threshold and not a cost budget

Groq's free tier returns no cost field, so `type: cost` does not fail — it **errors**:

```
[ERROR] Cost assertion does not support providers that do not return cost
  0 passed (0%)   0 failed (0%)   1 error (100%)
```

Errored is a third outcome, distinct from passed and failed: a failed assertion is a
finding about the model, an errored one is a defect in your harness. Use `latency` and
token counts as cost proxies here, and keep `type: cost` inside a commented-out paid
provider block. `modules/02-advanced-eval/assert-sets-and-budgets/` shows that pattern.

## Try it

1. Raise `max_tokens` and watch the completion-token gap between Qwen and the 20B widen.
2. Drop the `latency` threshold to 200 ms and see which models start failing — then decide
   whether that is a real budget or an arbitrary one.
3. Add a third topic and check whether the leak reproduces there too.
4. Ask Claude Code to `run and summarize` this config — the `run-and-summarize` skill
   emits the per-provider table with latency and key differences already filled in.
