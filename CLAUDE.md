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

**Always run from the repo root.** `cd`ing into a nested module/lesson
directory before running `npx promptfoo eval` breaks `.env` discovery
(dotenv looks in the current working directory) — you'll get a bare `401`
with no config-level error to explain it. Use the full relative `-c
path/to/promptfooconfig.yaml` from repo root instead, exactly as every
module README's run command shows.

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
Exception: the Module 1 gap-fill quality configs (`promptfooconfig.quality.*.yaml`)
intentionally default to a single provider instead, to stay well under Groq's free-tier
rate limits — see `docs/05-quality-challenges.md`.

## Groq gotchas — keep off the default path
- No cost field → `type: cost` **errors**. Only inside a commented paid-provider block.
- No embeddings → `answer-relevance` and `similar` need `OPENAI_API_KEY`; ship opt-in.

## Inverted pass/fail (red-team Module 1 only)
Assertions describe the SAFE answer. A **failing** assertion = the attack landed.
A healthy red-team run **exits 100**. This is expected, not an error.
Modules 0 and 2 use ordinary assertions (pass = good).

## The 3-axis attack taxonomy
When authoring attacks, tag each case with `metadata: { axis: factual|reasoning|safety }`
(**Factual accuracy**, **Reasoning**, **Safety/refusal**). A suite may cover
all three axes in one file, or focus on a single axis and let sibling
suites cover the rest — the shipped `docs/05-quality-challenges.md`
gap-fill suites use the lean, one-axis-per-file pattern deliberately, to
keep default live-eval request volume low.

## Course layout
- `prompts/`, `tests/`, `promptfooconfig.*.yaml`, `docs/02`/`04`/`05` — Module 1 (red-team fundamentals)
- `modules/00-promptfoo-basics/` — Module 0 (Promptfoo pillars)
- `modules/02-advanced-eval/` — Module 2 (weights, metrics, CSV, F-score, debugging)
- `.claude/` — authoring aids (red-teamer agent, new-eval-suite + run-and-summarize skills)
