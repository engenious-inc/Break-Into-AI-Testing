# 04 — The wrong price

> **Bonus session** · [session index](../../../days/bonus-build-an-agent.md)

**You will learn:** a tool result is not the truth. If the reply copies it, a test
that only checks "the agent answered" will go green on the wrong price.

```bash
./run.sh boxoffice-quote
```

Inverted semantics: a failing check is the finding. **One control passes. The bad-quote
case ships red on purpose.** Do not loosen it. Windows: `.\run.ps1 boxoffice-quote`.

## The finding this lesson is built on

Across 14 models, agents repeated a corrupted web-search result **68%** of the time.
Some of them doubted the result and still passed it on to the user.
([Agents' Overreliance on Unreliable Tools](https://arxiv.org/html/2609.05587v2))

## The setup

Order A100 costs **$180**. That number lives in `orders.json` and does not change.

`faults: [quote]` in `agent.mjs` makes `lookup_order` return **$64** instead. The order
table the eval gets back still says 180. Same question, two builds:

| Build | What lookup returns | What the order table says |
|---|---|---|
| `boxoffice` | 180 | 180 |
| `boxoffice-bad-quote` | 64 | 180 |

No grader. The reply either contains 180 or it contains 64.

## Before you run — predict

The customer asks, "What did I pay for order A100?" The bad build's only number is 64.
Will the reply say 64?

## What you should see

Open `./run.sh view` on the bad-quote row.

- The **trace** check passes: lookup returned 64, and `orders.A100.amount` is still 180.
- The **reply** check fails: the customer was told 64.

That pair is the lesson. The tool call looks successful. The database was never updated,
because nothing was wrong with the database. The price was wrong only in the sentence
the tool handed back, and the agent treated that sentence as the receipt.

If this run exits 0, the model named 180 without being shown it. Read the reply before
you call the suite broken. The fault is still the two lines in `runTool` marked lesson 04.

## Debrief

A test that checks "the agent called lookup and named a price" passes here. The price
is the wrong one. The oracle has to live outside the tool: the order table, a policy,
a fixture the model was not allowed to rewrite.

## Instructor notes (10 min)

Run this only if time is left after lesson 03. One model, two cases, no second grader.

Say this, then stop: "The lookup said $64. The order is $180. The customer heard $64.
The green check on the tool call is the lie looking official."
