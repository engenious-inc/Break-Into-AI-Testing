# CLAUDE.md — Working in this workshop repo

This is a Promptfoo red-team + evaluation workshop. It is a **course**, not an app.
When you add or edit lessons, follow these conventions.

Requires Node ≥ 20.

## The triplet pattern
Every runnable example is three files:
- `prompts/<name>.txt` — the system+user message array (the "app under test")
- `tests/<name>.yaml` — the attack/eval cases (`description` + `vars.query` + `assert`)
- `promptfooconfig.<name>.yaml` — wires a prompt to the provider matrix + test files

Run one with: `npx promptfoo@latest eval -c promptfooconfig.<name>.yaml`
Then `npx promptfoo@latest view` to open the report UI.

No root `package.json` — Promptfoo is always invoked via `npx promptfoo@latest`, never installed as a dependency.

## Providers — Groq free tier is the default
Copy this block verbatim into every shipped default config (self-contained, no includes):
```yaml
providers:
  - id: groq:llama-3.1-8b-instant
    config: { temperature: 0, max_tokens: 400 }
  - id: groq:llama-3.3-70b-versatile
    config: { temperature: 0, max_tokens: 400 }
  - id: groq:openai/gpt-oss-20b
    config: { temperature: 0, max_tokens: 400 }
```
Model-graded assertions use the 70B as grader:
```yaml
defaultTest:
  options:
    provider: groq:llama-3.3-70b-versatile
```
**Opt-in** providers (paid/local/cross-vendor) ship commented-out with a one-line note.

## Groq gotchas — keep off the default path
- No cost field → `type: cost` **errors**. Only inside a commented paid-provider block.
- No embeddings → `answer-relevance` and `similar` need `OPENAI_API_KEY`; ship opt-in.

## Inverted pass/fail (red-team Module 1 only)
Assertions describe the SAFE answer. A **failing** assertion = the attack landed.
A healthy red-team run **exits 100**. This is expected, not an error.
Modules 0 and 2 use ordinary assertions (pass = good).

## The 3-axis attack taxonomy
When authoring attacks, cover three axes per topic: **Factual accuracy**,
**Reasoning**, **Safety/refusal**. Tag each case with `metadata: { axis: factual|reasoning|safety }`.

## Course layout
- `prompts/`, `tests/`, `promptfooconfig.*.yaml`, `docs/02`/`04`/`05` — Module 1 (red-team fundamentals)
- `modules/00-promptfoo-basics/` — Module 0 (Promptfoo pillars)
- `modules/02-advanced-eval/` — Module 2 (weights, metrics, CSV, F-score, debugging)
- `.claude/` — authoring aids (red-teamer agent, new-eval-suite + run-and-summarize skills)
