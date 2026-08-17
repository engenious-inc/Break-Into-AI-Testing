# Modules

This workshop is one course in four modules plus a hackathon.

| Module | Where | Source (how-to-test-ai) | August cohort |
|--------|-------|-------------------------|---------------|
| 0 — Promptfoo Basics | `modules/00-promptfoo-basics/` | day-02-promptfoo-basics | Day 2 (assertions), **Day 3** (`01-prompts/`, `02-providers/`) |
| 1 — Red-Team Fundamentals | `modules/01-red-team/` (lessons) over repo root (`prompts/`, `tests/`, `promptfooconfig.*`, `docs/02`,`04`,`05`) | day-01-ai-fundamentals-and-challenges | Day 5 |
| 2 — Advanced Eval | `modules/02-advanced-eval/` | day-03-promptfoo-advanced | Day 4 — **except `observability/`, which is Day 8** |
| 3 — Testing an Application | `modules/03-app-testing/` — PayFlow + FinanceBot (+ `promptfooconfig.{payflow,financebot}{,-multiturn,-redteam}.yaml`, `tests/{payflow,financebot}.*.yaml`), [`mcp-deepwiki/`](03-app-testing/mcp-deepwiki/), [`mcp-local/`](03-app-testing/mcp-local/), [`mcp-promptfoo/`](03-app-testing/mcp-promptfoo/) | (new) | Day 7 |
| — Black box | `prompts/onboardbot.txt` + `./run.sh chat onboardbot` (no `promptfooconfig`) | (new) | Day 6 |
| — Observability | `modules/02-advanced-eval/observability/` | (new) | Day 8, with Arato.ai + Agenta.ai |
| Hackathon | `docs/04-challenges.md` | (base repo) | — |

Start at Module 0 if new to Promptfoo; jump to Module 1 to start breaking bots.

> **Module 3 is the only one whose providers are not chat models.** PayFlow and FinanceBot
> use Promptfoo's `http` provider against local multi-agent apps (assert on route +
> citations — server must be up: `./run.sh payflow-serve` then `./run.sh payflow`, or
> `./run.sh financebot-serve` then `./run.sh financebot`).
> MCP track: `mcp-deepwiki/` (remote SUT), `mcp-local/` (stdio SUT — install once,
> `./run.sh mcp-local`), and `mcp-promptfoo/` (Promptfoo *is* the MCP server for the IDE —
> see root `.cursor/mcp.json`). Day 8 reuses workshop-local: `./run.sh mcp-abuse` (JSON,
> inverted), `./run.sh mcp-agent` (Groq picks the tool), `./run.sh mcp-injection`
> (tool-result injection).
> The first two test tools; the third drives evals from chat.
>
> It is also the only module with **both** semantics: `payflow` / `payflow-multiturn` and
> `financebot` / `financebot-multiturn` and `mcp-local` are ordinary pass=good suites, while
> `payflow-redteam` / `financebot-redteam` generate their own attacks and invert them,
> like Module 1, and `mcp-abuse` / `mcp-agent` / `mcp-injection` invert against the
> workshop-local tool inventory. Lab-slot checklist:
> [`LAB-GUIDE-NOTES.md`](03-app-testing/LAB-GUIDE-NOTES.md).

> **Module 1's runnable artifacts still live at the repo root** — `prompts/`, `tests/`,
> `promptfooconfig.*.yaml`, and `docs/02`/`04`/`05`. `modules/01-red-team/` is a
> *teaching layer* over them (lesson ordering, the Claude Code workflow, and the
> exercises), not a second copy of the suites. The one exception is
> `04-grading-the-grader/`, which ships its own triplet because it runs three variants
> of one shipped assertion side by side — pre-fix, half-fixed, and shipped — to isolate
> what each half of commit `e89a944` actually contributes.
