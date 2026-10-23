# Assert-sets and budgets

> **Day 4** · [session index](../../../days/04-metrics-and-model-graded.md)

`assert-set` with a `threshold` (OR semantics), plus a latency budget. `type: cost` is
commented out — Groq returns no cost field by default, so it **errors** rather than fails.

**Free cost-budget demo (no paid key):** set synthetic `inputCost` / `outputCost` on the
Groq provider (see comments in `promptfooconfig.yaml`), uncomment the `type: cost`
assert, then:

```bash
npx promptfoo@latest eval -c modules/02-advanced-eval/assert-sets-and-budgets/promptfooconfig.yaml --no-cache
```

Promptfoo multiplies those rates by Groq's token counts. You are not billed — the rates
are invented so the assertion has a number. Tighten `threshold` (or raise the rates) to
force a fail; loosen them to pass.

Default (latency-only) run:

```bash
npx promptfoo@latest eval -c modules/02-advanced-eval/assert-sets-and-budgets/promptfooconfig.yaml
```

Always run from the repo root so `.env` is discovered.
