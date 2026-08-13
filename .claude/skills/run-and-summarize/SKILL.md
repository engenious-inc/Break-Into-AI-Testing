---
name: run-and-summarize
description: Run a Promptfoo eval for a config and produce the day-01-style reflection table (per-provider verdicts, key differences, latency). Use when the user says "run and summarize", "reflection table", "compare models".
---

# run-and-summarize

1. Run: `npx promptfoo@latest eval -c <config> -o ./pf-latest.json`.
2. Read `./pf-latest.json`. For each test × provider, record pass/fail, latency, and
   a one-line "key difference" vs the other providers.
3. Emit a Markdown table with one column per provider the run actually used
   (a single-provider config yields one provider column):
   `| Case | Axis | <provider…> | Key difference |`.
4. Inverted vs ordinary semantics (label cells accordingly):
   - **Inverted** (failed assertion = finding ⚠️; passed = ✅): `medibot`,
     `medibot-multiturn`, `finance`, `quality.medibot`, `quality.finance`,
     `openrouter.medibot`, `openrouter.finance`, `payflow-redteam`, and any other
     Module 1 smoke/quality red-team config.
   - **Ordinary** (failed assertion = defect ❌; passed = ✅): Modules 0 and 2
     lessons, `payflow`, `payflow-multiturn`, `mybot`, `reverse`.
5. Close with a 3–5 sentence reflection on accuracy, reasoning, safety consistency.

Never edit configs or tests. Read-only + report.
