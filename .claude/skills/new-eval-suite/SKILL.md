---
name: new-eval-suite
description: Scaffold a new Promptfoo triplet (prompt reference + tests file + config) for a workshop lesson or bot, wired to the Groq default providers. Use when the user says "new suite", "scaffold a lesson", "add an eval".
---

# new-eval-suite

Given a suite name `<name>` and a target prompt (default `prompts/mybot.txt`):

1. Copy `templates/tests.template.yaml` → `tests/<name>.yaml`.
2. Copy `templates/promptfooconfig.template.yaml` → `promptfooconfig.<name>.yaml`,
   replacing `__PROMPT__` with the prompt path, `__TESTS__` with `tests/<name>.yaml`,
   and the `description:` placeholder with a real one-line suite description.
3. Tell the user to run: `npx promptfoo@latest eval -c promptfooconfig.<name>.yaml`.

The template already includes the Groq default provider block (matching `CLAUDE.md`'s convention). Do not add paid providers unless asked.
