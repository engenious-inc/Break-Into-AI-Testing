# Day 1 — AI fundamentals & environment setup

Getting a working environment, and the vocabulary for why AI is hard to test.

## Run this

```bash
./setup.sh          # macOS/Linux — prompts for your free Groq key
./preflight.sh      # confirms node, npx, the key, and network
```

Windows: `setup.ps1` and `preflight.ps1`, same order.

Do not move on until preflight is green. Every later session assumes it.

## Read this

- [`docs/01-quickstart.md`](../docs/01-quickstart.md) — the three-minute version
- [`README.md`](../README.md) — the seven-item taxonomy of what makes AI hard to test
- [`docs/03-troubleshooting.md`](../docs/03-troubleshooting.md) — when setup fights you

## Homework

Pick one of the seven taxonomy items and design three test prompts for it. You will turn
these into a real suite on Day 2, so write them down somewhere you can find again.

## No config to run yet

Day 1 has no `promptfooconfig` of its own — the point is a working machine and shared
vocabulary. The first suite you run is Day 2's.
