# Module 2 — Advanced Evaluation

Beyond pass/fail: weighted assertions, named metrics, assertion sets, budgets,
exact-vs-fuzzy matching, CSV-driven data, F-score classification, temperature
sensitivity, and a hands-on debugging track. Defaults use Groq; cost budgets and
embedding-based checks are opt-in (need a paid key), and are marked per lesson.

Run any lesson: `npx promptfoo@latest eval -c modules/02-advanced-eval/<path>/promptfooconfig.yaml`

## Lessons
- `weights-and-metrics/` — multiple assertions with `weight:` + named `metric:` + test `threshold:`
- `assert-sets-and-budgets/` — `assert-set`, OR via `threshold: 0.5`, latency budget (+ optional cost)
- `exact-vs-fuzzy/` — `equals` + `icontains` (+ optional embedding `similar`)
- `csv-driven-data/` — `tests: file://tests/*.csv`, `__expected*` / `__metadata:*` columns
- `fscore-classification/` — TP/FP/FN counters + `derivedMetrics` precision/recall/F1
- `temperature-and-personas/` — same providers at temp 0.7 vs 1; empathetic vs not
- `debugger/` — fix intentionally-broken configs (`1_basic → 2_moderate → 3_advance`)

> Maps to `how-to-test-ai` day-03-promptfoo-advanced.
