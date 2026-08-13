# Prompts 4/4 — File-based

> **Day 3** · [session index](../../../../days/03-prompt-engineering-and-local-models.md)

Prompts loaded with `file://`. Paths resolve relative to **this config**, not the
repo root — count the `../` carefully. Still run the eval from the repo root so `.env`
is found.

```bash
npx promptfoo@latest eval -c modules/00-promptfoo-basics/01-prompts/file-based/promptfooconfig.yaml
```
