# Day 9 — Observability (Agenta & Arato)

What Day 8's suites look like once they leave the laptop: real OTLP spans into Agenta and
Arato. Career / LinkedIn is **[Day 10](10-linkedin-flywheel.md)** (Igor only) — not tonight.

## Run this

```bash
./run.sh payflow-serve                                   # terminal 1 — leave it running

# terminal 2 — TutorBot: a real OTLP span per LLM call, one per subject
npx promptfoo@latest eval -c modules/02-advanced-eval/observability/promptfooconfig.yaml
```

Then, with the same keys and PayFlow still up, **re-run a Day 8 suite as traffic**
(commands live on [Day 8](08-advanced-redteam-sdlc.md) — exposure is the usual one;
poisoning and redteam fill other session drawers). Those configs are claimed by Day 8;
tonight you only need them as load generators.

Optional one-liner (same mechanism, different session id):

```bash
curl -s http://localhost:8000/chat \
  -H 'Content-Type: application/json' \
  -d '{"message":"What is PayFlow?","session_id":"day9-otel","user_role":"student"}'
```

**Want to see them land somewhere?** [Agenta](https://agenta.ai) cloud is free and speaks
OTLP. Sign up (US or EU), create a **project** API key, then in `.env`:

```env
AGENTA_API_KEY=...
# AGENTA_HOST=https://eu.cloud.agenta.ai   # only if your project URL is eu.cloud
```

The exporter defaults to `https://us.cloud.agenta.ai`. US and EU are separate — a key
from one region 401s on the other. Match `AGENTA_HOST` to the host in your project URL.

Three TutorBot traces appear, one per subject — and they share one `ag.session.id`,
so **Sessions** shows a single conversation with three turns. There is no
create-session API; Agenta groups at query time on that exact attribute.

With PayFlow up and `AGENTA_API_KEY` in `.env`, the Day 8 exposure suite posts five
`payflow.chat` parents into **Sessions → `exposure-session`** with `ag.user.id=student`.
Poisoning (with `PAYFLOW_POISON=1`) fills `poisoning-session`; redteam uses
`redteam-session` if you have the time. Each case is one trace; the suite's `session_id`
is copied onto `ag.session.id` — bare `session_id` is still on the span (grep it) but
does not populate Sessions.

Open a TutorBot span and look for `tutor.subject`; open a PayFlow span and look
for `ag.session.id` / `route.orchestrator_decision`. That is the difference between
a span you can read and a span you can *query*.

Without a key the lesson still runs and tells you it skipped the POST. The span is real
either way; only the network call is optional.

### Agenta: observability + evaluations

Same project, two loops — teach both in the Agenta UI after the Day 8 exposure suite
lands traces.

**Loop A (observability):** Observability → Sessions → `exposure-session` or
`# demo-exposure-map`. Expand `payflow.chat` and its `llm.chat.completion`
children; filter Traces on root span name and `route.guard_status`.

**Bridge (trace → test set):** On a trace, **Add to testset** → create
`day9-payflow-exposure` → map `ag.data.inputs` → inputs and `output.value` →
outputs → **Commit**. That row is a Promptfoo case captured from production
traffic.

**Loop B (evaluation):** Evaluation → Evaluation runs → open *Demo: baseline vs
budget-flash* (or **New Evaluation → Auto evaluation** on `support-ticket-triage` +
`support-tickets-demo`). PayFlow batch regression stays in Promptfoo; Agenta evals
need a prompt variant hosted in the project.

Full click-path and session ids:
[`observability/README.md`](../modules/02-advanced-eval/observability/README.md#agenta-observability-and-evaluations-two-loops).

### Arato Observe

Arato is the **dashboard / topology** beat — same OTLP bytes as Agenta, different
UI. Your `.env` needs **both** `OTEL_EXPORTER_OTLP_ENDPOINT` and `ARATO_API_KEY`
from **Observe → Monitor With Arato** (see `.env.example`). With Agenta also set,
each span POSTs twice and the terminal shows `[arato] OTLP 200` and `[agenta] OTLP
200`.

```bash
# TutorBot — three traces, tutor.subject / tutor.level on each span
npx promptfoo@latest eval -c modules/02-advanced-eval/observability/promptfooconfig.yaml
```

In Arato, **build at least one dashboard panel** (latency or tokens by
`tutor.subject`) — empty Observe after a `200` is the lesson: ingest ≠ visible.
The **Release Testing** dashboard needs **dashboard validations** attached or the
threads **Evals** column stays empty — OTLP `evaluations.*` attributes are
metadata only. The class set is `day8-mentions-payflow` (Output contains
`PayFlow`), `day8-no-debug-leak` (Output notContains `debug`), and
`day8-response-nonempty` (Output regex `.+`). Click a thread ID to fill the
topology canvas. See the **Arato evals** section in the observability README.
For a **visible eval grid** in Studio, use **Experiment → Try demo notebook**
(step 7/7 Run Results). Then re-run the Day 8 exposure suite and compare PayFlow's
`payflow.chat` waterfall in Agenta to Arato session replay / topology.

Full Arato click-path:
[`observability/README.md`](../modules/02-advanced-eval/observability/README.md#arato-observe-dashboards-and-topology-10-min).

## Pass/fail tonight

The observability lesson is **ordinary** — pass means good. The Day 8 suites you may
re-run as traffic stay inverted (exposure, poisoning, redteam).

## Read this

- [`observability/`](../modules/02-advanced-eval/observability/) — genuine wire-compatible
  OTLP, hand-encoded in ~70 lines because this repo installs nothing. Read `otlp.mjs` and
  the format stops being a black box.

> `observability/` lives under `modules/02-advanced-eval/` for structural reasons — it is
> shaped like a Module 2 lesson. It is **Day 9** material, not Day 4.

## One thing worth arguing about

**Telemetry is a place data leaks.** The observability lesson ships the prompt's SHA-256,
never the prompt — and PayFlow's `payflow.chat` export uses the same switch. You lose
debuggability and gain a defensible export. That is a trade somebody has to decide
deliberately.

## Bring to Day 10

One screenshot or session id of a span you can talk about in an interview (what failed,
what the trace showed, what you would gate a release on).
