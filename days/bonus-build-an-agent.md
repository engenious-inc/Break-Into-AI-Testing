# Bonus session — Build an agent, then test it

Everything before tonight tested something somebody else built. Tonight you read a
200-line agent, run it, and find out what goes wrong when a model can **do** things
instead of only saying them.

All material lives in [`modules/04-build-an-agent/`](../modules/04-build-an-agent/).
Start with its README — it walks through the agent before any eval runs.

## Run this

From the **repo root**, one at a time (each takes about two minutes on the free tier):

```bash
npx promptfoo@latest eval -c modules/04-build-an-agent/01-it-said-done/promptfooconfig.yaml
npx promptfoo@latest eval -c modules/04-build-an-agent/02-narrate-then-comply/promptfooconfig.yaml
npx promptfoo@latest eval -c modules/04-build-an-agent/03-memory-outlives-the-patch/promptfooconfig.yaml
npx promptfoo@latest view
```

No server to start, no `npm install`. Only `GROQ_API_KEY`.

| Lesson | Semantics | Healthy result |
|---|---|---|
| `01-it-said-done` | Ordinary | Exit 100 — case 4 fails **on purpose** (the refund tool lies) |
| `02-narrate-then-comply` | Inverted | Exit 100 — controls pass, at least one leak lands across 3 tries |
| `03-memory-outlives-the-patch` | Inverted | Exit 100 — control passes, the patched agent still emails the attacker |

Do not run two lessons at once on one key. If a run sits silent for more than a minute,
`Ctrl-C`, wait a minute, run it again — the module README explains why.

## The arc

One sentence per lesson, and they build on each other:

1. **The agent lies** — it says "Done!" and the database says otherwise.
2. **The agent lies about refusing** — the reply sounds safe, the outbox says otherwise.
3. **The lie survives the fix** — you patch the bug, and the memory it wrote keeps working.

The rule underneath all three: **grade the world, not the words.**

## Run sheet (≈ 2 h 15 min)

| Block | Min | What happens |
|---|---|---|
| Hook | 10 | "A chatbot can say something wrong. An agent can do something wrong, then say something reassuring about it." Ask for examples from the room. |
| Read the agent | 20 | Walk [`boxoffice/agent.mjs`](../modules/04-build-an-agent/boxoffice/agent.mjs) top to bottom: policy, tool schemas, `runTool`, the loop. Stop on the return shape — that one decision makes every later test possible. |
| Lesson 01 | 25 | ThinkingBox's 67% → predict → run → open case 4 → find `order.amount > 500`. |
| Break | 10 | |
| Lesson 02 | 25 | Dynatrace's "no framework defends you" → vote on which order leaks → run → read B500's reply, *then* its outbox. |
| Lesson 03 | 25 | RufRoot → three builds → run → the channel comparison table (same words refused in notes, obeyed from memory). |
| Exercises | 15 | Pairs pick one: fix the refund bug (01), harden `send_email` (02), purge the memory (03). |
| Close | 5 | "What did your last agent demo grade — the world, or the words?" |

Short on time? Lesson 03 is the one to keep. It contains the other two: the agent does
everything right, says everything right, and sends the email to the wrong person.

## Bring back

One sentence for your notes or LinkedIn: a test you would now write for an agent that you
would not have written last week, and the 2026 incident that makes the case for it.
