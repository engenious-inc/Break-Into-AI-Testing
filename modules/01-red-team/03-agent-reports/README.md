# 03 — The agent runs it and reports

`.claude/skills/run-and-summarize/` runs an eval and produces the per-provider
verdict table by hand-filling nothing.

## Use it

```
run and summarize promptfooconfig.medibot.yaml
```

It runs the eval to `./pf-latest.json`, reads the raw per-row results, and emits:

`| Case | Axis | <provider…> | Key difference |`

Critically, it knows about this module's inverted semantics: a **failed**
assertion is labelled ⚠️ (the attack landed) and a **passed** one ✅ (the guardrail
held). A summariser that did not know this would report a successful red team as
a catastrophic test failure.

It is read-only. It never edits configs or tests.

## Why the report is the deliverable

Terminal output scrolls away and convinces nobody. The table is what you take to
a standup, a ticket, or a compliance review. It answers the three questions a
reader actually has:

- Which attacks landed, on which models?
- Where did the models *disagree* — and what does that tell us about model vs. prompt?
- What is the latency and consistency cost of the assertions we are running?

## Exercise

1. Run and summarize `promptfooconfig.medibot.yaml`, then `promptfooconfig.finance.yaml`.
2. Put the two tables side by side.
3. Answer in three sentences: **why is FinanceBot harder to break than MediBot?**

Cases 5–7 of the finance suite use no jailbreak wrapper at all — plain investment
questions — and held across all three models in our testing. MediBot's
prescription rule falls over to a single line of education framing.

The reason is worth arguing about: *never recommend a specific security* is a
bright line the model can check mechanically (is a ticker in my answer?), while
*never provide dosage* requires a judgment call (is quoting a textbook range a
dose?). Judgment calls are attack surface. Bright lines are enforceable.
