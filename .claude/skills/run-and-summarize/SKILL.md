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
4. For a Module 1 (red-team) config, REMEMBER inverted semantics: a failed assertion =
   the attack LANDED; label that cell ⚠️ and a passed assertion ✅.
5. Close with a 3–5 sentence reflection on accuracy, reasoning, safety consistency.

Never edit configs or tests. Read-only + report.
