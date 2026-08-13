# Assert-sets and budgets

> **Day 4** · [session index](../../../days/04-metrics-and-model-graded.md)

`assert-set` with a `threshold` (OR semantics), plus a latency budget. `type: cost` is
commented out — Groq returns no cost field, so it **errors** rather than fails.

```bash
npx promptfoo@latest eval -c modules/02-advanced-eval/assert-sets-and-budgets/promptfooconfig.yaml
```

Always run from the repo root so `.env` is discovered.
