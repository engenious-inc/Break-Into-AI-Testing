# Day 2 — Promptfoo basics: assertions

The smallest complete loop: a prompt, a provider, and an assertion that can fail.

## Run this

```bash
npx promptfoo@latest eval -c modules/00-promptfoo-basics/03-assertions/contains/promptfooconfig.yaml
npx promptfoo@latest view
```

Then work through the rest in order.

## Read this — five lessons, deterministic first

| Lesson | What it teaches |
|---|---|
| [`03-assertions/contains/`](../modules/00-promptfoo-basics/03-assertions/contains/) | substring checks — the cheapest assertion that works |
| [`03-assertions/regex/`](../modules/00-promptfoo-basics/03-assertions/regex/) | pattern matching when `contains` is too blunt |
| [`03-assertions/llm-rubric/`](../modules/00-promptfoo-basics/03-assertions/llm-rubric/) | a model grading prose — your first non-deterministic check |
| [`03-assertions/factuality/`](../modules/00-promptfoo-basics/03-assertions/factuality/) | grading against a reference answer |
| [`03-assertions/answer-relevance/`](../modules/00-promptfoo-basics/03-assertions/answer-relevance/) | needs `OPENAI_API_KEY` for embeddings — **optional**, skip it if you do not have one |

Do the deterministic ones first. When you reach `llm-rubric` you are paying for a second
model call on every case, and that changes how you think about suite size.

## Exercise

Take the three prompts you wrote for Day 1's homework and turn them into a real suite:
one `promptfooconfig.yaml`, one tests file, at least one deterministic assertion and one
model-graded one per case.
