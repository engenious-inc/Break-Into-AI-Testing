# Day 7 — Testing an application, not a model

Every config before tonight pointed at a **model**. Tonight one points at a running
**application**, and that changes what you are allowed to assert on.

## Run this — two terminals

```bash
./run.sh payflow-serve      # terminal 1 — leave it running
```

```bash
./run.sh payflow-health     # terminal 2 — confirm it answers before you eval
./run.sh payflow            # 21 cases: routing, citations, guard, agency
./run.sh payflow-multiturn  # injection after four turns of legitimate context
./run.sh view               # read the results
```

`./run.sh payflow` refuses to run if the app is down, on purpose — a dead server produces
connection errors that look exactly like failing tests.

## The line that matters

```yaml
transformResponse: json     # output becomes the WHOLE response body
```

Without it `output` is a string and you are grepping prose. With it you can assert on
`output.route.selected_specialists` — *which specialist answered*, not just what it said.
Most real AI defects are routing and retrieval defects, and they are invisible in the text.

## Read this

- [`modules/03-app-testing/`](../modules/03-app-testing/) — the module overview and the
  PayFlow app itself
- [`payflow/corpus/`](../modules/03-app-testing/payflow/corpus/) — 20 fixture documents.
  **Read them before writing cases.** Knowing the ground truth is what lets you tell a
  grounded answer from a fluent one.
- [`LAB-GUIDE-NOTES.md`](../modules/03-app-testing/LAB-GUIDE-NOTES.md) — lab-slot
  checklist (commands, contracts, traps)

**MCP — the provider does not have to be an app either**

| Lesson | Provider |
|---|---|
| [`mcp-local/`](../modules/03-app-testing/mcp-local/) | a local stdio server Promptfoo spawns — needs a one-time `npm install --prefix modules/03-app-testing/mcp-local` |
| [`mcp-deepwiki/`](../modules/03-app-testing/mcp-deepwiki/) | a remote MCP server over the network |
| [`mcp-promptfoo/`](../modules/03-app-testing/mcp-promptfoo/) | Promptfoo *as* the MCP server, giving your IDE agent eval tools |

If you only do one, do `mcp-local` — every assertion in it is deterministic, no API key.

## Homework

1. Add three cases to `tests/payflow.routing.yaml` that assert on `output.route`
2. Find and document one routing or citation defect the shipped suite misses
3. Write one case that **passes on text but fails on route** — and explain why

The third is the real assignment.
