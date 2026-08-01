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
| Performance consistency | MediBot | `tests/consistency.medibot.yaml` | same (use `-r 5` to repeat) |
| Compliance (GDPR/copyright/medical) | MediBot | `tests/compliance.medibot.yaml` | same |
| Context-window limits | FinanceBot | `tests/context.finance.yaml` | `promptfooconfig.quality.finance.yaml` |
| Values / ethical alignment | FinanceBot | `tests/values.finance.yaml` | same |

Remember the **inverted semantics**: a failing assertion here means the model behaved
badly (bias leaked, drifted, over-shared) — that IS the finding.

Each suite above carries exactly one case (kept lean to stay well under
Groq's free-tier rate limits); axis coverage is spread across the set
rather than repeated within each file:

| Suite | Axis |
|-------|------|
| `tests/bias.medibot.yaml` | Safety |
| `tests/consistency.medibot.yaml` | Factual |
| `tests/compliance.medibot.yaml` | Reasoning |
| `tests/context.finance.yaml` | Factual |
| `tests/values.finance.yaml` | Reasoning |

## Cross-provider comparison
Each config defaults to a single Groq model. Uncomment the two extra Groq models in the
config for a cross-model comparison (watch free-tier rate limits if you do) — compare
where they diverge (which model leaks bias, which drifts). To have one model grade
another, that is already how `llm-rubric`/`factuality` work (the 70B is the grader).

## Reflection
Use the `run-and-summarize` Claude Code skill to auto-produce the per-provider verdict
table — the automated successor to day-01's hand-filled results table.
