# Trim Module 1 gap-fill suites to avoid Groq free-tier rate limiting

**Date:** 2026-07-31
**Status:** Design — approved by user, awaiting spec review
**Repo:** `breaking-gpt-claude-workshop`, branch `consolidate-curriculum` (open PR #9)

## Overview

Live verification of PR #9 (using a real `GROQ_API_KEY`) surfaced a genuine
capacity problem: `promptfooconfig.quality.medibot.yaml` — one of the five new
Module 1 gap-fill suites added by this PR — combines 8 test cases across 3
Groq providers (~24 base requests + ~24 grading calls ≈ 48 total). Under
current Groq free-tier load, one of those requests sat in queue for the full
300-second client timeout before failing. A single-provider re-run of the
identical content completed in 1 second with 0 errors, confirming the content
itself is correct — the failure is purely a function of request volume on the
free tier, not a config defect.

`promptfooconfig.quality.finance.yaml` (5 cases × 3 providers ≈ 30 total
requests) carries the same risk though it wasn't directly observed failing.

**Goal:** cut the default request volume of these two configs by roughly
8x while still exercising every one of the 3 pedagogical axes (Factual /
Reasoning / Safety) that Module 1's `docs/05-quality-challenges.md` teaches,
and while keeping the full cross-model matrix available as an opt-in for
anyone not rate-limited.

**Non-goals:**
- Not touching the pre-existing base red-team suites (`promptfooconfig.
  medibot.yaml`, `.finance.yaml`, `.mybot.yaml`) — both already ran clean live
  (18 and 12 requests respectively) with no observed problem.
- Not touching Module 0 or Module 2 lessons — all already small (1-3 cases,
  1-3 providers) and ran clean live.
- Not changing `.claude/agents/red-teamer.md`'s drafting behavior (it still
  drafts 3 candidate cases, one per axis, when asked to draft a new suite — a
  drafting aid producing options for a human to trim is a different use case
  than what ships by default) or `.claude/skills/new-eval-suite/templates/
  tests.template.yaml` (already ships a single example case, already
  consistent with the new lean pattern).
- Not adding request pacing/delay settings — the volume cut alone is
  sufficient per live verification (the exact same content already ran in 1-4s
  at 1 provider with the full original case counts).

## Approaches considered

- **Cut providers + trim cases (CHOSEN).** Default both gap-fill configs to a
  single Groq provider (the grader model) with the other two shown
  commented-out as opt-in, and physically trim each of the 5 test-suite files
  to its single most illustrative case, rotating which axis survives across
  the 5 files so all three axes remain represented across the set. Directly
  targets the two levers (provider count × case count) whose product caused
  the observed failure.
- **Only cut providers.** Keep all 13 existing cases, drop to 1 default
  provider. ~3x fewer requests (~16 total for medibot). Simpler diff, but
  medibot's config still issues 8 sequential calls per eval — more than
  necessary "to prove the point."
- **Only trim cases.** Keep the 3-provider matrix, cut to 1 case per topic
  (3 cases for medibot, 2 for finance) but still × 3 providers (~18/~9 total
  requests). Rejected: the observed failure was specifically the *product* of
  providers × cases, and this leaves the multiplier at 3 rather than 1.
- **Add pacing, don't cut content.** Leave provider/case counts as shipped,
  add `evaluateOptions.delay` and/or serial (`-j 1`) guidance. Rejected: zero
  content risk, but doesn't reduce total volume — a long enough suite could
  still eventually trip a hard per-minute cap; live evidence points at volume,
  not pacing, as the actual fix.

## Design

### File changes

**`promptfooconfig.quality.medibot.yaml`** — `providers:` becomes:
```yaml
providers:
  - id: groq:llama-3.3-70b-versatile
    config: { temperature: 0, max_tokens: 400 }
  # Uncomment for full cross-model comparison (watch free-tier rate limits):
  # - id: groq:llama-3.1-8b-instant
  #   config: { temperature: 0, max_tokens: 400 }
  # - id: groq:openai/gpt-oss-20b
  #   config: { temperature: 0, max_tokens: 400 }
```
`defaultTest.options.provider` and the `tests:` list (bias/consistency/
compliance) are unchanged.

**`promptfooconfig.quality.finance.yaml`** — identical provider-block edit;
`tests:` list (context/values) unchanged.

**Test-suite files** — each trimmed to exactly one case, per this mapping
(the case kept, and why):

| Suite | Axis kept | Case kept | Rationale |
|---|---|---|---|
| `tests/bias.medibot.yaml` | Safety | Refuse the ethnic-ranking request | Sharpest, most unambiguous bias-refusal test of the three |
| `tests/consistency.medibot.yaml` | Factual | Trivia yes/no stability | Deterministic (`icontains`), simplest signal for the consistency concept |
| `tests/compliance.medibot.yaml` | Reasoning | EU cross-border patient-data reasoning | Requires actual multi-step reasoning, not just a refusal |
| `tests/context.finance.yaml` | Factual | Needle-in-haystack retrieval | The literal concept the lesson is named for |
| `tests/values.finance.yaml` | Reasoning | "Overheard tip" moral dilemma | Requires reasoning through an ethical dilemma, not a flat refusal |

`context.finance.yaml`'s hidden-instruction/safety case is dropped —
prompt-injection resistance is already covered extensively by the base Act
1/2 red-team exercises, so this isn't a coverage loss. Net axis spread across
the 5 kept cases: factual×2, reasoning×2, safety×1 — all three axes remain
represented across the set even though each individual file now demonstrates
only one.

Cases are physically removed from each file (not commented out) — the repo's
existing convention reserves "commented = opt-in" for *providers*, not test
cases, and keeping removed cases as inline comments would bloat the files
without a clear precedent. The kept case's `description`/`vars.query`/`assert`
text is copied verbatim from the currently-shipped file (already on disk in
this branch) — not paraphrased or rewritten — so the surviving case is
byte-identical to what it replaces, just without its two removed siblings.

### Documentation updates

- **`docs/05-quality-challenges.md`**: update case-count references (no
  longer "8 cases" for MediBot), and reframe the 3-axis explanation from
  "each topic covers all 3 axes" to "axes are distributed across the 5
  topics" — include the mapping table above. The `--filter-metadata
  axis=safety` example command is unchanged (still valid, just now surfaces
  fewer/different matching cases).
- **`CLAUDE.md`**: soften the "3-axis attack taxonomy" section from "cover
  three axes per topic" to make clear a suite may cover all three axes in one
  file *or* focus on a single axis and let sibling suites cover the rest —
  noting the shipped gap-fill suites use the lean, single-axis-per-file
  pattern specifically to keep default live-eval request volume low.

### Expected resulting volume

- `promptfooconfig.quality.medibot.yaml`: 3 cases × 1 provider ≈ 6 total
  requests (was ≈48).
- `promptfooconfig.quality.finance.yaml`: 2 cases × 1 provider ≈ 4 total
  requests (was ≈30).

Both counts are well within what was already proven, live, to run in 1-4
seconds with 0 errors during verification (the identical content ran clean at
1 provider with the original, untrimmed case counts).

## Verification

- Each trimmed config runs live (`npx promptfoo@latest eval`, from repo root,
  with a real `GROQ_API_KEY`) with 0 errors, completing in a few seconds.
- `preflight.sh`'s keyless config-resolution check (added in the prior PR
  work) still passes — trimming cases doesn't remove any `file://` reference
  the check depends on.
- `docs/05-quality-challenges.md`'s case counts and axis-mapping table match
  the actual shipped test files exactly.
- `CLAUDE.md`'s taxonomy wording no longer contradicts the shipped
  single-axis-per-file pattern.

## Delivery

Lands as additional commits on the existing `consolidate-curriculum` branch
(PR #9 is still open, not yet merged) — pushing is a separate, explicit
confirmation step after implementation, matching how the original PR push was
handled.
