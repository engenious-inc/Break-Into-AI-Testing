# Module 1 — Red-Team Fundamentals

Break MediBot and FinanceBot, then hand the repetitive half of the job to an agent.

Module 1's runnable artifacts live at the **repo root** (`prompts/`, `tests/`,
`promptfooconfig.*.yaml`) — this directory is the teaching layer over them, so
there is exactly one copy of every attack suite. Only lesson 04 ships its own
triplet, because it runs three variants of one shipped assertion side by side
(pre-fix, half-fixed, shipped) to isolate what each half of the fix contributes.

## Before you start

```bash
./setup.sh        # once   (Windows: powershell -ExecutionPolicy Bypass -File .\setup.ps1)
./preflight.sh    # every session — read-only, safe to re-run
```

**Run every command from the repo root.** `cd`-ing into a lesson directory
breaks `.env` discovery and you get a bare `401` with nothing explaining it.

## Inverted pass/fail — read this before your first run

Assertions in this module describe the **safe** answer. A **failing** assertion
means **the attack landed** — that is the finding, not a broken test. A healthy
red-team run **exits 100**. Modules 0 and 2 use ordinary semantics (pass = good).

## Lessons

- `01-manual-baseline/` — land one attack by hand; read a 3-model report
- `02-agent-generates/` — the `red-teamer` subagent drafts attacks along the 3 axes
- `03-agent-reports/` — the `run-and-summarize` skill turns a run into a verdict table
- `04-grading-the-grader/` — reproduce a real grading failure: the LLM judge quotes a
  leaked rule back as proof of a refusal. Verify it before teaching it with
  `./scripts/outcome-check.sh`.

Then: `docs/02-redteam-exercises.md` (Act 2 — transfer to FinanceBot),
`docs/05-quality-challenges.md` (bias / consistency / compliance / context / values),
`docs/04-challenges.md` (the hackathon).

## The 3-axis authoring convention

Tag every case `metadata: { axis: factual | reasoning | safety }`.
Filter a run to one axis with `--filter-metadata axis=safety` — this is also how
you keep request volume under Groq's free-tier limit.

> Source: `how-to-test-ai` day-01-ai-fundamentals-and-challenges.
> Delivered as the August cohort's **Day 5 — Red Teaming** (the cohort schedule and
> the source-curriculum day numbers are different schemes; don't try to reconcile them).
