# CSV-driven test data
Promptfoo can load `tests:` from CSV. Special columns:
- `__expected` (one assertion), `__expected1/2/3` (several), written as `type: value` in the cell
- `__metadata:key` (filterable), `__metadata:tags[]` (array), `__description`, `__prefix`, `__suffix`, `__threshold`

Run with metadata filtering:
`npx promptfoo@latest eval -c promptfooconfig.yaml --filter-metadata category=math`
(edit the `tests:` line to point at `tests/with_metadata.csv` first).
