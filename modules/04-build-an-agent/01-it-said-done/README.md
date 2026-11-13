# 01 — "It said Done."

> **Bonus session** · [session index](../../../days/bonus-build-an-agent.md)

**You will learn:** why an agent eval that reads only the final reply passes broken
software, and how to grade the outcome instead.

```bash
npx promptfoo@latest eval -c modules/04-build-an-agent/01-it-said-done/promptfooconfig.yaml
```

Ordinary semantics: pass = good. **Case 4 ships red on purpose.** Do not loosen it.

## The 2026 finding this lesson is built on

In Microsoft's ThinkingBox agent benchmark, **67% of failed runs ended cleanly**: the agent
called a state-changing tool, the last tool call returned no error, and the agent reported
success. Only checking the database showed the task was wrong.
([summary](https://dbggr.dev/articles/how-to-evaluate-llm-agents/))

Read that again as a tester: two out of three agent failures *look exactly like passes*
from the outside.

## Before you run — predict

Open [`tests/cases.yaml`](tests/cases.yaml). Each case has two kinds of check:

- an `llm-rubric` with `transform: output.reply` — a judge reads only what the customer sees
- a `javascript` check on `output.orders` — code reads the database

Write down, for each of the five cases, whether you expect the two checks to **agree**.

## What happens

| Case | Reply rubric | Database check | What it teaches |
|---|---|---|---|
| 1. refund A100 | ✓ | ✓ | The happy path. Both agree. |
| 2. lookup before refund | — | ✓ | The *path* is testable too: `lookup_order` must come before `refund`. |
| 3. non-refundable A300 | ✓ | ✓ | Policy held, and the database proves it. |
| 4. **refund VIP A200** | **✓** | **✗** | The agent says *"Done! Your $640 refund has been processed."* The order is still `paid`. |
| 5. gateway down | ✓ | ✓ | A **loud** failure. The agent told the truth. Loud failures are the easy ones. |

Case 4 is the lesson. Open it in `npx promptfoo@latest view`, expand the output, and
read `tool_calls`. The `refund` tool returned `{ ok: true, refund_id: "R-A200" }`.
The model did nothing wrong — it trusted a tool that lied.

Now find the bug in [`../boxoffice/agent.mjs`](../boxoffice/agent.mjs). Search for
`order.amount > 500`. Large refunds return success without writing anything.

> **Tutor's note.** Nobody in the room would have caught this by reading transcripts.
> The transcript is perfect. That is the point: for an agent, the transcript is the
> *least* trustworthy artifact you have.

## Debrief questions

1. Case 4's rubric passed. Was the grader wrong? (No — it graded exactly what it was
   shown. The mistake was showing it the wrong thing.)
2. Case 5 used a fault-injected provider (`faults: [refund]`). Why test a *loud* failure
   at all, if loud failures are easy? (Because "easy" is a claim. One line of YAML
   turns it into a fact.)
3. The original draft of case 5 had a regex: *the reply must not say "has been refunded"*.
   The model wrote *"No money has been refunded."* and the regex failed it. What does
   that tell you about text checks on agent replies?

## Exercises

1. **Fix the bug** in `runTool` and re-run. Case 4 goes green. Put the bug back before
   the next group.
2. **Add a rebook case.** Ask the agent to move A100 to "Dec 13" and assert on
   `output.orders.A100.event`. Then try "the 13th" and "tomorrow's show" — which phrasing
   breaks the state check while the reply still sounds right?
3. **Write the receipt rule.** Add a check to every refund case:
   `output.outbox.some((e) => e.to === 'maya@example.com')`. Is "the customer got an
   email" part of "refunded"? Decide, and defend it in one sentence.

## Instructor notes (25 min)

- 5 min: the ThinkingBox number. Ask the room to guess the percentage first.
- 5 min: predict sheet. Most people predict case 4 passes both checks.
- 5 min: run and open the viewer on case 4. Read the tool result aloud.
- 10 min: exercise 1 or 2 in pairs.

Repo convention this lesson demonstrates: **pair every model-graded assertion with a
deterministic one that fails for structural reasons** (see `CLAUDE.md`). Here the structural
reason is the database.
