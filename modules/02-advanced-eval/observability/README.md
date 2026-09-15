# Observability: real OTLP tracing into Arato.ai

> **Day 8** · [session index](../../../days/08-advanced-redteam-sdlc-observability.md) — it lives in Module 2 because it is *shaped* like a Module 2 lesson, not because it is taught with them

> **This is a Day 8 lesson**, taught with Arato.ai and Agenta.ai — not part of the
> Day 4 metrics exercises. It lives in Module 2 because it is shaped like a Module 2
> lesson (single provider, ordinary pass=good assertions), not because it is taught
> alongside them.

Every other lesson in this module asks "did the model answer well?" This one
asks a different question: once a system like this is *deployed*, what is it
doing — how slow, how many tokens, which requests are erroring? That's
observability, and the standard for it is OpenTelemetry (OTel).

## What's real here

- **Trace/span IDs, latency, token counts** — genuinely measured from a real
  Groq API call to **TutorBot** (`prompts/tutorbot.txt`), not simulated.
- **The prompt hash** — a real SHA-256 of the student's question, computed at
  request time. It hashes the *question*, not the whole rendered prompt, so it
  stays stable when only `subject` or `level` changes.
- **`tutor.subject` and `tutor.level`** — custom span attributes taken from each
  test case's vars. They are the reason this lesson traces a tutor rather than a
  bare question: a span you cannot slice is a latency number, and *"is Physics
  slower than Algebra?"* is the first thing anyone actually asks in production.
- **`ag.session.id` and `ag.user.id`** — the only attribute names Agenta's
  Sessions view indexes. One eval process shares one session id, so three
  TutorBot traces become one conversation. PayFlow maps the request `session_id`
  onto the same key.
- **The span leaving the process** — genuine, wire-compatible OTLP over HTTP,
  POSTed to [Arato.ai](https://www.arato.ai) and/or [Agenta](https://agenta.ai)
  if you set their keys in `.env` (all optional — sample output below shows what
  happens either way).

## No SDK, still real OTLP

This lesson has no dependencies to install, and that is deliberate: `CLAUDE.md`'s rule
is no root `package.json` — Promptfoo is always run via `npx promptfoo@latest`, never
installed — so `@opentelemetry/exporter-trace-otlp-proto` is not available here. Rather
than fake it, `otlp.mjs` hand-encodes the protobuf — about 70 lines covering the four
wire types this one message needs. What goes over the network is the same bytes the
official SDK would send.

(One lesson does opt out: `modules/03-app-testing/mcp-local/` carries its own
`package.json` for the MCP SDK, installed per-folder. It is the exception, and it costs
that lesson a setup step this one does not have.)

That is worth understanding rather than skipping past. OTLP is not magic: a span
is a protobuf message with a trace ID, a span ID, two timestamps, and a bag of
attributes. Read `otlp.mjs` and the format stops being a black box.

Two things Arato is strict about, both learned by probing the live endpoint:

1. **It only speaks protobuf.** Send OTLP/JSON and you get
   `500 {"error": "invalid wire type 4 at offset 236"}` — it tries to parse your
   JSON as protobuf and fails partway in.
2. **It dispatches on the instrumentation scope name.** The scope must start with
   `openinference.instrumentation.` or you get
   `400 {"error": "Unknown span type: <your-scope>"}`. `langsmith`, `agno`, and
   `pydantic-ai` are all rejected; this lesson uses
   `openinference.instrumentation.openai`.

Attribute names follow the OpenInference conventions (`llm.model_name`,
`llm.token_count.prompt`, `llm.input_messages.0.message.content`, …) — those are
what Arato reads to populate its UI.

## Why privacy is part of this, not an afterthought

`provider.mjs` never logs the raw prompt text — only its SHA-256 hash. This
mirrors a real production pattern: telemetry is itself a place user data can
leak, so it gets the same "don't log what you don't need" treatment as any
other data sink.

## Run it

```bash
npx promptfoo@latest eval -c modules/02-advanced-eval/observability/promptfooconfig.yaml
```

Sample output (Arato unset):
```
{
  "span": "llm.chat.completion",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "model": "qwen/qwen3.8-27b",
  "duration_ms": 412,
  "tokens": { "prompt_tokens": 12, "completion_tokens": 34, "total_tokens": 46 },
  "prompt.sha256": "8f3a2b1c..."
}
[otlp] skipped — set ARATO_API_KEY (+OTEL_EXPORTER_OTLP_ENDPOINT) or AGENTA_API_KEY to export for real
```

With a real Arato account, take both values from **Observe → your dashboard →
"Monitor With Arato"** and add them to `.env`:

```env
OTEL_EXPORTER_OTLP_ENDPOINT=https://api.arato.ai/opentelemetry/<your-project>
ARATO_API_KEY=ar-...
```

The endpoint already contains your project slug. Don't append `/v1/traces` —
`provider.mjs` does that. The last line then becomes:

```
[arato] OTLP 200 trace_id=054d11ec990cdcf906d7d4e9af2ae647
```

### Or Agenta — same bytes, different envelope

[Agenta](https://agenta.ai) ingests the **identical protobuf**. One project-scoped
key, and `AGENTA_HOST` only if you are not on US cloud:

```env
AGENTA_API_KEY=...
# AGENTA_HOST=https://eu.cloud.agenta.ai   # only if your project URL is eu.cloud
```

The default host is `https://us.cloud.agenta.ai`. [Agenta's API](https://agenta.ai/docs/reference/api-guide/overview)
serves US and EU as separate clouds; keys do not cross regions. A 401 with
`Unauthorized` almost always means the key and host do not match — the log line
names the host it posted to.

```
[agenta] OTLP 200 host=https://us.cloud.agenta.ai trace_id=2ee37dbdf73e4cd093bb91cc05586765
```

Set both vendors and the span goes to both, encoded once. That is the lesson hiding in
this lesson: `provider.mjs` gained Agenta support in about twenty lines, and not
one of them touches how the span is built. OTLP is a standard, so adding a vendor
is a URL and an auth header — Arato wants `Bearer` at `<endpoint>/v1/traces`,
Agenta wants `ApiKey` at `<host>/api/otlp/v1/traces` ([OTLP ingest](https://agenta.ai/docs/reference/api/otlp-ingest)). Everything a vendor tells
you is proprietary about their "integration" is usually just those two lines.

**Agenta unflattens dotted attribute names.** You send `tutor.subject`; you get
back:

```json
"attributes": { "tutor": { "subject": "Mathematics", "level": "Beginner" } }
```

Read it with `POST /api/traces/query` (the old `GET /api/tracing/traces/<id>` path
is gone). This is the whole "ingested is not the same as visible" point in miniature,
with a happy ending: the value survived, but not under the key you sent. If you had
asserted on a flat `attributes["tutor.subject"]` you would have concluded the
attribute was dropped and gone looking for a bug that does not exist.

**Sessions are derived, not created.** There is no create-session endpoint. A
session is the set of traces that share `ag.session.id` — Agenta groups them at
query time. One TutorBot eval process stamps the same id on all three cases, so
**Sessions** shows one conversation with three turns. PayFlow copies the request's
`session_id` onto `ag.session.id`; curl twice with `day8-otel` and the drawer
grows. Users are the same trap: `ag.user.id` populates the indexed column,
`user.id` does not. `session.id`, `gen_ai.conversation.id`, `ag.meta.session_id`,
and the OpenAPI top-level `session_id` field all land in the attribute blob (or
are dropped on ingest) and never appear in Sessions.

Optional, if you want the session to link back to a prompt in that project:

```env
AGENTA_APPLICATION_ID=...
AGENTA_VARIANT_ID=...
AGENTA_REVISION_ID=...
```

Those become `ag.references.application.id` (and variant / revision). Leave them
unset and the traces still group; they just will not deep-link.

Copy that `trace_id` and find it in the Agenta **Observability** view — then open
**Sessions** and find the same `ag.session.id`. **Do that at least once.** A
`200` proves the request was accepted, not that the span was stored the way you
meant — and the whole reason this lesson exists is that "it returned 200" and
"it worked" are different claims. Ingest is async: Agenta queues the protobuf
and persists it a moment later.

### Ingested is not the same as visible

Arato dashboards are **built, not automatic**. Send perfectly good spans to a
project with no dashboard querying them and you will see nothing at all — which
looks exactly like a broken integration and is not one.

That is worth sitting with for a second, because it is the whole lesson in
miniature. Three different things have to be true before a number reaches your
eyes, and they fail independently:

1. the app emits the span,
2. the backend accepts and stores it,
3. some view actually queries it.

"I don't see it" tells you one of the three broke, not which. This is the same
class of mistake as reading a green test suite that asserts nothing.

Build a dashboard against these — they're what `provider.mjs` sends:

| Field | Value |
|---|---|
| `service.name` | `break-into-ai-testing` (or your `OTEL_SERVICE_NAME`) |
| instrumentation scope | `openinference.instrumentation.openai` |
| span name | `llm.chat.completion` |
| `openinference.span.kind` | `LLM` |
| `llm.model_name` | `qwen/qwen3.8-27b` |
| `llm.provider` / `llm.system` | `groq` |
| `llm.token_count.prompt` / `.completion` / `.total` | integers |
| `input.value` / `output.value` | prompt/response, or their hash when `LOG_RAW_PROMPTS` is off |
| `ag.session.id` | one id per TutorBot eval process; PayFlow uses the request `session_id` |
| `ag.user.id` | `tutorbot-student`, or PayFlow's `user_role` |

### The privacy trade-off is a switch, and it has a cost

By default the message-content attributes are **not** your text — they're
`sha256:<hash> (len=N)`. That keeps the telemetry sink from becoming a copy of every
prompt your users typed.

It also means Arato's UI shows you hashes instead of conversations. That is the real
tension in production observability, and it's worth naming out loud in class: the tool is
more useful the more it knows, and more dangerous for exactly the same reason. Flip it
when you need to read the conversations back:

```env
LOG_RAW_PROMPTS=true
```

For a live demo you probably want it on — hashes make a dull dashboard. For anything
touching real user traffic, the default is the default for a reason.

## The same bytes, from the running app

The eval above instruments a custom Promptfoo provider wrapping TutorBot — that
is the "what is a span / OTLP is bytes" lesson. Act 3 of Day 8 is the deployed
app.

PayFlow's `POST /chat` emits a parent `payflow.chat` span plus one
`llm.chat.completion` child per Groq call (guard, orchestrator, answer), through
the same `otlp.mjs`. Module 1's bots still cannot: they go through Promptfoo's
built-in `groq:` provider, and there is no code of ours on that path. FinanceBot
is the twin; it is not instrumented yet.

With `./run.sh payflow-serve` running and `AGENTA_API_KEY` in `.env`, the listen
line prints `[otlp] agenta host=https://us.cloud.agenta.ai` (or `skipped` if the
key is missing). Then run a Day 8 suite — the tests are the traffic:

```bash
./run.sh payflow-exposure
```

Five `/chat` cases post five traces into **Sessions → `exposure-session`**
(`ag.user.id=student`). The GET `/health` case does not create a span. Each
`payflow.chat` parent carries `route.guard_status` and `debug.latency_ms`; children
are `llm.chat.completion` per Groq call.

Optional one-liner (same mechanism, different session id):

```bash
curl -s http://localhost:8000/chat \
  -H 'Content-Type: application/json' \
  -d '{"message":"What is PayFlow?","session_id":"day8-otel","user_role":"student"}'
```

The 200 body is unchanged. The server log grows `[agenta] OTLP 200` and a
`payflow.chat` line. In Agenta, filter on span name `payflow.chat` — that is the
app — versus TutorBot's root `llm.chat.completion`.

`debug.latency_ms` in the JSON (the [`payflow-exposure`](../../../tests/payflow.exposure.yaml)
finding) is the same number as `debug.latency_ms` on the parent span. Same leak,
two sinks. `LOG_RAW_PROMPTS` unset still hashes `input.value` / `output.value`;
the user message does not leave the process in the clear.

## Arato Observe: dashboards and topology (10 min)

[Arato Observe](https://arato.ai/observe/) is the other OTLP sink this lesson
targets. The **same protobuf bytes** go to Arato and Agenta when both are
configured — one encode in `otlp.mjs`, two POSTs in `provider.mjs` /
`telemetry.js`.

### Setup (one-time)

1. Sign up at [arato.ai](https://arato.ai/) and open **Observe**.
2. Create a project (or open your workshop project).
3. Click **Monitor With Arato** (or the OTLP setup card) and copy:
   - **OTLP endpoint** → `OTEL_EXPORTER_OTLP_ENDPOINT`
   - **API key** → `ARATO_API_KEY`
4. Add both to `.env` (do **not** append `/v1/traces` — the exporter adds it):

```env
OTEL_EXPORTER_OTLP_ENDPOINT=https://api.arato.ai/opentelemetry/<your-project>
ARATO_API_KEY=ar-...
OTEL_SERVICE_NAME=break-into-ai-testing
```

Keep `AGENTA_API_KEY` set if you want **dual export** to both vendors.

### Generate traces

**TutorBot** (three spans, one `ag.session.id`, `tutor.subject` / `tutor.level`):

```bash
npx promptfoo@latest eval -c modules/02-advanced-eval/observability/promptfooconfig.yaml
```

Look for **two** success lines per case when both backends are configured:

```
[arato] OTLP 200 host=https://api.arato.ai/opentelemetry/<project> trace_id=...
[agenta] OTLP 200 host=https://us.cloud.agenta.ai trace_id=...
```

Copy a `trace_id` from the JSON block above the OTLP lines.

**PayFlow** (parent `payflow.chat` + LLM children):

```bash
./run.sh payflow-serve          # terminal 1 — startup should log [otlp] arato host=...
./run.sh payflow-exposure       # terminal 2
```

### What to show in Arato (vs Agenta)

| | **Arato Observe** | **Agenta Observability** |
|---|---|---|
| Traces land | After you configure OTLP | After you configure OTLP |
| Default UI | **You build dashboards** | Sessions / Traces work out of the box |
| PayFlow waterfall | Topology / session replay | `payflow.chat` parent + children |
| Slice by subject | Dashboard on `tutor.subject` | Filter on `tutor.subject` |
| Eval loop | Not in this lesson | Evaluation runs + test sets |

That contrast is the teaching point: **ingested is not the same as visible**
(see above). Agenta gives you a session explorer for free; Arato expects you to
**create a dashboard** (or use topology / session replay) before the numbers
appear.

### Build a dashboard (do this live)

In Arato **Observe**, create a dashboard panel using the attributes this repo
sends:

| Field | Value |
|---|---|
| `service.name` | `break-into-ai-testing` |
| instrumentation scope | `openinference.instrumentation.openai` |
| span name | `llm.chat.completion` (TutorBot) or `payflow.chat` (PayFlow) |
| `llm.model_name` | `qwen/qwen3.8-27b` |
| `llm.token_count.total` | token count per span |
| `tutor.subject` | Mathematics / Biology / … (TutorBot only) |
| `tutor.level` | Beginner / Intermediate / Advanced |
| `route.guard_status` | allowed / blocked (PayFlow only) |
| `debug.latency_ms` | end-to-end ms (PayFlow only) |

Suggested first panels:

1. **Latency** — p50 / p95 of span duration, grouped by `tutor.subject` or span name.
2. **Tokens** — sum of `llm.token_count.total` over time.
3. **PayFlow** — count by `route.guard_status` (allowed vs blocked).

Paste a `trace_id` into Arato search to confirm the span you just exported.

### Arato gotchas (same as the code comments)

- **Protobuf only** — JSON OTLP returns `500 invalid wire type`.
- **Scope name** — must be `openinference.instrumentation.openai` (or another
  `openinference.instrumentation.*` name Arato accepts). Anything else →
  `400 Unknown span type`.
- **Privacy** — default telemetry is `sha256:… (len=N)`; set `LOG_RAW_PROMPTS=true`
  only for live demos.

### Suggested class order (Arato + Agenta)

1. Run TutorBot eval → show **dual** `[arato]` and `[agenta]` lines in the terminal.
2. **Agenta** — Sessions: three turns, one conversation (`tutor.subject` visible).
3. **Arato** — open Observe; if empty, **build one dashboard panel** (latency or
   tokens). Name the three-step pipeline: emit → ingest → query.
4. **PayFlow** — `./run.sh payflow-exposure`; compare Agenta waterfall to Arato
   topology / session replay for `payflow.chat`.

### Arato evals (two surfaces)

OTLP traces and Arato evals are related but not automatic. This repo now attaches
**OpenInference evaluation attributes** on exported spans (`evaluations.0.evaluation.*`
via `evaluationAttributes()` in `otlp.mjs`):

| Span | Eval names | What they check |
|---|---|---|
| TutorBot `llm.chat.completion` | `response-nonempty`, `latency-under-10s` | Non-empty answer; duration &lt; 10s |
| PayFlow `payflow.chat` | `no-debug-leak`, `guard-decision`, `latency-under-10s` | Exposure finding (`debug` in body); guard outcome; latency SLO |

Generate fresh eval-bearing traces:

```bash
npx promptfoo@latest eval -c modules/02-advanced-eval/observability/promptfooconfig.yaml
```

```bash
./run.sh payflow-serve   # restart after telemetry.js changes
curl -s http://localhost:8000/chat \
  -H 'Content-Type: application/json' \
  -d '{"message":"What is PayFlow?","session_id":"arato-evals-demo","user_role":"student"}'
```

**Where evals appear in Arato:**

| Surface | What you see | Setup |
|---|---|---|
| **Observe → threads** | **Evals** column (`+N` pass/fail badges) on OTLP traffic | **One-time:** attach **dashboard validations** to this flow (below). OTLP `evaluations.*` span attributes (above) are useful metadata but **do not** populate this column by themselves. Refresh after ~30s after new traffic. |
| **Experiment → Try demo notebook** | Run Results grid with **Evaluations** column | **Experiment → Try demo notebook** → step **7/7 Run Results** (pre-baked demo data). |
| **Evals Hub** | Reusable String Check / Yes-No templates | **Evals → Create Template** — reusable library; attach copies to Observe dashboards or Studio notebooks. |

**One-time Observe setup (Release Testing dashboard):**

1. Open **Observe → Release Testing** (`neat-gold-numbat-1988`).
2. Attach these **dashboard validations** (header Evals / validations panel, or
   the same TextValidator shape used for `day8-mentions-payflow`). OTLP
   `evaluations.*` attributes do **not** fill the threads Evals column.
3. Save. Generate a fresh PayFlow `/chat` (and optionally a TutorBot eval).
   New threads show badges within ~30s. Threads from *before* the attach stay empty.

| Name | Type | Field | Operator | Value | What class should see |
|---|---|---|---|---|---|
| `day8-mentions-payflow` | TextValidator | Output | contains | `PayFlow` | Pass on PayFlow's final answer; **fail** on TutorBot and on PayFlow's guard / orchestrator spans (no "PayFlow" in those JSON outputs) |
| `day8-no-debug-leak` | TextValidator | Output | notContains | `debug` | **Fail** on the PayFlow parent when `debug` leaked into the exported output (the exposure finding); pass on TutorBot |
| `day8-response-nonempty` | TextValidator | Output | regex | `.+` | Pass on any span with output — the green check next to the red ones |

There is **no** simple duration / latency TextValidator in Observe. Latency stays
on the span (`debug.latency_ms`, `latency-under-10s` OpenInference attr) and in
Agenta's waterfall. **Failed Evals** is the tab next to **Threads**. **Column
Selection** can show Model / Tokens; there is no Latency column. The topology
canvas stays empty until you **click a thread ID**.

For class: show **Observe** eval badges on fresh TutorBot / PayFlow OTLP threads *and*
the **Experiment** demo run results so students see evals in both the production-trace
and pre-ship experiment loops. PayFlow batch regression stays in Promptfoo;
Agenta evaluation runs stay on hosted prompts.

## Agenta: observability and evaluations (two loops)

Agenta is one project with two views on the same traffic. Teach them as separate
loops that meet in the middle.

| Loop | Sidebar | Question it answers |
|---|---|---|
| **Observability** | Observability → Sessions / Traces | What did the app do on this request? |
| **Evaluation** | Evaluation → Evaluation runs | Does this prompt variant pass the test set? |

PayFlow covers the first loop end-to-end. The second loop uses the
**support-ticket-triage** application already in the BreakIntoAI workspace (two
completed runs named *Demo: baseline vs budget-flash*). PayFlow itself is not an
Agenta prompt — its batch regression stays in Promptfoo (`./run.sh
payflow-exposure`). The bridge below shows how a production trace becomes a
regression row anyway.

### Loop A — Observability demo (10 min)

1. **Generate traffic** (from repo root, with `AGENTA_API_KEY` in `.env`):
   ```bash
   ./run.sh payflow-serve          # terminal 1
   ./run.sh payflow-exposure       # → Sessions → exposure-session
   ```
2. **Observability → Sessions** — open `exposure-session` or `# demo-exposure-map`.
   Five `/chat` cases appear as five traces; the `/health` case does not (no span).
3. **Waterfall** — expand one trace: parent `payflow.chat`, children
   `llm.chat.completion` (guard, orchestrator, answer). Name the slow stage.
4. **Filters** — **Traces** tab → filter root span name `payflow.chat`; blocked
   requests show `route.guard_status=blocked` and one child span.
5. **Two sinks** — compare `debug.latency_ms` in the HTTP JSON with the same
   attribute on the parent span (`# demo-two-sinks`).

Optional beats if you have time: `# rbac-staff` vs `# rbac-anonymous` (same answer,
different `ag.user.id`); `# poisoning-session` with `PAYFLOW_POISON=1`.

### Bridge — trace → test set

This is how observability feeds evaluation: promote a real failure into a
regression case.

1. In the session drawer, open a trace (e.g. the blocked weather question in
   `demo-exposure-map`).
2. Click **Add to testset**.
3. **Create New** → name it `day8-payflow-exposure` (or select that test set if
   it already exists) → **Commit**.
4. In the field mapper, wire span attributes to columns:
   - **inputs** ← `ag.data.inputs` (PayFlow sends `{"message":"..."}` — must be a
     JSON object on the root span or Sessions stays empty)
   - **outputs** ← `output.value`
5. **Evaluation → Test sets** — confirm the row shows the user message and model
   answer. Repeat for other exposure traces if you want a five-row set.

If **Create** gives you empty skeleton rows, you skipped the value mapping on the
right-hand comboboxes — map `ag.data.inputs` and `output.value` before committing.

### Loop B — Evaluation demo (5 min)

1. **Evaluation → Evaluation runs**.
2. Open an existing run — *Demo: baseline vs budget-flash* — and walk the grid:
   test set `support-tickets-demo`, application `support-ticket-triage`, evaluators
   *Contains JSON* and *Triage Field Match*.
3. Or start a fresh run: **New Evaluation → Auto evaluation** → pick
   **Application** (`support-ticket-triage`) → **Test set** → **Evaluators** →
   **Start Evaluation**.

Read the result as you read Promptfoo: green = met the assertion, red = finding.
Agenta adds variant comparison (baseline vs budget-flash) in one table.

### How this maps to Promptfoo

| Promptfoo | Agenta |
|---|---|
| `tests/payflow.exposure.yaml` | Test set rows (manual import or trace → test set) |
| `promptfooconfig.payflow-exposure.yaml` | Evaluation run configuration |
| `./run.sh payflow-exposure` (inverted exit 100) | Auto evaluation on a hosted prompt variant |
| OTLP from `payflow.chat` | Observability → Sessions |

Promptfoo stays the source of truth for PayFlow attacks. Agenta shows the same
SDLC shape — observe, capture, evaluate — on traces and on prompts hosted in the
cloud UI.

> Extension lesson — not part of the original `how-to-test-ai` day-03-promptfoo-advanced
> curriculum. Taught on **Day 8** (Advanced Red Teaming, SDLC Testing + Arato.ai &
> Agenta.ai).
