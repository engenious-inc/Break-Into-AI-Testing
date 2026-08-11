# Day 6 — Black box testing

**Tonight's application is not in this repo.** Do not go looking for it here; there is
nothing to find, and that is expected rather than a mistake on your part.

## Get the app

```bash
git clone https://github.com/Jaimeman84/financial-chat-bot.git
cd financial-chat-bot
```

Open it in VS Code and follow the session's setup steps. You are testing it **black box** —
as an outsider who has not read the source. Resist opening the code first; the whole point
is what you can learn without it.

## What tonight covers

- Exploratory technique: information gathering, following a refusal, changing one variable
- Jailbreak patterns: role impersonation, hypothetical framing, encoded asks
- Inconsistency testing — asking the same thing several ways and comparing the answers
- Using AI to test AI, and where that stops helping
- Writing the bug up: description, steps to reproduce, expected vs actual
- Factuality vs hallucination, defense in depth, context window exploitation
- Pass/fail rates as a business decision, and when AI is not the answer at all

## Bring back

At least one written-up finding. You will need it on Day 7, where the same discipline gets
pointed at an app whose internals you *can* read — and on Day 8, where severity decides
whether something ships.

## Why this repo has nothing for tonight

Days 5, 7 and 8 test applications that live here. Day 6 deliberately uses an outside app so
you have to work without the source, the corpus, or the system prompt. Everything you know
about the target tonight, you learned by poking it.
