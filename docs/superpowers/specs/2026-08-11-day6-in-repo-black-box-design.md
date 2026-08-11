# Day 6: bring black-box testing into this repo

**Date:** 2026-08-11
**Scope:** one new script (`scripts/chat.mjs`), a `chat` target in `run.sh` and `run.ps1`, four slides collapsed to one in the Day 6 deck, and rewrites of the Day 6 session page and runbook.

## Why

Day 6 currently sends students to `github.com/Jaimeman84/financial-chat-bot`. That
predates the consolidation recorded in
[`2026-08-01-financebot-legacy-lessons-design.md`](2026-08-01-financebot-legacy-lessons-design.md),
whose stated purpose was to port those lessons in with **"no new architecture, no new
dependencies, no new install step"**, preserving the three-minute `npx`-only quickstart as
"a deliberate, stated design goal."

The external app costs a `npm install` of 19 packages and, by default, a **paid**
Anthropic or OpenAI key — against a course whose README promises "free, no credit card
required." It can be pointed at Groq via `OPENAI_BASE_URL`, but nothing documents that,
and the setup burden is the thing the consolidation existed to remove.

## The real gap

Not *which bot* — **the repo has no interactive chat interface for any bot**, and
black-box exploration is mostly conversation.

Two in-repo options were tested and rejected:

**PayFlow cannot be black-boxed.** `POST /chat` always returns
`{answer, route, citations, debug}`; there is no answer-only mode. A Day 6 student poking
it sees the pipeline's own record of how it routed — which is exactly Day 7's reveal.
Using it on Day 6 would spoil the day it was meant to set up.

**FinanceBot cannot be poked.** `scripts/` holds only `generate-qr`, `outcome-check` and
`smoke-check`. To try one ad-hoc prompt a student must edit a YAML file and re-run a
suite. That is not exploration.

## Design

### `scripts/chat.mjs`

Node builtins only — `node:readline`, `node:fs`, global `fetch`. No dependencies, the same
free Groq key, and the `GROQ_API_BASE` override already used by
`modules/03-app-testing/payflow/pipeline.js`.

```bash
./run.sh chat finance      # also: medibot, mybot
```

It reads `prompts/<bot>.txt`, takes the **system** message, discards the `{{query}}` user
template, and prints **only the assistant's reply** — no system prompt, no model name, no
token counts. The box stays closed by what the tool shows rather than by asking students
not to look.

Three commands, each traceable to a slide:

| Behaviour | Earns its place from |
|---|---|
| History across turns | Slide 24 (context-window exploitation) and slide 35 (multi-turn confusion) are impossible single-shot |
| `/reset` | Slide 16 (inconsistency testing) needs the same question from a *fresh* context |
| `/save <file>` | Slide 21 asks for write-ups of "3–5 issues from Session 1". Findings otherwise die in scrollback — the runbook names this as the top breakout failure |

Nothing else. No streaming, no colour, no model switching.

**Errors surface, they do not get swallowed.** A missing `GROQ_API_KEY`, an unknown bot
name, or a Groq non-200 prints the status and body and exits non-zero. Rate limits are the
expected failure here and a silent hang would be read as a broken bot.

### Windows parity

`run.ps1` exists and mirrors every `run.sh` target. `chat` must be in both, or Day 6
breaks for Windows students specifically — the one group least able to work around it.

### Deck changes — `August Day 6 - BlackBoxTesting.pptx`

Edited in place, per the decision to make the `.pptx` the source of truth. **The Google
Slides original will go stale**; that is accepted.

| Slides | Now | Change |
|---|---|---|
| 10–13 | Four slides: repo URL, how to clone, repo URL again, how to open VS Code | **Keep slide 10, rewrite it, delete 11–13.** Slide 10 already carries the title "Black Box Testing — Financial Chat Bot" and a body text shape; its URL becomes the run command. Deck 35 → 32 slides, and everything after 10 shifts down by three |
| 18 | "Explore the Financial Chat Bot app" | Retarget to FinanceBot in this repo; keep the client-perspective framing verbatim |
| 35 | Sample prompts about "onboarding topics" and "access levels" | Replace with prompts that probe FinanceBot's five rules |

Slides 14–17, 20–29 and the career block are target-agnostic and unchanged.

### `days/06-black-box-testing.md` and the Day 6 runbook

Both currently instruct students and instructor to clone the external repo. Both are
rewritten around `./run.sh chat finance`. The runbook's timing table is rebuilt for 32
slides, and its "The Morning Of" section loses the clone-and-npm-install risk entirely —
the setup risk it was written around no longer exists.

## Sequencing

`days/06-black-box-testing.md` is in **open PR #33**. If #33 merges first it ships guidance
telling students to clone the external repo. Either land this work on the same branch, or
merge #33 and correct immediately — but do not merge #33 and leave it.

## Verification

1. `./run.sh chat finance` holds a multi-turn conversation, `/reset` clears context,
   `/save` writes a readable transcript.
2. The system prompt never appears in output — checked by grepping a saved transcript for
   a distinctive phrase from `prompts/financebot.txt`.
3. A missing key and a bad bot name each produce a clear message and a non-zero exit.
4. `shellcheck` clean on `run.sh`; `run.ps1` gains the same target.
5. Deck: 32 slides, no reference to `financial-chat-bot` or `npm install` remains, all
   three checkers run and their output is compared against a render (this deck is
   hand-authored — see the sources README on why its counts are not trustworthy alone).
6. `scripts/check-day-index.sh` still passes.

## Out of scope

- **Changing PayFlow.** No answer-only mode; Day 7's contract stays as it is.
- **Rebuilding the Day 6 deck from a script.** It is Google Slides-authored and stays a
  hand-edited `.pptx`.
- **Fixing Day 6 slide 11's title/subtitle collision.** Real, unrelated to this work, and
  slide 11 is being deleted by this change anyway.
