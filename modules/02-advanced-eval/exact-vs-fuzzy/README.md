# Exact vs fuzzy matching

> **Day 4** · [session index](../../../days/04-metrics-and-model-graded.md)

`icontains` (fuzzy) vs `equals` (exact, brittle — shown commented) vs embedding
`similar` (needs `OPENAI_API_KEY`, opt-in).

```bash
npx promptfoo@latest eval -c modules/02-advanced-eval/exact-vs-fuzzy/promptfooconfig.yaml
```

Always run from the repo root so `.env` is discovered.
