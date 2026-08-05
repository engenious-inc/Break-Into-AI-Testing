# Modules

This workshop is one course in three modules plus a hackathon.

| Module | Where | Source (how-to-test-ai) |
|--------|-------|-------------------------|
| 0 — Promptfoo Basics | `modules/00-promptfoo-basics/` | day-02-promptfoo-basics |
| 1 — Red-Team Fundamentals | `modules/01-red-team/` (lessons) over repo root (`prompts/`, `tests/`, `promptfooconfig.*`, `docs/02`,`04`,`05`) | day-01-ai-fundamentals-and-challenges |
| 2 — Advanced Eval | `modules/02-advanced-eval/` | day-03-promptfoo-advanced |
| Hackathon | `docs/04-challenges.md` | (base repo) |

Start at Module 0 if new to Promptfoo; jump to Module 1 to start breaking bots.

> **Module 1's runnable artifacts still live at the repo root** — `prompts/`, `tests/`,
> `promptfooconfig.*.yaml`, and `docs/02`/`04`/`05`. `modules/01-red-team/` is a
> *teaching layer* over them (lesson ordering, the Claude Code workflow, and the
> exercises), not a second copy of the suites. The one exception is
> `04-grading-the-grader/`, which ships its own triplet because it deliberately runs
> a deliberately-broken variant of a shipped assertion side by side with the fixed one.
