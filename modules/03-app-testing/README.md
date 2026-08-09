# Module 3 — Testing an Application, Not a Model

Every other module in this repo points Promptfoo at a **model**. This one points it at
something else:

| Lesson | Provider / surface | Target |
|--------|-------------------|--------|
| PayFlow (below) | `http` | Local multi-agent app — assert on **route + citations** |
| [`mcp-deepwiki/`](./mcp-deepwiki/) | `mcp` (`url:`) | Remote DeepWiki — **tool output shapes** |
| [`mcp-local/`](./mcp-local/) | `mcp` (`command:`) | Local stdio server — happy path + **path-traversal guard** |
| [`mcp-promptfoo/`](./mcp-promptfoo/) | Promptfoo **is** the MCP server | IDE agents get `validate` / `run` / `list` eval tools |

When the provider is a model, the only thing you can assert on is the text it produced.
When the provider is your application or tool server, you can assert on *how the answer
was produced* — which specialist was chosen, which documents were retrieved, whether the
guard fired, whether a tool failed cleanly. Most real AI defects live there, not in the
prose.

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

> **Editing the corpus? Add `--no-cache`.** Promptfoo caches by request, and the request
> here is just your question — it has no idea the documents behind the app changed. Edit a
> corpus file, re-run without `--no-cache`, and you get the *old* answer replayed with your
> *new* assertions, which fails for a reason that is not real. The tell is
> `Duration: 0s` and an empty server log: the app was never called.
>
> ```bash
> ./run.sh payflow --no-cache
> ```

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
| `FG-012` | the freeze card toggle screen, referenced by `PF-121` |

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

## Lessons

1. **PayFlow** — `payflow/` + root `promptfooconfig.payflow.yaml`. Start the server, then
   assert on `output.route` and `output.citations`.
2. **Remote MCP** — [`mcp-deepwiki/`](./mcp-deepwiki/). No local server. Three cases teach
   when to use deterministic vs `llm-rubric` vs error-path asserts against tool output.
3. **Local MCP** — [`mcp-local/`](./mcp-local/). Promptfoo spawns a tiny stdio server
   (`npm install` once). Happy-path tools plus a path-traversal refusal you assert on.
4. **Promptfoo’s MCP** — [`mcp-promptfoo/`](./mcp-promptfoo/). Promptfoo exposes eval tools
   to Cursor/Claude (`validate_promptfoo_config`, `run_evaluation`, …). Not a provider
   lesson — a control-plane lesson. Repo ships `.cursor/mcp.json`.
