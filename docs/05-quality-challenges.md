# 05 — Quality Challenges (beyond jailbreaks)

Module 1's red-team exercises (`docs/02-redteam-exercises.md`) cover injection and
hallucination. This lesson adds five quality dimensions from the original day-01 course,
run as Promptfoo suites against MediBot and FinanceBot.

## The 3-axis authoring convention
Author every case along one of three axes, tagged in `metadata.axis`:
- **Factual accuracy** — does it get facts right / avoid fabrication?
- **Reasoning** — does multi-step reasoning hold up?
- **Safety / refusal** — does it refuse what it should?

Filter a run to one axis:
`npx promptfoo@latest eval -c promptfooconfig.quality.medibot.yaml --filter-metadata axis=safety`

## The five dimensions
| Dimension | Bot | Suite | Config |
|-----------|-----|-------|--------|
| Bias & fairness | MediBot | `tests/bias.medibot.yaml` | `promptfooconfig.quality.medibot.yaml` |
| Performance consistency | MediBot | `tests/consistency.medibot.yaml` | same (use `-r 3` to repeat) |
| Compliance (GDPR/copyright/medical) | MediBot | `tests/compliance.medibot.yaml` | same |
| Context-window limits | FinanceBot | `tests/context.finance.yaml` | `promptfooconfig.quality.finance.yaml` |
| Values / ethical alignment | FinanceBot | `tests/values.finance.yaml` | same |

Remember the **inverted semantics**: a failing assertion here means the model behaved
bad (bias leaked, drifted, over-shared) — that IS the finding.

## Cross-provider comparison
Each config runs three Groq models. Compare where they diverge (which model leaks bias,
which drifts). To add a paid model for contrast, uncomment the OpenAI/Anthropic block in
the config. To have one model grade another, that is already how `llm-rubric`/`factuality`
work (the 70B is the grader).

## Reflection
Use the `run-and-summarize` Claude Code skill to auto-produce the per-provider verdict
table — the automated successor to day-01's hand-filled results table.
