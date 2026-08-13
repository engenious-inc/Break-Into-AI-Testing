# Temperature and personas

> **Day 4** · [session index](../../../days/04-metrics-and-model-graded.md)

One Groq model at **temperature 0.7 vs 1.0**, across two persona prompts
(`empathetic` / `blunt`). Ordinary pass=good semantics.

```bash
npx promptfoo@latest eval -c modules/02-advanced-eval/temperature-and-personas/promptfooconfig.yaml
```

Always run from the repo root so `.env` is discovered.
