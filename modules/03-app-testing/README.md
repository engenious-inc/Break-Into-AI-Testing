# Module 3 — Testing an Application, Not a Model

Every other module in this repo points Promptfoo at a **model**. This one points it at a
**running application** — a multi-agent pipeline with a guard, an orchestrator, four
document specialists, and retrieval in front of the answer.

That changes what you can test. When the provider is a model, the only thing you can
assert on is the text it produced. When the provider is your application, you can assert
on *how the answer was produced* — which specialist was chosen, which documents were
retrieved, whether the guard fired. Most real AI defects live there, not in the prose.

## The app: PayFlow GenAI demo

PayFlow is a fictional fintech product. The demo answers questions about it from a small
fixture corpus of Jira tickets, Confluence pages, and Figma screens.

```
user ──▶ guard LLM ──▶ orchestrator LLM ──▶ retrieval ──▶ answer LLM ──▶ user
           │                  │                  │
      allow/block      pick specialist     keyword scoring over
                       + intent            that specialist's docs
```

Three of those four steps are an LLM call. **The routing decision is model output**, which
means it can be wrong — and a test suite can catch it being wrong. Retrieval is
deterministic keyword scoring, so there are no embeddings, no vector store, and no second
API key. The same free Groq key you have been using since Day 1 runs the whole thing.

### Start it

```bash
node modules/03-app-testing/payflow/server.js     # or: ./run.sh payflow-serve
```

It listens on `http://localhost:8000`. Check it before evaluating:

```bash
./run.sh payflow-health
```

### The contract

```
POST /chat
  { "message": "...", "session_id": "...", "user_role": "student" }

200 ->
  {
    "answer": "...",
    "route": {
      "guard_status": "allowed" | "blocked",
      "guard_reason": string | null,
      "selected_specialists": ["jira"],
      "orchestrator_decision": "jira_blocker_query"
    },
    "citations": [ { "id": "PF-104", "source": "jira", "title": "..." } ],
    "debug": { "steps": [...], "retrieved": 3, "latency_ms": 931 }
  }
```

`GET /health` returns service status and the document count. Run it before an eval — a
connection-refused error in Promptfoo looks identical to a failing test until you check.

## Pointing Promptfoo at it

The whole lesson is four lines of `promptfooconfig.payflow.yaml`:

```yaml
providers:
  - id: http
    config:
      url: http://localhost:8000/chat
      method: POST
      body:
        message: '{{prompt}}'
      transformResponse: json     # <- output becomes the WHOLE response body
```

`transformResponse: json` is the part that matters. Without it, `output` is a string and
you are back to grepping prose. With it, `output` is the parsed body, so a test can say:

```yaml
- type: javascript
  value: output.route.selected_specialists.includes('jira')
```

That assertion does not care what the answer said. It cares that the Jira specialist is
the one that said it.

## Run the suite

```bash
./run.sh payflow          # starts nothing — bring the server up first
```

or directly:

```bash
npx promptfoo@latest eval -c promptfooconfig.payflow.yaml -j 2
npx promptfoo@latest view
```

## The corpus

`payflow/corpus/` holds 20 fixture documents across four specialists. They are internally
consistent on purpose, and they contain deliberate traps:

| Document | Why it is there |
|---|---|
| `PF-104`, `PF-105` | the two genuine v2.4 release blockers |
| `PF-106` | open, HIGH priority, and **not** a blocker — the decoy that catches sloppy answers |
| `PF-098` | blocks PF-104, so "what is blocking the release" has a second hop |
| `PF-113` | states the release condition, and names PF-105 without PF-105 being retrieved |
| `CF-009` | the login flow change log — lives in Confluence, not Jira |
| `FIG-012` | the freeze card toggle screen, referenced by `PF-121` |

Read them before you write test cases. Knowing the ground truth is what lets you tell a
grounded answer from a fluent one.

## Known defects — these are the exercise

The demo is deliberately not perfect. Two real failures are reproducible today:

1. **Cross-source routing is wrong.** Ask *"What changed in the login flow and is there a
   related ticket?"* and the orchestrator routes to `jira`. The change log is `CF-009`, in
   Confluence. The answer that comes back is grounded — in the wrong corpus.

2. **Citations are incomplete.** Ask *"What open Jira bugs are blocking the payment
   release?"* and the answer correctly names PF-104 **and PF-105**, but the citation list
   contains PF-113, PF-106, PF-104 — not PF-105. The model learned about PF-105 from
   PF-113's summary, so the answer is right while the citations under-report it.

Neither is a prose problem. Neither is visible if you only read the answer. Both are
exactly what `output.route` and `output.citations` assertions exist to catch.
