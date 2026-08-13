# Assertions 5/5 — answer-relevance (optional)

> **Day 2** · [session index](../../../../days/02-promptfoo-basics.md)

Embedding-based `answer-relevance`. Uses local `transformers:` embeddings (no OpenAI
key). Off the default free-tier path only because the first run downloads a model.

```bash
npx promptfoo@latest eval -c modules/00-promptfoo-basics/03-assertions/answer-relevance/promptfooconfig.yaml
```

Always run from the repo root so `.env` is discovered.
