# Providers 1/2 — Configuration

> **Day 3** · [session index](../../../../days/03-prompt-engineering-and-local-models.md)

Groq 3-model matrix with temperature / max_tokens tuning. **No assertions on purpose** —
compare with [`comparing-models/`](../comparing-models/), which runs the same prompt and
fails 2 of 6 because it checks for a chain-of-thought leak. A green run here means
"the providers answered," not "the answers are good."

```bash
npx promptfoo@latest eval -c modules/00-promptfoo-basics/02-providers/configuration/promptfooconfig.yaml
npx promptfoo@latest view
```

Always run from the repo root so `.env` is discovered.
