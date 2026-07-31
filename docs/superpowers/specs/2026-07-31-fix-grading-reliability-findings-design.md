# Fix grading-reliability findings from live verification

**Date:** 2026-07-31
**Status:** Design — awaiting user spec review
**Repo:** `breaking-gpt-claude-workshop`, branch `consolidate-curriculum` (open PR #9)

## Overview

Live verification of PR #9 (real `GROQ_API_KEY`, real Groq inference) surfaced
three issues unrelated to rate limiting — two are grading-reliability defects
in shipped lesson content, one is a documentation gap:

1. **`llm-rubric` word-count checks are unreliable.** Reproduced twice: a
   31-word reply was graded "over 50 words"; a 21-word reply was graded "56
   words." The grading model (`groq:llama-3.3-70b-versatile` via `llm-rubric`)
   cannot reliably count words. Affects
   `modules/00-promptfoo-basics/03-assertions/llm-rubric/promptfooconfig.yaml`
   and `modules/02-advanced-eval/weights-and-metrics/promptfooconfig.yaml`,
   both of which fold a word-count clause into a compound `llm-rubric` value.

2. **The F-score lesson's `weight: 0` counter pattern cannot work as
   documented.** Confirmed via two live reproductions plus promptfoo's own
   docs: *"each named score passed into the scoring function is already
   normalized as a weighted average"* — `namedScores` is `Σ(score × weight)`,
   so a `weight: 0` assertion contributes exactly zero to any aggregate
   regardless of its raw per-row score. This is true of promptfoo's own
   documented `__count`/MAPE example, not just the F-score tutorial pattern
   `modules/02-advanced-eval/fscore-classification/` inherited verbatim from
   the original day-03 source material — this is an upstream inconsistency
   between promptfoo's docs and its behavior, not something introduced by
   this migration.

3. **Running from a nested lesson directory silently breaks auth.** `cd`ing
   into a module subdirectory before invoking `npx promptfoo eval` means
   dotenv can't find the repo-root `.env`, producing a bare `401` with no
   config-level error — discovered when it happened during verification
   itself. Every module README already documents running from repo root; this
   just makes the *reason* explicit so it isn't a trap for anyone deviating
   from the documented command.

**Goal:** fix (1) and (2) so the affected lessons' pass/fail behavior actually
matches what they claim to teach, and land the (3) callout so the failure
mode is self-explanatory if hit again.

**Non-goals:**
- Not touching any other Module 0/1/2 lesson — only the two configs with a
  demonstrated word-count reliability problem, and the one config with a
  demonstrated aggregation problem.
- Not filing an upstream promptfoo issue or waiting on a fix — the companion
  script sidesteps the limitation entirely and is robust to promptfoo's
  internal semantics however they evolve.
- Not adding a Python dependency for the F-score script — the repo is
  Node-only (`npx`-driven); the companion script is Node to match.

## Approaches considered

**For the word-count fix:**
- **Split into `llm-rubric` (tone) + `javascript` (length) — CHOSEN.** Keeps
  each lesson's actual teaching point (llm-rubric grading; weighted
  assertions) intact, removes only the sub-clause the grader can't reliably
  judge. Matches the deterministic-length-check pattern the base repo already
  uses in `tests/smoke.medibot.yaml`.
- **Drop the word-count clause entirely.** Simpler, but loses "under 50
  words" as a demonstrated constraint — the lesson becomes less complete for
  no real reason, since a deterministic check is trivial to add.
- **Raise the word limit generously (e.g. "under 100 words") hoping the
  grader miscounts less at a wider margin.** Rejected: doesn't fix the root
  cause (the grader's counting is unreliable, not just miscalibrated at the
  margin — it hallucinated a specific wrong count, not just misjudged a close
  call), and would need re-verification against the same unreliable judge.

**For the F-score aggregation:**
- **Companion script reading `-o` JSON output — CHOSEN** (already presented
  with preview and approved). Robust to promptfoo's internal weighting
  semantics; teaches a realistic, common real-world skill (post-processing
  raw eval output).
- **Strip the broken block, document as a known limitation.** Smaller diff,
  but the lesson's headline deliverable (a working P/R/F1 computation) simply
  wouldn't exist. Rejected by the user in favor of the companion script.

## Design

### 1. Word-count fix

**`modules/00-promptfoo-basics/03-assertions/llm-rubric/promptfooconfig.yaml`**
— `tests[0].assert` becomes:
```yaml
tests:
  - assert:
      - type: llm-rubric
        value: "The response is friendly and welcoming."
      - type: javascript
        value: "output.split(/\\s+/).length <= 50"
```

**`modules/02-advanced-eval/weights-and-metrics/promptfooconfig.yaml`** —
`tests[0].assert` becomes:
```yaml
tests:
  - vars: { topic: "an index fund" }
    threshold: 0.7
    assert:
      - type: llm-rubric
        value: "The response is enthusiastic."
        weight: 2
        metric: Tone
      - type: javascript
        value: "output.split(/\\s+/).length <= 50"
        weight: 1
        metric: Tone
      - type: icontains
        value: "fund"
        weight: 1
        metric: Accuracy
```
(`threshold: 0.7` and the `Tone`/`Accuracy` metric grouping are unchanged —
promptfoo's overall test pass/fail is the flat weighted average across *all*
assertions regardless of metric tag, so splitting the compound rubric into
two weighted assertions under the same `Tone` metric preserves the lesson's
weighted-threshold math while making the length component deterministic.)

### 2. F-score companion script

**`modules/02-advanced-eval/fscore-classification/promptfooconfig.yaml`** —
remove the three `weight: 0` counter assertions and the entire
`derivedMetrics:` block. Keep only:
```yaml
defaultTest:
  assert:
    - type: javascript
      value: "JSON.parse(output).label === context.vars.label"
      metric: accuracy
tests: file://tests/labeled.csv
```
(prompt, provider, `response_format`/`temperature` config unchanged.)

**New file: `modules/02-advanced-eval/fscore-classification/scripts/
compute-fscore.js`** — a Node script, no dependencies beyond Node's builtin
`fs`. Behavior:
- Takes a promptfoo JSON output path as `process.argv[2]`.
- Reads and parses it; walks `results.results[]`.
- Per row: reads the true label from `vars.label`; attempts
  `JSON.parse(response.output).label` for the predicted label, catching parse
  failures. On a parse failure, the predicted label is treated as
  not-`safe_refusal` for confusion-matrix purposes — it never contributes to
  TP or FP (which both require a predicted label of `safe_refusal`), and
  contributes to FN only if the row's true label is `safe_refusal` (a
  should-have-been-caught case that was missed). Model output parsing is a
  genuine external-input boundary, not an internal invariant, so this must
  not crash the script.
- Tallies TP/FP/FN for the `safe_refusal` positive class using the same
  semantics the removed promptfoo assertions used (predicted `safe_refusal` ∧
  actual `safe_refusal` → TP; predicted `safe_refusal` ∧ actual ≠ → FP; actual
  `safe_refusal` ∧ predicted ≠ → FN).
- Computes `precision = TP/(TP+FP)`, `recall = TP/(TP+FN)`,
  `f1 = 2·TP/(2·TP+FP+FN)`, printing `"N/A"` instead of a divide-by-zero
  result when a denominator is 0.
- Also prints overall accuracy (rows where predicted === actual) as a
  sanity cross-check against promptfoo's own reported pass count.
- Prints a small table to stdout; exits 0.

**`modules/02-advanced-eval/fscore-classification/README.md`** — add a note
near the top explaining the `weight: 0`/`namedScores` limitation (quoting the
docs line: *"each named score...is already normalized as a weighted
average"*) and that this is why the lesson computes P/R/F1 via a companion
script rather than promptfoo's built-in `derivedMetrics`. Update the "run it"
instructions to:
```bash
npx promptfoo@latest eval -c promptfooconfig.yaml -o results.json
node scripts/compute-fscore.js results.json
```
The existing TP/FP/FN/precision/recall/F1 conceptual explanation is otherwise
unchanged — the concepts are still correct, only the computation mechanism
changes.

### 3. Repo-root doc callout

**`CLAUDE.md`** — add one short paragraph (placed near the "run commands"
guidance): always run `npx promptfoo eval` from the repo root; `cd`ing into a
nested module/lesson directory first breaks `.env` discovery (dotenv looks in
the current working directory) and produces a bare `401` with no
config-level error to explain it. Every module README's documented run
command already does this correctly (`-c modules/.../promptfooconfig.yaml`
from repo root) — this callout just makes the *reason* explicit.

## Error handling

- `compute-fscore.js` must not crash on a single malformed model response —
  catch the `JSON.parse` and treat that row as a non-match for its true
  label, same as a genuinely wrong classification would be treated.
- Divide-by-zero in precision/recall/F1 (e.g., zero predicted positives)
  prints `"N/A"`, not `NaN` or a thrown error.

## Verification

- Both word-count-fixed configs run live with 0 errors and the length
  assertion passes/fails based on an actual `split(/\s+/).length`
  computation, not grader judgment.
- `fscore-classification`'s trimmed config runs live with 0 errors (just the
  `accuracy` assertion, matching what already worked).
- `compute-fscore.js` run against that eval's `-o` output produces
  precision/recall/F1 matching hand-computed values from the known label
  distribution in `tests/labeled.csv` (2 true `safe_refusal` rows out of 6 —
  a 100%-accurate classifier should yield precision=1.0, recall=1.0, f1=1.0).
- `preflight.sh`'s keyless config-resolution check still passes (the script
  file isn't a `file://` prompt/test reference preflight tracks, so no change
  needed there).

## Delivery

Lands as additional commits on `consolidate-curriculum` (PR #9, still open),
alongside or after the rate-limit-trim spec's commits — pushing remains a
separate, explicit confirmation step.
