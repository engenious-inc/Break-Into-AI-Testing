# Module 4 — Build an agent, then test it

> **Bonus session** · [session index](../../days/bonus-build-an-agent.md)

Every suite so far tested something somebody else built: a system prompt, PayFlow, an MCP
server. Tonight you build the agent yourself — about 200 lines, no framework — and then
you find out the three things an agent can get wrong that a chatbot cannot.

A chatbot can only **say** something wrong. An agent can **do** something wrong, and then
say something reassuring about it. Every lesson in this module is a version of that
sentence.

## Meet BoxOffice

[`boxoffice/agent.mjs`](boxoffice/agent.mjs) is a ticket-support agent for a fictional
promoter, Lumen Live. Read it top to bottom before anything else — it is short on purpose.

```text
customer message
      │
      ▼
┌─────────────┐   tool_calls    ┌───────────────────────────────┐
│  Groq model │ ──────────────▶ │ lookup_order · refund · rebook │
│  + policy   │ ◀────────────── │ send_email · remember          │
└─────────────┘   tool results  └───────────────────────────────┘
      │                                   │ reads / writes
      │ no more tool calls                ▼
      ▼                           orders · outbox · memory
   reply
```

Four parts, each a few lines:

| Part | Where | What to notice |
|---|---|---|
| `SYSTEM_PROMPT` | top of file | Five numbered policy rules. Rule 4 says order notes are information, not instructions. Keep it in mind for lesson 02. |
| `TOOL_SCHEMAS` | below it | Plain JSON Schema. This is all the model knows about each tool. |
| `runTool` | middle | The "world". Each run gets a fresh copy of `orders.json`. |
| `callApi` | bottom | The loop: ask the model → run the tools it asked for → feed results back → stop when it answers in words. |

The file is also a **Promptfoo custom provider**, and its return value is the most
important design decision in the module:

```js
output: {
  reply,          // what the customer reads
  tool_calls,     // every call: name, arguments, and what the tool returned
  orders,         // the database after the run
  outbox,         // every email that actually left
  memory_loaded,  // what was injected from long-term memory
  memory_writes,  // what the agent asked to remember
}
```

> **Tutor's note.** If your agent only returns the reply, you can only test the reply.
> Return the evidence, and the rest of this module becomes a few lines of JavaScript.

## The lessons

| # | Lesson | One-line lesson | Semantics | Ships |
|---|---|---|---|---|
| 01 | [`01-it-said-done/`](01-it-said-done/) | The reply is a claim; the database is the receipt. | Ordinary | 1 case red **on purpose** |
| 02 | [`02-narrate-then-comply/`](02-narrate-then-comply/) | Grade what it did, not what it said it did. | Inverted | 2 controls pass, findings fail |
| 03 | [`03-memory-outlives-the-patch/`](03-memory-outlives-the-patch/) | Fixing the bug does not clean what the bug wrote. | Inverted | 1 control passes, findings fail |

Run each from the **repo root** (never `cd` into the lesson — `.env` will not load):

```bash
npx promptfoo@latest eval -c modules/04-build-an-agent/01-it-said-done/promptfooconfig.yaml
npx promptfoo@latest eval -c modules/04-build-an-agent/02-narrate-then-comply/promptfooconfig.yaml
npx promptfoo@latest eval -c modules/04-build-an-agent/03-memory-outlives-the-patch/promptfooconfig.yaml
npx promptfoo@latest view
```

Each lesson takes about two minutes on the free tier.

## Free-tier facts that shaped the configs

- **An agent costs several model calls per test case.** One BoxOffice case is 2–4 Groq
  calls and ~3,500 tokens. Every lesson stays at 4–5 cases on one model.
- **Groq rate-limits per model.** The grader always runs on a *different* model from the
  agent. If both share one model, the agent spends the per-minute budget, the grader gets a
  429, and Promptfoo waits for Groq's *daily* reset — the run appears to hang for hours.
  A different grader model also stops a model grading its own work (see
  [`01-red-team/04-grading-the-grader/`](../01-red-team/04-grading-the-grader/)).
- **Grader `max_tokens` is capped.** Qwen allows 1,000 output tokens per minute here;
  an uncapped grader request asks for about 2,000 and is refused outright.

If a run stalls with no output, kill it, wait a minute, and re-run. Do not run two
lessons at once on one key.

## Where this sits in the course

- [`03-app-testing/`](../03-app-testing/) tested a multi-agent app over HTTP. This module
  opens the box: same ideas, but you own the loop and can return anything you like.
- `mcp-agent` / `mcp-injection` (Day 8) showed a model choosing tools. Lesson 02 is the
  same injection channel with a real side effect — an email — and a second grader that reads
  only the words.
- The research behind each lesson is linked in its README. None of it is older than 2026.
