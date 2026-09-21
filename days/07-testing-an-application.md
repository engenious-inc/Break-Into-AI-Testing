# Day 7 — Testing an application, not a model

Every config before tonight pointed at a **model**. Tonight one points at a running
**application**, and that changes what you are allowed to assert on.

MediBot and FinanceBot from Day 5 are **prompts** — a text file in `prompts/` plus an eval,
nothing to start. Tonight's PayFlow and HarborWealth FinanceBot are **applications**: a server
you leave running, a port, a chat UI in the browser, and a JSON contract underneath.

Two name traps, before you run anything:

- **`finance` is not `financebot`.** `./run.sh finance` is Day 5's prompt-only FinanceBot and
  tonight does not touch it. `./run.sh financebot` is the HarborWealth app on `:8001`.
  Different bot, different corpus, different thing under test.
- **There is no MediBot app.** MediBot never gets a server or a chat UI — cloning PayFlow into
  healthcare would cost the exact distinction this session exists to make. You still reach
  MediBot through `./run.sh medibot` and `./run.sh view`.

## Run this — two terminals

```bash
./run.sh payflow-serve      # terminal 1 — leave it running
```

```bash
./run.sh payflow-health     # terminal 2 — confirm it answers before you eval
./run.sh payflow            # 25 cases: routing, citations, guard, agency
./run.sh payflow-api        # HTTP contract + two planted defects (those two fail on purpose)
./run.sh financebot-serve   # optional second app on :8001
./run.sh financebot         # 17 cases: routing, citations, guard, agency
./run.sh financebot-api     # HTTP contract + three planted defects (those three fail on purpose)
./run.sh financebot-multiturn  # same injection shape + planted paper-trade (that case fails on purpose)
./run.sh payflow-multiturn  # injection after four turns of context (1 case fails on purpose)
./run.sh payflow-rbac       # access control: 1 control passes, 5 findings fail
./run.sh mcp-local          # local MCP: echo / add / read / path-traversal (no Groq key)
./run.sh view               # read the results
```

`./run.sh payflow` refuses to run if the app is down, on purpose — a dead server produces
connection errors that look exactly like failing tests.

| Semantics | Exit 100 means | Targets |
|---|---|---|
| **Inverted** | Finding in the app / agent | `payflow-redteam`, `financebot-redteam`, `payflow-rbac`, `payflow-exposure`, `payflow-poisoning`, `mcp-abuse`, `mcp-agent`, `mcp-injection` |
| **Ordinary** | Defect in the app / MCP behavior | `payflow`, `payflow-api`, `payflow-multiturn`, `financebot`, `financebot-api`, `financebot-multiturn`, `mcp-local` |

The planted Day 7 reds in `payflow-api`, `payflow-multiturn`, `financebot-api`, and
`financebot-multiturn` still use **ordinary** semantics: exit 100 is an intentional
application defect to inspect. Accordingly, `run.sh` calls it a defect, unlike the
MediBot runner's inverted “that's the finding” wording.

## The line that matters

```yaml
transformResponse: json     # output becomes the WHOLE response body
```

Without it `output` is a string and you are grepping prose. With it you can assert on
`output.route.selected_specialists` — *which specialist answered*, not just what it said.
Most real AI defects are routing and retrieval defects, and they are invisible in the text.

## The field nobody reads

Every PayFlow config in this repo sends `user_role` in the request body.
`tests/payflow.api.yaml` sends it twice. Neither `payflow/server.js` nor
`payflow/pipeline.js` ever reads it. PayFlow has an authorization parameter and no
authorization.

`./run.sh payflow-rbac` is six cases against that. Case 1 is a control and passes: `staff`
asks for the release blockers and gets them. Case 2 sends the **identical question** with
`user_role: anonymous` and gets the identical answer, the identical route, and the
identical citations. Put the two rows next to each other in `./run.sh view` — the only
difference in the request is one string, and there is no difference at all in the
response.

This suite is **inverted** (as are the later `payflow-exposure` and
`payflow-poisoning` suites). Five of six failing is the healthy result. Do not relax the
assertions; the fix belongs in `pipeline.js`, and writing it is the interesting part.

It also makes the argument for `transformResponse: json` better than any other case in the
day: the answer text is perfectly good prose. The finding is only visible in
`output.route` — or rather, in what `output.route` does not contain.

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
| [`mcp-local/`](../modules/03-app-testing/mcp-local/) | a local stdio server Promptfoo spawns — `./run.sh mcp-local` after a one-time `npm install --prefix modules/03-app-testing/mcp-local` |
| [`mcp-deepwiki/`](../modules/03-app-testing/mcp-deepwiki/) | a remote MCP server over the network |
| [`mcp-promptfoo/`](../modules/03-app-testing/mcp-promptfoo/) | Promptfoo *as* the MCP server, giving your IDE agent eval tools |

If you only do one, do `mcp-local` — every assertion in it is deterministic, no API key.
The same server grows extra tools for Day 8; do not delete them to make a suite go green.

## Homework

1. Add three cases to `tests/payflow.routing.yaml` that assert on `output.route`
2. Find and document one routing or citation defect the shipped suite misses
3. Write one case that **passes on text but fails on route** — and explain why

The third is the real assignment.
