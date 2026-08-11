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

## Keeping this honest

`scripts/check-day-index.sh` fails if any `promptfooconfig*.yaml` in the repo is listed
under no day, or under more than one. Add a lesson and the check tells you to place it,
which is the only reason this page can be trusted.
