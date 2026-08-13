# Day 5 — Red teaming

Attacking a bot's rules on purpose, against two targets with different domain rules.

> Exercises: **[`docs/02-redteam-exercises.md`](../docs/02-redteam-exercises.md)** (Act 1
> and Act 2) and **[`docs/05-quality-challenges.md`](../docs/05-quality-challenges.md)**.
> Both are document numbers. Both are Day 5.

## The one rule that trips everyone

**In a red-team / quality suite, a FAILING assertion means the attack landed.**
Assertions describe the SAFE answer, so a failure is the finding — not a broken test.

| Semantics | Meaning of exit 100 | Targets |
|---|---|---|
| **Inverted** (fail = finding) | Something bad happened — triage it | `medibot`, `finance`, `medibot-multiturn`, `quality.medibot`, `quality.finance`, `openrouter.*`, `payflow-redteam` |
| **Ordinary** (fail = defect) | Your bot / app / lesson broke | Modules 0 and 2, `payflow`, `payflow-multiturn`, `mybot`, `reverse` |

Quality suites (`./run.sh quality.medibot` / `quality.finance`) invert too — a fail means
bias leaked, compliance slipped, or values drifted. Know which column you are in before
you celebrate a red scoreboard.

## Run this

```bash
./run.sh medibot              # healthcare triage — free-tier-safe
./run.sh finance              # retail brokerage — different rules, same techniques
./run.sh medibot-multiturn    # the attack spread across a conversation
./run.sh quality.medibot      # bias / consistency / compliance
./run.sh quality.finance      # context / values
```

Rate-limited on Groq? The same two suites run via OpenRouter instead — both need
`OPENROUTER_API_KEY`:

```bash
./run.sh openrouter.medibot
./run.sh openrouter.finance
```

## Read this

| Lesson | What it teaches |
|---|---|
| [`01-manual-baseline/`](../modules/01-red-team/01-manual-baseline/) | attacks you write by hand — you must do this before generating any |
| [`02-agent-generates/`](../modules/01-red-team/02-agent-generates/) | Claude Code drafting attacks along an axis |
| [`03-agent-reports/`](../modules/01-red-team/03-agent-reports/) | turning findings into something a team can act on |
| [`04-grading-the-grader/`](../modules/01-red-team/04-grading-the-grader/) | the 70B grading its own output, and what that costs you |

`04-grading-the-grader` is the one to slow down on. It comes back on Day 8.

## Homework

Finish Act 2: take the four Act 1 techniques — role-play bypass, authority bypass,
encoded injection, system-prompt extraction — and adapt each to FinanceBot's domain. Add
them to `tests/smoke.finance.yaml`.
