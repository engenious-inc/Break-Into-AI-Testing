# Consolidating the `how-to-test-ai` curriculum into the Promptfoo workshop

**Date:** 2026-07-31
**Status:** Design — awaiting review
**Repo:** `breaking-gpt-claude-workshop` (the "centralized location")

## Overview

Two courses exist today:

- **`breaking-gpt-claude-workshop`** (base / target) — a zero-install Promptfoo
  red-team workshop. `npx promptfoo`, Node ≥ 20, Groq free-tier primary. Three
  "apps under test" (MediBot, FinanceBot, MyBot), each a triplet of
  `prompts/<bot>.txt` + `tests/<bot>.yaml` + `promptfooconfig.<bot>.yaml`.
  Exercise-and-challenge docs. Built agentically with Claude Code.
- **`how-to-test-ai`** (source) — a 3-day course spread across git branches:
  `day-01-ai-fundamentals-and-challenges` (manual, console-based red-team/quality
  challenges), `day-02-promptfoo-basics`, `day-03-promptfoo-advanced` (both
  Promptfoo lesson trees).

**Goal:** fold *all* of `how-to-test-ai`'s lessons into
`breaking-gpt-claude-workshop` so the base repo becomes the single, centralized
course — **keeping the lessons, not the applications**. The migrated lessons run
on the base repo's existing Promptfoo + Groq setup and reuse the existing bots.

**Non-goals:**
- Not recreating the source repos' example apps (customer_service,
  technical_support, empathetic_assistant, the generic sentiment classifier).
- Not introducing a new evaluation platform (no Agenta.ai). The course *is* a
  Promptfoo course; Promptfoo stays.
- Not preserving the source's branch-per-day delivery. We use directory modules
  in one branch.
- Not building a full Claude-Code-driven lesson runner (considered and rejected as
  over-built — see Approaches).

## Approaches considered

- **A — Additive modular curriculum (CHOSEN).** Base repo's flat red-team layout
  stays exactly as-is and *becomes* Module 1. Add `modules/00-promptfoo-basics/`
  and `modules/02-advanced-eval/` alongside, plus a `docs/05-quality-challenges.md`
  and a lean `.claude/` layer. Least disruption; reuses everything.
- **B — Full restructure.** Move existing `prompts/`, `tests/`, configs under a
  symmetric `shared/` + `modules/01-red-team/` tree. Cleaner final shape but
  churns every path (docs links, QR, setup/preflight) and risks the working base.
  Rejected: cost/risk outweighs symmetry.
- **C — Claude-Code-native delivery.** Each lesson delivered via a slash command
  driving the student interactively. Most "agentic" but heaviest to build and
  maintain. Rejected as delivery mechanism; a thin slice (a few skills/agents) is
  folded into A.

## Key decisions

1. **Promptfoo is the harness. No Agenta.ai.** Days 02–03 *are* Promptfoo
   lessons; a different platform would contradict the material. "Agenta" in the
   original ask refers to the agentic, Claude-Code-built nature of the base repo.
2. **Add a lean Claude Code layer.** The base repo has no `.claude/`/`CLAUDE.md`.
   Add one guide + a small set of skills/agents (see Module: Claude Code layer).
   This is also the bridge from day-01's *manual* pedagogy to the automated
   harness: "write 3 prompts" → a red-teamer subagent; "run + fill reflection
   table" → a run-and-summarize skill.
3. **Reuse the apps; recreate nothing.** MediBot/FinanceBot/MyBot are the running
   examples across all modules. The one lesson needing a labeled dataset
   (F-score classification) is recast as a *workshop-domain* classifier
   ("classify a MediBot reply as safe-refusal / unsafe / hallucination") rather
   than importing a generic sentiment app.
4. **Normalize providers to Groq-primary.** Migrated day-02/03 lessons default to
   the base repo's Groq free-tier provider block so they run at zero cost out of
   the box. OpenAI / Anthropic / OpenRouter / LM Studio remain **opt-in** —
   local-model config and cross-vendor comparison are themselves lessons, so they
   survive as documented options, not defaults.
5. **Fill the five day-01 gaps.** Bias & fairness, values/ethical alignment,
   performance consistency (repeat-runs), context-window retention, and full
   compliance (GDPR/copyright) get new Promptfoo suites against the bots.
   Otherwise those lessons are lost.
6. **The debugger configs stay intentionally broken.** Day-03's
   `1_basic → 2_moderate → 3_advance` ship as "fix-me" exercises with a
   `SOLUTION.md` per stage, not as reference configs.

## Lesson → destination mapping

### Day 01 (7 challenges + methodology) → Module 1 + `docs/05-quality-challenges.md`

| Lesson | Base-repo status | Action |
|---|---|---|
| Security / prompt injection | Covered (Act 1) | Keep; cross-reference from module doc |
| Hallucination | Covered | Keep |
| Bias & fairness | **Gap** | New suite `tests/bias.<bot>.yaml` + config + doc section |
| Performance consistency | Partial | New repeat-run suite (same query ×N) + doc |
| Context-window limits | Partial | New needle-in-haystack suite (long `{{query}}`) + doc |
| Values / ethical alignment | **Gap** | New suite + doc |
| Compliance (GDPR/copyright/medical) | Partial | Extend: GDPR/copyright cases + doc |
| 3-axis taxonomy (Factual/Reasoning/Safety) | **Gap (framing)** | Document as the authoring convention in the module README; tag tests with `metadata.axis` |
| Cross-provider comparison | Covered (matrix) | Keep; document the "same attack across models / one model judging another" runs |
| Manual result recording & reflection | Different | Replaced by Promptfoo's report + the `run-and-summarize` skill |

### Day 02 (Promptfoo basics) → `modules/00-promptfoo-basics/`

Sub-lessons, each a runnable `promptfooconfig.yaml` re-pointed at Groq-primary and,
where natural, at a workshop bot:

- `01-prompts/` — text, multiline (`|`/`|-`), variable (`{{var}}`), file-based
  (`file://`). Reuse the bots' system prompts as the file-based example.
- `02-providers/` — provider config (`id:`+`config:` with `temperature`/
  `max_tokens`), and a `local-model/` example (LM Studio,
  `apiBaseUrl: http://localhost:1234/v1`) kept opt-in.
- `03-assertions/` — `contains`, `regex`, `factuality`, `answer-relevance`
  (`threshold`), `llm-rubric`. Graded by the base repo's Groq 70B grader.

### Day 03 (Promptfoo advanced) → `modules/02-advanced-eval/`

- `weights-and-metrics/` — multiple assertions per test with `weight:` and named
  `metric:`, test-level `threshold:`.
- `assert-sets-and-budgets/` — `type: assert-set`, `threshold: 0.5` for OR, and
  `cost`/`latency` budgets. **Caveat:** Groq's free tier returns no cost field, so
  cost assertions are documented against an opt-in paid provider; latency budgets
  run on Groq.
- `exact-vs-fuzzy/` — weighted `equals` + `similar` (embedding) + `icontains`.
- `csv-driven-data/` — `tests: file://tests/*.csv`, the `__expected*` /
  `__metadata:*` / `__prefix` / `__suffix` / `__threshold` columns, inline
  per-row assertions, `--filter-metadata`, `defaultTest`.
- `fscore-classification/` — TP/FP/FN counter assertions (`weight: 0`) +
  `derivedMetrics` for precision/recall/f1, JSON output
  (`response_format: {type: json_object}`, `temperature: 0`). **Recast** to a
  workshop-domain classifier with a labeled CSV of bot replies. Port
  `FSCORE_COMPLETE_GUIDE.md`.
- `temperature-and-personas/` — same providers at `temperature: 0.7` vs `1` with
  `label:`; empathetic vs non-empathetic persona validated with
  `contains-any` / `not-contains-any`.
- `debugger/` — `1_basic → 2_moderate → 3_advance` fix-me configs (indentation,
  malformed sequences, `vars`/`message` typos, missing `anthropic:` prefix, wrong
  `file://` dir paths, `contains` type mismatch) + the debug-workflow README + a
  per-stage `SOLUTION.md`.

## Target structure (Approach A)

```
breaking-gpt-claude-workshop/
├── README.md                         # rewritten: course index (Module 0→1→2→Hackathon) + quickstart
├── CLAUDE.md                         # NEW: repo conventions, how to run/author a suite, provider blocks
├── .claude/
│   ├── agents/red-teamer.md          # drafts 3-axis attack prompts for a named bot
│   └── skills/
│       ├── new-eval-suite/           # scaffold a prompts+tests+config triplet from a template
│       └── run-and-summarize/        # run `promptfoo eval`, interpret inverted pass/fail, emit reflection table
├── setup.sh · setup.ps1              # kept; extended to warm caches / note new modules
├── preflight.sh · preflight.ps1      # kept; extended to sanity-check module configs resolve
├── prompts/                          # UNCHANGED — Module 1 bot system prompts (medibot/financebot/mybot)
├── tests/                            # existing smoke suites kept; NEW gap-fill suites added:
│   └── bias.*.yaml  consistency.*.yaml  context.*.yaml  values.*.yaml  compliance.*.yaml
├── promptfooconfig.*.yaml            # existing configs kept + new configs wiring the gap-fill suites
├── docs/
│   ├── 01-quickstart.md · 02-redteam-exercises.md · 03-troubleshooting.md · 04-challenges.md  # kept
│   └── 05-quality-challenges.md      # NEW: bias/consistency/context/values/compliance + 3-axis framing
└── modules/
    ├── README.md                     # module map + how each maps to the old day-01/02/03
    ├── 00-promptfoo-basics/          # ← day-02
    │   ├── README.md  01-prompts/  02-providers/  03-assertions/
    └── 02-advanced-eval/             # ← day-03
        ├── README.md  weights-and-metrics/  assert-sets-and-budgets/  exact-vs-fuzzy/
        ├── csv-driven-data/  fscore-classification/  temperature-and-personas/
        └── debugger/ (1_basic/ 2_moderate/ 3_advance/, each with SOLUTION.md)
```

## The Claude Code layer (design detail)

- **`CLAUDE.md`** — repo conventions: the prompt/test/config triplet pattern; the
  inverted assertion semantics (a *failing* assertion = the attack landed, so a
  healthy red-team run exits `100`); the Groq-primary provider block and how to
  opt into paid/local providers; how to run a module (`npx promptfoo eval -c
  <config>` / `promptfoo view`).
- **`.claude/agents/red-teamer.md`** — given a bot name and a lesson topic,
  drafts candidate attack prompts along the 3-axis taxonomy (Factual / Reasoning /
  Safety). Output is a `tests/*.yaml` fragment, not applied automatically.
- **`.claude/skills/new-eval-suite/`** — scaffolds a new triplet (prompt + test +
  config) from a template so a student adds a lesson/suite consistently.
- **`.claude/skills/run-and-summarize/`** — runs an eval, reads the Promptfoo
  output, and produces the day-01-style comparison/reflection table
  (per-provider verdicts, key differences) — the automated replacement for the
  manual results table.

Kept deliberately small (one guide, one agent, two skills). No lesson-runner
framework.

## Provider strategy

- Default provider block across migrated modules = the base repo's Groq block
  (`groq:llama-3.1-8b-instant`, `groq:llama-3.3-70b-versatile` [also the grader],
  `groq:openai/gpt-oss-20b`).
- Opt-in blocks documented and shipped commented-out: `openai:*`,
  `anthropic:messages:*`, `openrouter:*` (fallback), and the LM Studio local
  endpoint. Cross-vendor comparison and local-model lessons use these.
- One `shared`/reference provider snippet documented in `CLAUDE.md` so modules
  don't each re-derive the block; modules still contain their own runnable config
  (no hidden indirection).

## Error handling & edge cases

- **Inverted pass/fail in red-team suites** — documented prominently; preflight
  and README explain exit `100` is healthy for Module 1.
- **Groq free-tier limits (429) / no cost field** — cost assertions live only in
  opt-in paid-provider examples; latency budgets run on Groq; troubleshooting doc
  extended (it already covers 401/429/timeouts and the OpenRouter fallback).
- **Intentionally broken debugger configs** — will not run as-is by design;
  README marks them fix-me and each has a `SOLUTION.md`.
- **Local-model lessons** require LM Studio running; documented as optional, never
  on the default path so CI/preflight never depends on `localhost:1234`.

## Verification

Each migrated module must be independently runnable:

- `npx promptfoo eval -c modules/00-promptfoo-basics/<lesson>/promptfooconfig.yaml`
  returns results on the Groq default (no paid key needed) for every basics and
  advanced lesson except the explicitly opt-in (cost/local/cross-vendor) ones.
- The five new Module 1 gap-fill suites run against MediBot/FinanceBot and produce
  the expected inverted verdicts.
- `preflight.sh` passes (extended check: every shipped default config file
  resolves its prompt/test references).
- Debugger stages fail before the fix and pass after applying `SOLUTION.md`.

## Deliverable / repo location

- Work lands on branch `consolidate-curriculum` in `breaking-gpt-claude-workshop`.
- The clone currently lives in the session scratchpad; final home (push to
  engenious-inc, a FOX fork, or a fresh consolidated repo) is the user's call and
  is out of scope for this design.

## Out of scope

- Recreating any source example app.
- Migrating the source's branch-per-day delivery model.
- Any new eval platform.
- CI wiring beyond the existing `preflight`/`setup` scripts.
- Choosing/creating the final remote for the consolidated repo.
