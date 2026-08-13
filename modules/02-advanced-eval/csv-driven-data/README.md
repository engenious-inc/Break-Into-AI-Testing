# CSV-driven test data

> **Day 4** · [session index](../../../days/04-metrics-and-model-graded.md)
Promptfoo can load `tests:` from CSV. Special columns:
- `__expected` (one assertion), `__expected1/2/3` (several), written as `type: value` in the cell
- `__metadata:key` (filterable), `__metadata:tags[]` (array), `__description`, `__prefix`, `__suffix`, `__threshold`

## Watch out for questions with more than one right answer

`"Name a primary color."` used to assert `icontains: red`. It failed the first time the
model answered **"Blue."** — which is also a primary color. The test was underspecified,
not the model wrong, and a student hitting it reasonably assumes they broke something.

It now asserts `icontains-any: red, blue, yellow`, which is both correct and a more
useful assertion type to know. When you write CSV cases at volume, this is the failure
mode to watch for: a question you *meant* to have one answer, phrased so it has three.

Run with metadata filtering (from the repo root — `cd`-ing into this folder breaks
`.env` discovery):
```bash
npx promptfoo@latest eval -c modules/02-advanced-eval/csv-driven-data/promptfooconfig.yaml --filter-metadata category=math
```
(edit the `tests:` line in that config to point at `tests/with_metadata.csv` first).
