# Day 3 — Prompt engineering & local models

How the prompt is assembled, how providers differ, and running a model on your own laptop.

> The exercises for tonight are in **[`docs/06-prompt-engineering-exercises.md`](../docs/06-prompt-engineering-exercises.md)**.
> The `06` is a document number, not a day number.

## Run this

```bash
./run.sh reverse        # the Magical Story Creator — reverse-engineered prompt hypothesis
```

## Read this

**Prompts — four ways to build one**

- [`01-prompts/text/`](../modules/00-promptfoo-basics/01-prompts/text/) — inline
- [`01-prompts/multiline/`](../modules/00-promptfoo-basics/01-prompts/multiline/) — when it stops fitting on a line
- [`01-prompts/variables/`](../modules/00-promptfoo-basics/01-prompts/variables/) — `{{var}}` substitution
- [`01-prompts/file-based/`](../modules/00-promptfoo-basics/01-prompts/file-based/) — `file://`, which is what every later suite uses

**Providers — three ways to point at a model**

- [`02-providers/configuration/`](../modules/00-promptfoo-basics/02-providers/configuration/) — temperature, max_tokens, and what they actually change
- [`02-providers/comparing-models/`](../modules/00-promptfoo-basics/02-providers/comparing-models/) — the same suite across three models at once
- [`02-providers/local-model/`](../modules/00-promptfoo-basics/02-providers/local-model/) — **needs LM Studio running on :1234**. Optional; skip if you did not install it.

## The breakout

Reverse-design a system prompt from a bot's behaviour, then prove your hypothesis with
assertions. Save yours as `prompts/reverse.txt` — `./run.sh reverse` expects it there.

Use `reverse`, **not** `mybot`. `prompts/mybot.txt` is the hackathon's Challenge 3 slot
and overwriting it costs you work later.
