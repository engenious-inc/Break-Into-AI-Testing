# Day 4 — Metrics & model-graded assertions

The heaviest reading night in the course: eight lessons plus a debugger. Pace accordingly.

> The exercises are in **[`docs/07-metrics-exercises.md`](../docs/07-metrics-exercises.md)**.
> That `07` is a document number — this is Day **4**. Day 7 is
> [`07-testing-an-application.md`](07-testing-an-application.md).

## Run this

```bash
npx promptfoo@latest eval -c modules/02-advanced-eval/weights-and-metrics/promptfooconfig.yaml
npx promptfoo@latest view
```

## Read this

| Lesson | What it teaches |
|---|---|
| [`weights-and-metrics/`](../modules/02-advanced-eval/weights-and-metrics/) | `weight:` and named `metric:` — not every assertion matters equally |
| [`assert-sets-and-budgets/`](../modules/02-advanced-eval/assert-sets-and-budgets/) | `assert-set`, OR via `threshold`, latency budgets |
| [`exact-vs-fuzzy/`](../modules/02-advanced-eval/exact-vs-fuzzy/) | `equals` vs `icontains` vs embedding `similar` |
| [`structured-outputs/`](../modules/02-advanced-eval/structured-outputs/) | JSON Schema via `is-json` / `contains-json`, plus `options.transform` |
| [`csv-driven-data/`](../modules/02-advanced-eval/csv-driven-data/) | tests from a CSV, with `__expected` columns |
| [`fscore-classification/`](../modules/02-advanced-eval/fscore-classification/) | TP/FP/FN from the eval's JSON — Promptfoo cannot compute this for you |
| [`temperature-and-personas/`](../modules/02-advanced-eval/temperature-and-personas/) | the same provider at temp 0.7 vs 1.0 |
| [`debugger/`](../modules/02-advanced-eval/debugger/) | three intentionally-broken configs: `1_basic` → `2_moderate` → `3_advance` |

**The debugger stages are supposed to fail.** They are the exercise. If one runs clean,
something is wrong with the lesson, not with you.

## Not tonight

One lesson in this module — the observability one — is **Day 8** material. It needs a
running service to instrument, which nothing before Day 7 has. Skip it tonight; Day 8
links it directly.
