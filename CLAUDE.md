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
Copy this block verbatim into the root-level red-team triplet configs
(`promptfooconfig.medibot.yaml`, `promptfooconfig.finance.yaml`,
`promptfooconfig.mybot.yaml`) — the multi-model matrix is the whole point there
(self-contained, no includes):
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
Single-provider by design (NOT the 3-model block): most Module 0 and Module 2 lesson
configs (each isolates one concept and keeps free-tier request volume low), plus the
Module 1 gap-fill quality configs (`promptfooconfig.quality.*.yaml`, see
`docs/05-quality-challenges.md`). The deliberate multi-provider exceptions are the three
lessons whose subject IS the matrix: `modules/00-promptfoo-basics/02-providers/configuration/`
and `.../comparing-models/` (three Groq models each) and
`modules/02-advanced-eval/temperature-and-personas/` (one model at two temperatures).

## Lessons that fail on purpose
Outside Module 1's inverted scoring, one Module 0 lesson ships red by design:
`02-providers/comparing-models/` fails 2 of 6 because `groq:openai/gpt-oss-20b` emits its
chain of thought (`"Thinking: ..."`) in the visible answer. Do not "fix" it by loosening
the assertion — the failure is the lesson, and its README says so. If you add another
deliberately-failing lesson, say so in the module README so a red run is never mistaken
for a broken repo.

## Groq gotchas — keep off the default path
- No cost field → `type: cost` **errors**. Only inside a commented paid-provider block.
- No embeddings on Groq → `answer-relevance` uses local `transformers:` embeddings; `similar` still needs `OPENAI_API_KEY` (opt-in).

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
- `prompts/`, `tests/`, `promptfooconfig.*.yaml`, `docs/02`/`04`/`05` — Module 1 runnable artifacts
- `modules/01-red-team/` — Module 1 lessons (teaching layer over those artifacts; only
  `04-grading-the-grader/` ships its own triplet)
- `modules/00-promptfoo-basics/` — Module 0 (Promptfoo pillars)
- `modules/02-advanced-eval/` — Module 2 (weights, metrics, CSV, F-score, debugging)
- `.claude/` — the Claude Code workflow (red-teamer agent, new-eval-suite +
  run-and-summarize skills). In Module 1 these are the student's path, not optional
  authoring aids; Modules 0 and 2 use them only for scaffolding.

## Agent boundaries (Module 1)
`red-teamer` has `Read, Grep, Glob` and no write access, on purpose. An agent that
generates test cases, runs them, **and** grades the results is a closed loop with no
independent verification — see `modules/01-red-team/04-grading-the-grader/` for a real
case in this repo where the `llm-rubric` grader passed a total system-prompt leak.
Keep the human paste-and-review step when adding agent-driven lessons.

Corollary for authoring: **pair every model-graded assertion with a deterministic one
that fails for structural reasons.** `llm-rubric` / `factuality` fail in ways correlated
with the model under test — often literally the same model, since the 70B is the default
grader. A cheap `not-regex` fails independently, and independence is the point.
