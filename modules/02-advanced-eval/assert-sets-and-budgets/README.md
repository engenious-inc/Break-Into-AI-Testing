# Assert-sets and budgets

> **Day 4** · [session index](../../../days/04-metrics-and-model-graded.md)

`assert-set` with a `threshold` (OR semantics), plus latency and cost budgets.

**Model + cost comparison (no paid key):** `qwen-3.8-27b` and `gpt-oss-120b` share the
same synthetic `inputCost` / `outputCost` rates. Promptfoo multiplies those by each
model's token counts — you are not billed. Compare answers, latency, and the cost
column side by side; use `--no-cache` so rates are applied fresh:

```bash
npx promptfoo@latest eval -c modules/02-advanced-eval/assert-sets-and-budgets/promptfooconfig.yaml --no-cache
```

Tighten `threshold` (or raise the rates) to force a cost fail; loosen them to pass.
`type: cost` is a top-level assert (not inside the latency/length assert-set), so
over-budget fails the whole test.

Always run from the repo root so `.env` is discovered.
