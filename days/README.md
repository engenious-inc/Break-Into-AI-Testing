# Find your day

The lessons live in `modules/`, organised by topic. This folder organises the same
material by **session**, which is how it is taught. Nothing here duplicates a lesson — each
page tells you what to run tonight and links to the real thing.

| | Session | Start here |
|---|---|---|
| 1 | AI fundamentals & environment setup | [`01-fundamentals-and-setup.md`](01-fundamentals-and-setup.md) |
| 2 | Promptfoo basics — assertions | [`02-promptfoo-basics.md`](02-promptfoo-basics.md) |
| 3 | Prompt engineering & local models | [`03-prompt-engineering-and-local-models.md`](03-prompt-engineering-and-local-models.md) |
| 4 | Metrics & model-graded assertions | [`04-metrics-and-model-graded.md`](04-metrics-and-model-graded.md) |
| 5 | Red teaming | [`05-red-teaming.md`](05-red-teaming.md) |
| 6 | Black box testing | [`06-black-box-testing.md`](06-black-box-testing.md) |
| 7 | Testing an application, not a model | [`07-testing-an-application.md`](07-testing-an-application.md) |
| 8 | Advanced red teaming, SDLC & observability | [`08-advanced-redteam-sdlc-observability.md`](08-advanced-redteam-sdlc-observability.md) |
| — | Hackathon (not a session) | [`hackathon.md`](hackathon.md) |

## Numbers that lie

Three different numbering schemes exist in this repo and **none of them agree**. If you
remember one thing from this page, make it this:

| You see | It is |
|---|---|
| `modules/00-…`, `01-…`, `02-…`, `03-…` | module numbers — **not** days |
| `docs/06-prompt-engineering-exercises.md` | **Day 3** |
| `docs/07-metrics-exercises.md` | **Day 4** |
| `docs/05-quality-challenges.md` | **Day 5** |
| `docs/02-redteam-exercises.md` | **Day 5** |

`docs/07` is the one that catches people: it is Day **4**, not Day 7. Day 7 is
[`07-testing-an-application.md`](07-testing-an-application.md) in this folder.

Module numbers are stable and day numbers are not — the sessions have already been
renumbered once between cohorts, which is why the lessons are not stored in day folders.

## Pass/fail semantics cheat sheet

| Semantics | Exit 100 means | Targets |
|---|---|---|
| **Inverted** | Finding — the attack / bias / leak landed | `medibot`, `finance`, `medibot-multiturn`, `quality.*`, `openrouter.*`, `payflow-redteam`, `payflow-rbac`, `payflow-exposure`, `payflow-poisoning`, `mcp-abuse`, `mcp-agent`, `mcp-injection` |
| **Ordinary** | Defect — the bot / app / lesson broke | Modules 0 and 2, `payflow`, `payflow-multiturn`, `mybot`, `reverse`, `mcp-local` |

`payflow-rbac`, `payflow-exposure` and `payflow-poisoning` are the inverted suites that
point at the **application** rather than at a model. Their assertions describe a hardened
PayFlow, so a failure is a finding in the app itself. Each ships at least one control case
that passes — if the control fails too, the harness is broken, not the app.

`mcp-abuse`, `mcp-agent` and `mcp-injection` are the inverted suites that point at the
**workshop-local MCP server** (and, for the last two, at Groq holding its tool schemas).
`mcp-local` is ordinary: pass means the path-traversal guard held.

`./run.sh` prints the right verdict for each. Quality suites invert even though they are
not jailbreaks — a fail still means the model behaved badly.

## Keeping this honest

`scripts/check-day-index.sh` fails if any `promptfooconfig*.yaml` in the repo is listed
under no day, or under more than one. Add a lesson and the check tells you to place it,
which is the only reason this page can be trusted.
