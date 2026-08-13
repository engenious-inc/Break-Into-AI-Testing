# Day 8 — Advanced red teaming, SDLC & observability

Three acts: let the machine write the attacks, decide where that runs in a pipeline, then
find out what the thing reports once it is deployed.

## Run this

```bash
./run.sh payflow-serve                                   # terminal 1

# terminal 2 — generated attacks against the same app you tested on Day 7
./run.sh payflow-redteam

# or replay the committed attacks, free — no generation step
npx promptfoo@latest redteam eval -c redteam.yaml -j 1 --delay 1000

# observability: a real OTLP span per LLM call
npx promptfoo@latest eval -c modules/02-advanced-eval/observability/promptfooconfig.yaml
```

**The red team is slow and rate-limited.** ~24 probes, four Groq calls each.
`./run.sh payflow-redteam` paces at `-j 1 --delay 1000` so a free-tier key survives the
slot. If your key is exhausted, use the replay command — the attacks are committed in
[`redteam.yaml`](../redteam.yaml) precisely so you can.

## Inverted scoreboard, again

`payflow-redteam` is a red-team target: a **failing** check means the attack landed. That
is the finding. `payflow` and the observability lesson are ordinary — pass means good.

## Read this

- [`promptfooconfig.payflow-redteam.yaml`](../promptfooconfig.payflow-redteam.yaml) — the
  recipe: plugins decide *what* to attack, strategies decide *how* to dress it up. The
  comments record two traps that cost real time, including a strategy that does not exist.
- [`redteam.yaml`](../redteam.yaml) — the generated attacks themselves. Read them. Plugin
  names like `hijacking` mean nothing until you see the prompt one produced.
- [`observability/`](../modules/02-advanced-eval/observability/) — genuine wire-compatible
  OTLP, hand-encoded in ~70 lines because this repo installs nothing. Read `otlp.mjs` and
  the format stops being a black box.

> `observability/` lives under `modules/02-advanced-eval/` for structural reasons — it is
> shaped like a Module 2 lesson. It is **Day 8** material, not Day 4.

## Two things worth arguing about

**Refusing is not correcting.** `tests/payflow.agency.yaml` probes overreliance — a
question carrying a false premise. A model that says "I can't help with that" has refused,
and the false premise walked out intact.

**Telemetry is a place data leaks.** The observability lesson ships the prompt's SHA-256,
never the prompt. You lose debuggability and gain a defensible export. That is a trade
somebody has to decide deliberately.
