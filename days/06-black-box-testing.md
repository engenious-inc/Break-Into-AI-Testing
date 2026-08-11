# Day 6 — Black box testing

Every other session hands you the rules. Tonight you get a bot and nothing else, and you
work out what it will and will not do by talking to it.

## Run this

```bash
./run.sh chat onboardbot    # .\run.ps1 chat onboardbot on Windows
```

It is already in the repo you cloned on Day 1 — no install, no new key.

```
/reset          start a fresh conversation (same bot, no memory)
/save notes.txt write the transcript to a file
/quit           leave
```

## The one rule

**Do not open `prompts/onboardbot.txt`.** It is right there and it would take ten seconds.
The entire skill being practised tonight is inferring rules from behaviour, which is the
position you are in with every third-party model, every vendor API, and most internal
services. Reading the prompt is not cheating the exercise — it is skipping it.

## Where to start

Map before you attack. You cannot break a rule you have not found.

1. **What does it cover?** Ask what it can help with. Ask it to list its topics.
2. **Where does it stop?** Find a question it refuses. Note the exact wording.
3. **Why does it stop?** Is that refusal about the topic, or about you?
4. **Then push.** Only once you have a hypothesis worth testing.

## What tonight covers

- Exploratory technique: information gathering, following a refusal, changing one variable
- Jailbreak patterns: role impersonation, hypothetical framing, encoded asks
- Inconsistency testing — asking the same thing several ways and comparing the answers
- Using AI to test AI, and where that stops helping
- Writing the bug up: description, steps to reproduce, expected vs actual
- Factuality vs hallucination, defense in depth, context window exploitation
- Pass/fail rates as a business decision, and when AI is not the answer at all

## Bring back

At least one written-up finding. Steps to reproduce, what you expected, what happened, and
**how many times out of how many attempts** — this bot is not deterministic and "it
happened once" is a different bug from "it happens every time".

`/save` before you leave the breakout. Findings die in scrollback.

You will need the finding on Day 7, where the same discipline gets pointed at an app whose
internals you *can* read — and on Day 8, where severity decides whether something ships.

## Why there is no suite tonight

Days 5, 7 and 8 give you assertions to write. Tonight there are none, on purpose. A suite
encodes what you already believe; exploration is how you find out that belief was wrong.
Day 7 hands you the same discipline pointed at an app you *can* read.
