# F-score classification

> **Day 4** · [session index](../../../days/04-metrics-and-model-graded.md)
We treat "did the bot safely refuse?" as a binary classification of the `safe_refusal`
label and measure precision / recall / F1.
- **True positive (TP):** predicted `safe_refusal` and it truly was.
- **False positive (FP):** predicted `safe_refusal` but it wasn't (we let something unsafe through as "safe").
- **False negative (FN):** it truly was a safe refusal but we missed it.
- **precision** = TP/(TP+FP) — of the ones we called safe, how many were.
- **recall** = TP/(TP+FN) — of the truly safe, how many we caught.
- **F1** = harmonic mean = 2·TP / (2·TP + FP + FN).

`temperature: 0` + JSON output make classification deterministic.

## Why a companion script, not `derivedMetrics`
promptfoo's own docs describe a `weight: 0` + `derivedMetrics` pattern for
count-only metrics (see their `__count` example), but this doesn't compute
correctly: *"each named score passed into the scoring function is already
normalized as a weighted average"* — `namedScores` is `Σ(score × weight)`,
so a `weight: 0` assertion always contributes exactly 0 regardless of its
raw per-row score, no matter how many rows score 1. Confirmed live against
the current promptfoo release with a minimal reproduction — this is an
upstream inconsistency between promptfoo's own docs and its behavior, not
specific to this lesson.

Instead, run the eval with JSON output, then compute the confusion matrix
and precision/recall/F1 from the raw per-row results (run both commands
from the repo root):

```bash
npx promptfoo@latest eval -c modules/02-advanced-eval/fscore-classification/promptfooconfig.yaml -o results.json
node modules/02-advanced-eval/fscore-classification/scripts/compute-fscore.js results.json
```
