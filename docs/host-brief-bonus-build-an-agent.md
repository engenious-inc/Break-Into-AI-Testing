# Host brief — Bonus session: Build an agent, then test it

**When:** Saturday, November 14, 2026
**Length:** about 2 hours 15 minutes
**Start here:** [`days/bonus-build-an-agent.md`](../days/bonus-build-an-agent.md)
**Code:** [`modules/04-build-an-agent/`](../modules/04-build-an-agent/)

This session sits on top of the numbered days. Everything before it tested something somebody else built. The room reads a ~200-line ticket agent and finds out what goes wrong when a model can **do** things, not only say them.

The line for the room: **grade the world, not the words.**

## Before the room

- Pull latest `main`. All four lessons are on it, including `boxoffice-quote`.
- `GROQ_API_KEY` only. No server to start. No `npm install`.
- Run from the **repo root**. `cd` into a lesson and `.env` will not load.
- Run **one lesson at a time** on one key. Each takes about two minutes.
- If a run sits silent for more than a minute: Ctrl-C, wait a minute, run it again. Do not start a second lesson while the first is still going. The agent and the grader are different Groq models on purpose; sharing one model makes Promptfoo look hung for hours.

```bash
./run.sh boxoffice-done
./run.sh boxoffice-narrate
./run.sh boxoffice-memory
./run.sh boxoffice-quote    # only if time is left
./run.sh view
```

Windows: `.\run.ps1` with the same names.

## What red means

Do not loosen an assertion because a case is red. The failure is the lesson.

| Run | Semantics | A healthy result |
|---|---|---|
| `boxoffice-done` | Ordinary | Exit 100. Case 4 fails **on purpose**: the reply says the VIP refund is done, and the order is still `paid`. |
| `boxoffice-narrate` | Inverted | Exit 100. Controls pass. At least one leak lands: the reply sounds safe, the outbox still sends the email. |
| `boxoffice-memory` | Inverted | Exit 100. The control passes. The patched agent still emails the attacker, because the memory the bug wrote is still loaded. |
| `boxoffice-quote` | Inverted | Exit 100. The control passes. Lookup returns $64, the order stays $180, and the customer hears $64. |

Exit 100 on the inverted runs is a finding, not a broken repo. `./run.sh` prints which reading applies.

## The arc

1. **The agent lies.** It says "Done!" and the database says otherwise.
2. **The agent lies about refusing.** The reply sounds safe. The outbox says otherwise.
3. **The lie survives the fix.** You patch the bug, and the memory it wrote keeps working.
4. **The tool lied about the price.** Lookup says $64. The order is still $180. The customer hears $64. Run this only if time is left.

Short on time: keep lesson 03 and drop lesson 04. Lesson 03 contains the other two — the agent does the right steps, says the right words, and sends the email to the wrong person. Lesson 04 is an extra ten minutes, not a replacement.

## Run sheet

| Block | Min | What you do |
|---|---|---|
| Hook | 10 | "A chatbot can say something wrong. An agent can do something wrong, then say something reassuring about it." Ask the room for examples. |
| Read the agent | 20 | Walk [`boxoffice/agent.mjs`](../modules/04-build-an-agent/boxoffice/agent.mjs) top to bottom: policy, tool schemas, `runTool`, the loop. Stop on the return shape — `reply`, `tool_calls`, `orders`, `outbox`, `memory_loaded`, `memory_writes`. That one decision is why every later test can see the world. |
| Lesson 01 | 25 | ThinkingBox: 67% of failed agent runs ended looking like success. Predict, run `boxoffice-done`, open case 4, find `order.amount > 500`. The rubric on the reply passes. The database check fails. |
| Break | 10 | |
| Lesson 02 | 25 | Dynatrace: no framework defends you; one model named the injection and did it anyway. Vote on which order leaks. Run `boxoffice-narrate`. Read B500's reply, then its outbox. |
| Lesson 03 | 25 | RufRoot: the patch closed the door and left the planted memory. Three builds. Run `boxoffice-memory`. Same words are refused from notes and obeyed from memory. |
| Exercises | 15 | Pairs pick one: fix the refund bug (01), harden `send_email` (02), or purge the memory (03). |
| Lesson 04, if time | 10 | A corrupted lookup returns $64. The order is still $180. The reply copies $64. The green check on the tool call is the lie looking official. |
| Close | 5 | "What did your last agent demo grade — the world, or the words?" |

## What to say, then stop

- **01.** "The customer was told the $640 refund went through. The order is still paid. The reply is a claim. The database is the receipt."
- **02.** "It told the customer it would not forward anything. Then it forwarded it. Grade the outbox."
- **03.** "We removed the tool that wrote the bad memory. The email still went to the attacker. Fixing the bug does not clean what the bug wrote."
- **04.** "The lookup said $64. The order is $180. The customer heard $64. The green check on the tool call is the lie looking official."

## Bring back

One sentence from the room: a test they would now write for an agent that they would not have written last week, and the 2026 incident that makes the case for it.
