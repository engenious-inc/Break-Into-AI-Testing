# Module 2 — Advanced Evaluation

Beyond pass/fail: weighted assertions, named metrics, assertion sets, budgets,
exact-vs-fuzzy matching, CSV-driven data, F-score classification, temperature
sensitivity, and a hands-on debugging track. Defaults use Groq; cost budgets and
embedding-based checks are opt-in (need a paid key), and are marked per lesson.

Run any lesson: `npx promptfoo@latest eval -c modules/02-advanced-eval/<path>/promptfooconfig.yaml`

## Lessons
- `weights-and-metrics/` — multiple assertions with `weight:` + named `metric:` + test
  `threshold:`. Its README documents the verified threshold rule (`>=`, not `>`) and why
  6/9 does not clear 0.67.
- `assert-sets-and-budgets/` — `assert-set`, OR via `threshold: 0.5`, latency budget (+ optional cost)
- `exact-vs-fuzzy/` — `equals` + `icontains` (+ optional embedding `similar`)
- `csv-driven-data/` — `tests: file://tests/*.csv`, `__expected*` / `__metadata:*` columns
- `fscore-classification/` — TP/FP/FN from the eval's JSON output via a `compute-fscore.js` companion script (promptfoo's `derivedMetrics`/`weight:0` can't compute it — see the lesson README)
- `temperature-and-personas/` — same providers at temp 0.7 vs 1; empathetic vs not
- `debugger/` — fix intentionally-broken configs (`1_basic → 2_moderate → 3_advance`)
- `observability/` — real Arato.ai REST logging + hand-rolled OTel-shaped tracing via a custom zero-dependency provider; shows what production telemetry adds beyond eval-time quality checks

> Maps to `how-to-test-ai` day-03-promptfoo-advanced, and to the August cohort's
> **Day 4 (Model-Graded Assertions & Metrics)**. Exercises are written up in
> [`docs/07-metrics-exercises.md`](../../docs/07-metrics-exercises.md).
