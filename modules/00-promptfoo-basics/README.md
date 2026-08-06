# Module 0 — Promptfoo Basics

Learn the three Promptfoo pillars before red-teaming: **Prompts**, **Providers**,
**Assertions & Metrics**. Every lesson is a runnable config using the Groq free tier —
no paid key needed (a couple of clearly-marked optional lessons need `OPENAI_API_KEY`).

Run any lesson: `npx promptfoo@latest eval -c modules/00-promptfoo-basics/<path>/promptfooconfig.yaml`

## Lessons
1. **Prompts** (`01-prompts/`) — text, multiline, variable, and file-based prompts.
2. **Providers** (`02-providers/`) — provider config tuning, model comparison, and an
   optional local model.
   - `configuration/` — Groq 3-model matrix (temperature, max_tokens tuning).
   - `local-model/` — OPTIONAL: requires LM Studio running on localhost:1234; off the key-free default path.
   - `comparing-models/` — the same matrix with a latency budget and a leak check.
     **Fails 2 of 6 on purpose**: `gpt-oss-20b` ships its chain of thought in the visible
     answer, and `configuration/` reports 100% green on the same prompt because it has no
     assertions. See that lesson's README.
3. **Assertions & Metrics** (`03-assertions/`) — contains, regex, factuality, llm-rubric,
   and answer-relevance (optional — needs embeddings).

> Maps to `how-to-test-ai` day-02-promptfoo-basics. The August cohort's **Day 3
> (Prompt Engineering + Local Models)** teaches `01-prompts/` and `02-providers/`
> from this module.
