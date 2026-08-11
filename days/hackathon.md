# Hackathon — Break → Fix → Build

Not a session. Three challenges, every team does all three, scores sum.

## Run this

```bash
./run.sh mybot        # your Challenge 3 build-it bot
```

## Read this

[`docs/04-challenges.md`](../docs/04-challenges.md) — the rules and scoring.

## The one thing to protect

`prompts/mybot.txt` is **your** Challenge 3 slot. Nothing else in the repo writes to it,
and no lesson expects a particular thing inside it. If a Day 3 exercise tells you to
scaffold a prompt, use `prompts/reverse.txt` instead — overwriting `mybot.txt` costs you
hackathon work.

`promptfooconfig.mybot.yaml` is excluded from the repo's smoke check for the same reason:
your bot's results are not a signal about repo health.
