# STARWEST 2026 Agentic Testing Deck Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a surgically revised STARWEST 2026 PowerPoint (~50 main-flow slides plus a Q&A appendix) beside the original, without changing the original file.

**Architecture:** Copy the 65-slide working deck to a new `-Revised.pptx`, then mutate that copy with `python-pptx` for text/notes/hyperlinks and with direct OOXML only when python-pptx cannot clone or reorder reliably. Do not rebuild the deck from a blank template. Keep cream/black/yellow identity, speaker notes, QR images, and widescreen 20"×11.25" geometry. After each content wave, extract text+notes, then verify with LibreOffice PDF + contact sheets.

**Tech Stack:** Python 3, `python-pptx==1.0.2`, `lxml`, LibreOffice (`soffice`), Poppler (`pdftoppm`), ImageMagick (`montage`).

**Spec:** `docs/superpowers/specs/2026-09-16-starwest-agentic-testing-deck-design.md`

## Global Constraints

- Original file is read-only. Never open it for write. Never `prs.save()` to its path.
- Output filename must contain `-Revised` and sit in the same directory as the original.
- Surgical revision: keep the existing visual system (`FEFEF1` cream cards, `000000` type, `FFE67F` yellow frame/rules, Arial body, Courier New for code). No Arbon slate/orange theme. No stock images. No new visual language.
- Widescreen geometry stays `20.0 in × 11.25 in` (`18288000 × 10287000` EMU).
- Main flow target: 50 slides. Appendix after thank-you is allowed and expected.
- Do not copy the 14-slide Arbon book tour, Confidence Engineer rebrand, Chapter 21 predictions, or Arbon theme. Borrow only the punch lines listed in the spec.
- STARWEST metric language is primary: empirical pass rate vs `pass@k` (at least one success) vs `pass^k` (all k trials succeed). Never call ten repeated runs a `pass@k` baseline.
- Public-conference safety: generalize internal counts, BU×CDN matrices, live-encoder mutation capability, auth/topology, and thresholds-as-policy.
- Evidence labels required on measurement slides: `INTERNAL` / `ILLUSTRATIVE` / `PREPRINT` / `PUBLISHED`.
- Pair every new claim with a source footnote or a workshop-repo example that attendees can understand without cloning Promptfoo.
- Close PowerPoint / Keynote before copying. Ignore `~$*.pptx` lock files.
- Course-repo git: this plan is the only file that belongs in `Break-Into-AI-Testing`. Do not add PPTX binaries, `pf-agenta-tutorbot.json`, or scratch scripts to the course repo. Scratch scripts live beside the deck.
- Task "commit" steps below mean: write a `TASK-N.ok` stamp in the scratch dir after the task's assertion passes. Do not `git commit` binaries.

---

## File Structure

**Do not modify (checksum-guarded):**

- `/Users/gregory.goldshteyn/Documents/StarWest 2026/Herding_Cats_in_the_Cloud_-_STARWEST_2026 [Autosaved].pptx`
  - Working original. 65 slides, 65 notes slides, SHA-256 `4a8ec5f2607f40288ece41e88de39101c85fd101c261bf0738f1aef413c345b6`, size `4594148` bytes (as of plan write).
- `/Users/gregory.goldshteyn/Documents/StarWest 2026/Gregory-Goldshteyn-Herding_Cats_in_the_Cloud_-_STARWEST_2026.pptx`
  - Older sibling export. Leave untouched.
- `/Users/gregory.goldshteyn/Documents/eBooks/Testing-AI-Arbon-Summary.pptx`
  - Phrase reference only. Never copy slides, theme, or layouts from it.

**Create (output):**

- `/Users/gregory.goldshteyn/Documents/StarWest 2026/Herding_Cats_in_the_Cloud_-_STARWEST_2026-Revised.pptx`

**Create (scratch, outside the course repo):**

- `/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/helpers.py` — text, notes, reorder, clone, checksum helpers
- `/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/inventory.py` — dump titles/notes/hyperlinks/fonts from a deck
- `/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/assert_original.py` — original checksum + slide count
- `/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/assert_revised.py` — revised-deck acceptance
- `/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/01_workspace.py` through `07_verify.py` — one script per task
- `/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/out/` — inventories, PDF, PNGs, contact sheets, stamps
- `/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/mapping.json` — original index → keep/move/new decision table

**Read (workshop examples, do not copy source into slides):**

- `modules/01-red-team/04-grading-the-grader/README.md` — rubric passed a full leak; V1/V2/V3
- `prompts/payflow-multiturn.txt` — guard sees transcript above `--- CURRENT MESSAGE ---`, not retrieved payload
- `modules/03-app-testing/README.md` — assert `output.route` and `output.citations`, not prose
- `CLAUDE.md` — three-axis taxonomy; triplet; inverted vs ordinary scoring; deterministic + model-graded pair

---

## How to edit PPTX reliably

Use this stack in this order. Do not start with a from-scratch `Presentation()`.

### 1. python-pptx for in-place text and notes

Preserve run formatting. Never assign `shape.text = ...` on a designed slide (it collapses fonts).

```python
def set_run_text(shape, text: str) -> None:
    """Replace a shape's text while keeping the first run's font."""
    tf = shape.text_frame
    first = tf.paragraphs[0]
    for extra in list(tf.paragraphs)[1:]:
        extra._p.getparent().remove(extra._p)
    for extra_run in list(first.runs)[1:]:
        extra_run._r.getparent().remove(extra_run._r)
    if first.runs:
        first.runs[0].text = text
    else:
        first.text = text
```

For multi-paragraph bodies, keep paragraph count: write into existing paragraphs/runs in order; only add a paragraph when the design already had that many lines.

Notes: `slide.notes_slide.notes_text_frame.text = notes` is acceptable. python-pptx notes frames are not designed the same way as on-slide Arial/Courier.

### 2. Reorder by moving `sldIdLst` entries (do not delete+re-add)

```python
def move_slide(prs, old_index: int, new_index: int) -> None:
    sldIdLst = prs.slides._sldIdLst
    el = list(sldIdLst)[old_index]
    sldIdLst.remove(el)
    sldIdLst.insert(new_index, el)
```

This keeps the slide XML, relationships, notes, images, and hyperlinks attached. Deleting a slide with `drop_rel` and rebuilding it loses notes and pictures.

### 3. Clone via OOXML only when a new slide is required

python-pptx has no public `duplicate_slide`. For each new main-flow slide, clone a same-layout donor from the copy (prefer a cream content slide such as original 10 or 41, not the yellow title). Procedure:

1. Unzip the revised PPTX to `out/unzipped/` only inside a dedicated clone helper; never unzip the original.
2. Copy `ppt/slides/slideN.xml` → next free `slideM.xml`.
3. Copy `ppt/slides/_rels/slideN.xml.rels` → `slideM.xml.rels`. Rewrite any `notesSlide` relationship to a newly copied notes part, or drop the notes rel and add notes later via python-pptx.
4. Copy `ppt/notesSlides/notesSlideN.xml` + rels if notes must travel with the clone; then rewrite the notes' slide relationship back to `slideM`.
5. Register `slideM.xml` in `[Content_Types].xml` and in `ppt/_rels/presentation.xml.rels`, and append a `p:sldId` in `ppt/presentation.xml`.
6. Re-zip with stored `[Content_Types].xml` first (standard OOXML zip order). Validate by opening with python-pptx and counting slides.

Prefer cloning one well-known donor (`CLONE_DONOR_ORIG_INDEX = 4`, the black-claim slide, or `10` for a content slide) and then replacing text, rather than constructing shapes.

### 4. Hyperlinks

python-pptx click hyperlinks live on `shape.click_action` or run-level `run.hyperlink.address`. Original inventory found **zero** run hyperlinks; the sources slide is currently unlinked. Add bibliography URLs with:

```python
run.hyperlink.address = url
```

on the source-title run only. Do not wrap the whole slide. Preserve any existing `r:hyperlink` in slide rels if later inventory finds shape-level links.

QR codes on slide 2 are pictures (`PICS 2`). Do not delete or replace them.

### 5. Render / verify

```bash
/opt/homebrew/bin/soffice --headless --convert-to pdf \
  --outdir "/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/out" \
  "/Users/gregory.goldshteyn/Documents/StarWest 2026/Herding_Cats_in_the_Cloud_-_STARWEST_2026-Revised.pptx"

/opt/homebrew/bin/pdftoppm -r 72 -png \
  "/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/out/Herding_Cats_in_the_Cloud_-_STARWEST_2026-Revised.pdf" \
  "/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/out/slide"

/opt/homebrew/bin/montage \
  -density 72 -geometry 480x270+8+8 -tile 5x \
  "/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/out/slide-*.png" \
  "/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/out/contact-sheet.png"
```

Read the contact sheet plus any flagged slides. The render is the authority for clipping; python-pptx bounding boxes are not.

---

## Content mapping (original 1–65 → revised)

Indices below are **1-based original** indices.

### Main flow (50 slides, in this order)

| Rev | Orig | Action | Why |
|---|---|---|---|
| 1 | 1 | keep | Title. |
| 2 | 2 | keep | Speaker + QR. |
| 3 | 3 | rewrite body | Six sections → four acts matching the spec narrative. |
| 4 | 4 | keep | Load-bearing claim. |
| 5 | 5 | keep | Landscape. |
| 6 | 6 | keep | Traditional QA breaks. |
| 7 | 7 | keep | Cross-agent state. Thesis slide. |
| 8 | 9 | keep, retitle claim | Act 1 divider. Drop original 8 from main (internal counts). |
| 9 | 10 | **correct metrics** | Empirical vs `pass@k` vs `pass^k`. Label τ-bench 2024 GPT-4o. Relabel left tiles `ILLUSTRATIVE`. |
| 10 | new | anti-pattern punch | Retries are selection; pass rate is a property of the mix; cluster failures. Cream content clone. |
| 11 | new | compact agentic contract | plan → tool/args → permissions → recovery → side effects → final answer. |
| 12 | 15 | correct | Aggregation masking. Do not call it Simpson unless the numbers demonstrate it. `ILLUSTRATIVE` / Arbon. |
| 13 | 16 | strengthen notes | Judge one-liners in notes. |
| 14 | 17+18 | merge onto 17's layout | Ground truth missing + control contamination as one claim. |
| 15 | 19 | keep | Act 2 divider. |
| 16 | 20 | keep | Pyramid glance. |
| 17 | new | model → app → agent | Why prose-only asserts die. |
| 18 | 21 | keep | Tools are deterministic. |
| 19 | 22 | **generalize** | Remove live-encoder / 4 read / 6 write counts. Keep closed args + permission gate. |
| 20 | 23 | keep | Dry-run war story. |
| 21 | 24 | keep | Status-code cascade. |
| 22 | 25 | keep | Cognitive evals. |
| 23 | 27 | keep, tighten | Grading-the-grader V1/V2/V3. Workshop repo, no Promptfoo tutorial. |
| 24 | 30 | keep | Eval leaked its answer. |
| 25 | 31+32 | merge onto 31 | Suppression log + conservation of verdicts. |
| 26 | 34 | qualify | Single-author, single-system, non-peer-reviewed longitudinal preprint. |
| 27 | 35 | keep | Compounding reliability. |
| 28 | 36 | qualify | MAST NeurIPS; 1,642 traces predominantly LLM-annotated; humans developed/validated the taxonomy. |
| 29 | 37+38 | merge onto 37 | Race + invariant. Keep the pseudo-code if it still fits; else pseudo-code to appendix. |
| 30 | 40 | keep | Act 3 divider. |
| 31 | 41 | keep | Green suite claim. |
| 32 | 42 | keep | Stale oracle. |
| 33 | 43 | keep | Over-failing. |
| 34 | 45 | keep | Blind spots. |
| 35 | new | poisoned retrieval | Guard sees user message, not retrieved payload. `payflow-multiturn`. |
| 36 | new | route + citations | Assert structured fields, not prose. PayFlow. |
| 37 | new | overreliance vs refusal | Refusing a false premise is not correcting it. |
| 38 | 46 | keep | Untrusted model output. |
| 39 | 47 | compact | 4–5 named risks + guardrail questions. Full ASI list to appendix. |
| 40 | 48 | generalize + **fix notes** | Thresholds are `ILLUSTRATIVE`, not org policy. Replace duplicated slide-10 notes. |
| 41 | 49 | keep | Act 4 divider. |
| 42 | 50 | generalize | Five systems / no global ID — drop identifiable internal names if they encode topology. |
| 43 | 52 | strengthen | Commit / merge / nightly. Ordinary vs inverted scoring. Deterministic vs live vs generated. |
| 44 | 53 | keep | Config lied. |
| 45 | 54 | cite | July 2026 τ-bench 1.0.1, `banking_knowledge` only. |
| 46 | 55 | keep | Ship / canary / hold / rollback / collect. |
| 47 | 62 | keep | Compounding loop. |
| 48 | 63 | **correct takeaway 2** | Harness smoke vs `pass^k` reliability vs `pass@k` coverage. Drop “10×10 is pass@k baseline”. |
| 49 | 64 | rewrite | Linked bibliography, full titles, dates, labels. Add notes. |
| 50 | 65 | keep | Thank you + QR. Update jump list to new indices. |

### Appendix (after slide 50, Q&A)

Preserve these original slides by **moving** them, not deleting:

| Appendix order | Orig | Title to keep |
|---|---|---|
| A1 | 8 | Scale / closed action space (internal numbers stay off the main path) |
| A2 | 11 | Sample-size planning |
| A3 | 12 | Root-n interval |
| A4 | 13 | Accidental agreement measurement |
| A5 | 14 | Semantic distance |
| A6 | 26 | Nine-reviewer architecture |
| A7 | 28 | Nine-fixture grid |
| A8 | 29 | 42 findings breakdown |
| A9 | 33 | Unexplained null |
| A10 | 39 | Semantic guardrails |
| A11 | 44 | Dead letters |
| A12 | 47 clone or leftover full ASI table if 39 was compacted in place — if compacted in place, clone original 47 to appendix **before** compacting |
| A13 | 51 | 2026 vendor landscape |
| A14 | 57–61 | In-practice stack / MCP tool / 5×5 matrix / dense contract rows (move 60 and 61 for sure; 57–59 stay out of main unless a one-line “we run this” remains in notes of 47) |
| A15 | — | Optional one-slide “Arbon extras for Q&A”: Confidence Engineer hats, multiple-testing, “50 cases this week”, six predictions — **notes-heavy, cream theme, no book-tour layout** |

Original 18 is merged into 17: after copying 18’s distinctive claim into 17, move 18 to appendix as “control group used the tool” detail rather than deleting.

### Do not bring into the revised deck from Arbon

- Slides 1–14 of `Testing-AI-Arbon-Summary.pptx` as slides
- Confidence Engineer as a rebrand
- Chapter 21 six predictions as a main-flow list
- Slate/orange palette, 13.33"×7.5" geometry

### Known original defects the revision must fix

- Slides **10 and 48 share identical notes** (284 chars). Slide 48 notes must describe the red-team gate, not `pass@k`.
- Slide 64 has **empty notes**.
- Slide 10 left tiles are labeled like `PASS@5` / `PASS@10` while the right panel correctly contrasts `pass@1` vs `pass^8`. The left tiles are empirical rates from k runs, not `pass@k`.
- Slide 63 item 2 calls ten scenarios × ten runs a `pass@k` baseline.
- Slide 15 notes say “Simpson's paradox” for an illustration that may only be aggregation masking.
- Slide 3 still advertises six sections; spec is four acts.
- Slide 22 names live encoder start/stop and exact tool counts.
- Slide 8 names 14 repos, 18 services, 4×5 BU×CDN.
- Slide 48 presents numeric gates as operational policy.

---

## Bibliography (put on revised slide 49; verify URLs live in Task 4)

Use these titles. If a live page disagrees, keep the spec’s qualification and update the URL, do not invent a new paper.

1. **τ-bench (2024, published).** Sierra τ-bench retail results for a specific GPT-4o version and harness. Label: not current frontier performance. URL: `https://taubench.com/` plus the paper page found there.
2. **τ-bench 1.0.1 (July 2026).** Grading change scoped to `banking_knowledge`. Cite release notes, not the 2024 headline numbers.
3. **MAST (NeurIPS).** “Why Do Multi-Agent LLM Systems Fail?” 1,642 traces, predominantly LLM-annotated; human annotation developed and validated the taxonomy.
4. **Silent-failure / production runtime study (June 2026 preprint).** Single-author, single-system, non-peer-reviewed longitudinal preprint. Use the title already on original slide 34/64 and add `PREPRINT`.
5. **OWASP Top 10 for Large Language Model Applications** — official title + date on the live OWASP page.
6. **OWASP Top 10 for Agentic Applications** — official title; Agentic resource page date **9 December 2025**.
7. **OpenTelemetry GenAI semantic conventions** — status **Development**.
8. **Testing AI: Engineering Confidence in Non-Deterministic Systems**, Jason Arbon, first edition, July 2026.

Evidence chips on slides: `PUBLISHED` / `PREPRINT` / `ILLUSTRATIVE` / `INTERNAL` / `WORKSHOP`.

---

## New slide copy (use verbatim unless a later render forces a shorter wrap)

### Rev 10 — Anti-patterns near metrics

Kicker: `ANTI-PATTERNS`

Claim: `Retries are selection, not evaluation.`

Three cards:

1. `A retry that eventually passes did not measure the system. It sampled until the sample looked good.`
2. `A pass rate is a property of the test mix, not a property of the model.`
3. `Cluster failures into families before you file. One family is one bug.`

Notes: spoken point = card 1. Cut-for-time = cards 2–3. Transition: “If you need a contract that still holds when the wording changes, here it is.”

### Rev 11 — Compact agentic contract

Kicker: `THE CONTRACT`

Claim: `Test the trajectory, not just the final answer.`

Six numbered steps: `plan` → `tool and arguments` → `permissions` → `recovery` → `side effects` → `final answer`.

Optional spoken line in notes: `If a human would follow a checklist, build a parameterized workflow, not an agent.`

Map to workshop: outcome / trajectory / tool authority / state invariants / recovery / observability.

### Rev 17 — Model → application → agent

Kicker: `THE TARGET MOVED`

Claim: `Prose assertions stop being enough as soon as the system can act.`

Three columns:

- `MODEL` — string/rubric on the reply
- `APPLICATION` — `route`, `citations`, status codes
- `AGENT` — tools, args, permissions, state, recovery

Workshop: triplet (prompt / tests / provider); deterministic assert paired with model-graded assert.

### Rev 35 — Poisoned retrieval

Kicker: `BLIND CONTEXT`

Claim: `The guard classified the user. It never saw the retrieved payload.`

Diagram, left to right: `retrieved doc` → `hidden from guard` → `model` vs `user message` → `guard`.

Notes: PayFlow multi-turn plants the injection after four legitimate turns; the guard only sees the transcript above `--- CURRENT MESSAGE ---`. Do not name internal tickets as if they were FOX production.

### Rev 36 — Route and citations

Kicker: `ASSERT THE CONTRACT`

Claim: `A fluent answer can still cite the wrong specialist.`

Show a fake JSON stub (PayFlow-shaped, not a real FOX payload):

```json
{ "answer": "...", "route": { "specialists": ["jira"] }, "citations": [{ "id": "PF-104" }] }
```

Bullet: text can pass while `route` / `citations` fail. That is the finding.

### Rev 37 — Overreliance vs refusal

Kicker: `REFUSAL ≠ CORRECTION`

Claim: `Refusing a false premise is not the same as correcting it.`

Two columns: `SAFE REFUSAL` vs `OVERRELIANCE` (accepts the user’s false frame and acts). Three-axis tag in footer: `safety / factual`.

### Rev 39 guardrail add-on (same slide as compacted OWASP)

Questions: `allowed / blocked / escalated / constrained / logged`

Calibration bugs: `over-block` · `under-block` · `silent block`

---

## Speaker-note template (every main-flow slide)

Four labeled blocks, in this order:

```
SPOKEN: <one sentence>
CUT: <optional>
SOURCE: <qualification or "none">
NEXT: <one-line transition>
```

Keep existing speaker voice; do not genericize. If a note already has a strong spoken line, prefix the labels rather than rewriting from scratch.

Timing budget: 50 main slides in 40–42 minutes ≈ 45–50 seconds average, with claim slides slower and dividers at 15 seconds. Appendix is Q&A only.

---

### Task 1: Workspace, checksum, helpers, inventory

**Files:**

- Create: `/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/helpers.py`
- Create: `/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/assert_original.py`
- Create: `/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/inventory.py`
- Create: `/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/01_workspace.py`
- Create: `/Users/gregory.goldshteyn/Documents/StarWest 2026/Herding_Cats_in_the_Cloud_-_STARWEST_2026-Revised.pptx`

**Interfaces:**

- Consumes: original PPTX path and SHA-256 below
- Produces: `helpers.ORIGINAL_SHA256`, `helpers.copy_original_to_revised()`, `helpers.sha256_file(path) -> str`, `helpers.load(path) -> Presentation`, `helpers.dump_inventory(path, json_path)`

- [ ] **Step 1: Write the failing original assertion**

```python
#!/usr/bin/env python3
"""Guard: the STARWEST original deck must not change."""
from pathlib import Path
import hashlib
import sys

ORIGINAL = Path(
    "/Users/gregory.goldshteyn/Documents/StarWest 2026/"
    "Herding_Cats_in_the_Cloud_-_STARWEST_2026 [Autosaved].pptx"
)
EXPECTED_SHA256 = "4a8ec5f2607f40288ece41e88de39101c85fd101c261bf0738f1aef413c345b6"
EXPECTED_SIZE = 4594148
EXPECTED_SLIDES = 65

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def main() -> int:
    fails = []
    if not ORIGINAL.exists():
        fails.append(f"missing {ORIGINAL}")
    else:
        digest = sha256(ORIGINAL)
        size = ORIGINAL.stat().st_size
        if digest != EXPECTED_SHA256:
            fails.append(f"sha256 changed: {digest}")
        if size != EXPECTED_SIZE:
            fails.append(f"size {size} != {EXPECTED_SIZE}")
        from pptx import Presentation
        n = len(Presentation(str(ORIGINAL)).slides)
        if n != EXPECTED_SLIDES:
            fails.append(f"slides {n} != {EXPECTED_SLIDES}")
    for line in fails:
        print("FAIL", line)
    if fails:
        return 1
    print("OK original unchanged")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run it (expect PASS on the original)**

```bash
python3 "/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/assert_original.py"
```

Expected: `OK original unchanged`, exit 0. If SHA-256 differs, **stop** and update `EXPECTED_SHA256` only after the user confirms the Autosaved file was replaced on purpose.

- [ ] **Step 3: Write helpers.py**

```python
from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from pptx import Presentation
from pptx.enum.shapes import MSO_SHAPE_TYPE

ORIGINAL = Path(
    "/Users/gregory.goldshteyn/Documents/StarWest 2026/"
    "Herding_Cats_in_the_Cloud_-_STARWEST_2026 [Autosaved].pptx"
)
REVISED = Path(
    "/Users/gregory.goldshteyn/Documents/StarWest 2026/"
    "Herding_Cats_in_the_Cloud_-_STARWEST_2026-Revised.pptx"
)
SCRATCH = Path("/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise")
OUT = SCRATCH / "out"
ORIGINAL_SHA256 = "4a8ec5f2607f40288ece41e88de39101c85fd101c261bf0738f1aef413c345b6"
CREAM = "FEFEF1"
YELLOW = "FFE67F"
BLACK = "000000"

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def assert_original_untouched() -> None:
    digest = sha256_file(ORIGINAL)
    if digest != ORIGINAL_SHA256:
        raise RuntimeError(f"original checksum changed: {digest}")

def copy_original_to_revised() -> None:
    assert_original_untouched()
    if REVISED.exists() and sha256_file(REVISED) == sha256_file(ORIGINAL):
        return
    shutil.copy2(ORIGINAL, REVISED)
    if sha256_file(REVISED) != ORIGINAL_SHA256:
        raise RuntimeError("copy produced a different checksum")

def load_revised() -> Presentation:
    assert_original_untouched()
    return Presentation(str(REVISED))

def save_revised(prs: Presentation) -> None:
    prs.save(str(REVISED))
    assert_original_untouched()

def set_run_text(shape, text: str) -> None:
    tf = shape.text_frame
    first = tf.paragraphs[0]
    for extra in list(tf.paragraphs)[1:]:
        extra._p.getparent().remove(extra._p)
    for extra_run in list(first.runs)[1:]:
        extra_run._r.getparent().remove(extra_run._r)
    if first.runs:
        first.runs[0].text = text
    else:
        first.text = text

def shape_by_text_prefix(slide, prefix: str):
    for shape in slide.shapes:
        if shape.has_text_frame and shape.text_frame.text.strip().startswith(prefix):
            return shape
    raise KeyError(prefix)

def notes_of(slide) -> str:
    if not slide.has_notes_slide:
        return ""
    return slide.notes_slide.notes_text_frame.text

def set_notes(slide, text: str) -> None:
    slide.notes_slide.notes_text_frame.text = text

def move_slide(prs: Presentation, old_index: int, new_index: int) -> None:
    sldIdLst = prs.slides._sldIdLst
    el = list(sldIdLst)[old_index]
    sldIdLst.remove(el)
    sldIdLst.insert(new_index, el)

def all_text(slide) -> str:
    parts = []
    for shape in slide.shapes:
        if shape.has_text_frame:
            parts.append(shape.text_frame.text)
    return "\n".join(parts)

def dump_inventory(path: Path, json_path: Path) -> None:
    prs = Presentation(str(path))
    slides = []
    for i, slide in enumerate(prs.slides, 1):
        hrefs = []
        for shape in slide.shapes:
            if shape.has_text_frame:
                for p in shape.text_frame.paragraphs:
                    for r in p.runs:
                        if r.hyperlink and r.hyperlink.address:
                            hrefs.append(r.hyperlink.address)
            if shape.shape_type == MSO_SHAPE_TYPE.PICTURE:
                hrefs.append("PICTURE")
        slides.append({
            "index": i,
            "text": all_text(slide),
            "notes": notes_of(slide),
            "hrefs": hrefs,
            "shape_count": len(slide.shapes),
        })
    json_path.write_text(json.dumps({
        "path": str(path),
        "sha256": sha256_file(path),
        "slide_count": len(prs.slides),
        "width_in": prs.slide_width.inches,
        "height_in": prs.slide_height.inches,
        "slides": slides,
    }, indent=2))
```

- [ ] **Step 4: Write inventory.py and 01_workspace.py**

`inventory.py` calls `dump_inventory` for whichever path is argv[1].

`01_workspace.py`:

```python
from helpers import OUT, REVISED, copy_original_to_revised, dump_inventory, ORIGINAL

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    copy_original_to_revised()
    dump_inventory(ORIGINAL, OUT / "original.json")
    dump_inventory(REVISED, OUT / "revised-after-copy.json")

if __name__ == "__main__":
    main()
```

- [ ] **Step 5: Run workspace copy**

```bash
python3 "/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/01_workspace.py"
python3 "/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/assert_original.py"
python3 - <<'PY'
from pathlib import Path
import json, hashlib
from pptx import Presentation
rev = Path("/Users/gregory.goldshteyn/Documents/StarWest 2026/Herding_Cats_in_the_Cloud_-_STARWEST_2026-Revised.pptx")
orig = Path("/Users/gregory.goldshteyn/Documents/StarWest 2026/Herding_Cats_in_the_Cloud_-_STARWEST_2026 [Autosaved].pptx")
assert hashlib.sha256(orig.read_bytes()).hexdigest() == hashlib.sha256(rev.read_bytes()).hexdigest()
assert len(Presentation(str(rev)).slides) == 65
print("OK copy identical, 65 slides")
PY
```

Expected: copy identical to original; original checksum still matches.

- [ ] **Step 6: Stamp**

```bash
date > "/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/out/TASK-1.ok"
```

---

### Task 2: Metric terminology and Monday takeaway

**Files:**

- Modify: revised PPTX slides orig 10, 15, 63 (0-based 9, 14, 62) **before any reorder**
- Create: `.../starwest-2026-revise/02_metrics.py`
- Test: `.../starwest-2026-revise/assert_revised.py` (first slice)

**Interfaces:**

- Consumes: `helpers.load_revised`, `helpers.save_revised`, `helpers.set_run_text`
- Produces: corrected metric language on those three slides

- [ ] **Step 1: Write the failing terminology checks into assert_revised.py**

```python
#!/usr/bin/env python3
from pathlib import Path
import sys
from pptx import Presentation

REVISED = Path(
    "/Users/gregory.goldshteyn/Documents/StarWest 2026/"
    "Herding_Cats_in_the_Cloud_-_STARWEST_2026-Revised.pptx"
)
ORIGINAL = Path(
    "/Users/gregory.goldshteyn/Documents/StarWest 2026/"
    "Herding_Cats_in_the_Cloud_-_STARWEST_2026 [Autosaved].pptx"
)
EXPECTED_ORIG = "4a8ec5f2607f40288ece41e88de39101c85fd101c261bf0738f1aef413c345b6"

def sha256(path: Path) -> str:
    import hashlib
    return hashlib.sha256(path.read_bytes()).hexdigest()

def corpus(prs) -> str:
    parts = []
    for s in prs.slides:
        for sh in s.shapes:
            if sh.has_text_frame:
                parts.append(sh.text_frame.text)
        if s.has_notes_slide:
            parts.append(s.notes_slide.notes_text_frame.text)
    return "\n".join(parts)

def main() -> int:
    fails = []
    if sha256(ORIGINAL) != EXPECTED_ORIG:
        fails.append("original checksum changed")
    prs = Presentation(str(REVISED))
    text = corpus(prs)
    if "That’s your pass@k baseline" in text or "That's your pass@k baseline" in text:
        fails.append("takeaway still calls 10x10 a pass@k baseline")
    if "PASS@5" in text or "PASS@10" in text:
        fails.append("left tiles still labeled PASS@k for empirical rates")
    if "pass@k" not in text.lower() and "pass@k" not in text:
        fails.append("pass@k language missing")
    if "pass^k" not in text and "pass^8" not in text:
        fails.append("pass^k language missing")
    for line in fails:
        print("FAIL", line)
    if fails:
        return 1
    print("OK metrics terminology")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run assert_revised.py — expect FAIL**

```bash
python3 "/Users/gregory.goldshteyn/Documents/StarWest 2026/starwest-2026-revise/assert_revised.py"; echo exit=$?
```

Expected: FAIL on takeaway baseline and `PASS@5` / `PASS@10`.

- [ ] **Step 3: Implement 02_metrics.py**

On original slide 10:

- Change kicker claim from `Pass@k — success as a rate` to `Three numbers, three jobs`
- Body: `Empirical pass rate is what you observed. pass@k is whether any of k runs succeeded. pass^k is whether all k succeeded.`
- Relabel left tiles: `1 RUN` / `5 RUNS` / `10 RUNS` / `SHIP GATE` with chip `ILLUSTRATIVE · one scenario`
- Keep right panel `PUBLISHED · τ-bench retail, GPT-4o (2024 harness)` and the `pass@1` vs `pass^8` contrast
- Notes SPOKEN: coverage vs reliability vs a single observed rate. SOURCE: τ-bench 2024 GPT-4o, not current frontier.

On original slide 15:

- Claim stays `Users do not experience the average`
- Body must say `Aggregation can hide a failing slice. Call it Simpson's paradox only if the same table shows the reversal.`
- Chip: `ILLUSTRATIVE · Testing AI`
- Notes: drop the unqualified Simpson naming.

On original slide 63 item 2:

- Title: `Separate smoke, reliability, and coverage`
- Body: `Harness smoke is one run. Reliability is pass^k. Coverage is pass@k. Ten repeats of one prompt are not independent observations.`

Use `shape_by_text_prefix` / exact current strings so formatting stays.

- [ ] **Step 4: Run 02_metrics.py then assert_revised.py**

Expected: `OK metrics terminology`. Original checksum still matches.

- [ ] **Step 5: Stamp TASK-2.ok**

---

### Task 3: Public-conference safety generalizations

**Files:**

- Modify: revised slides orig 8 (even though later appendix), 22, 48, 50, 57 if they remain
- Create: `.../03_safety.py`

**Interfaces:**

- Consumes: same helpers
- Produces: no live-encoder mutation, no 14/18/4×5 as current org fact, no policy-flavored red-team thresholds

- [ ] **Step 1: Extend assert_revised.py with banned strings**

Add:

```python
BANNED = [
    "start and stop live encoders",
    "MUTATE A LIVE CHANNEL",
    "automation repos an agent can dispatch",
    "business units × CDNs",
    "business units x CDNs",
]
for banned in BANNED:
    if banned in text:
        fails.append(f"sensitive phrase still present: {banned!r}")
```

Also require slide 48 notes ≠ slide 10 notes:

```python
notes = [s.notes_slide.notes_text_frame.text if s.has_notes_slide else "" for s in prs.slides]
# After reorder this check uses title match instead of index:
from collections import defaultdict
by_title = {}
for s in prs.slides:
    title = next((sh.text_frame.text.strip() for sh in s.shapes if sh.has_text_frame and sh.text_frame.text.strip()), "")
    if s.has_notes_slide:
        by_title.setdefault(title, []).append(s.notes_slide.notes_text_frame.text)
# Direct: find kickers
k10 = k48 = None
for s in prs.slides:
    t = "\n".join(sh.text_frame.text for sh in s.shapes if sh.has_text_frame)
    if "Pass@k" in t or "Three numbers, three jobs" in t:
        k10 = s.notes_slide.notes_text_frame.text
    if "SECURITY · RED TEAMING" in t or "The red-team gate" in t:
        k48 = s.notes_slide.notes_text_frame.text
if k10 is None or k48 is None:
    fails.append("could not find metrics or red-team notes")
elif k10 == k48:
    fails.append("red-team notes still duplicated from metrics")
```

- [ ] **Step 2: Run — expect FAIL on encoder / matrix strings**

- [ ] **Step 3: Implement 03_safety.py**

Original 8 (will become appendix A1): change `14` / `18` / `4 × 5` captions to generalized language: `finite suites`, `finite services`, `finite delivery matrix`, keep `FREE-TEXT INPUTS 0`. Subtitle: `Illustrative of a closed action space, not a capacity report.`

Original 22: replace encoder claim with `Write tools and read tools are different test problems. Mutation requires a permission gate that is tested as a mechanism, never as prompt phrasing.` Remove `WRITE TOOLS · 6 — MUTATE A LIVE CHANNEL`.

Original 48: add chip `ILLUSTRATIVE THRESHOLDS · not a published policy`. Notes:

```
SPOKEN: Thresholds are written before the run so they cannot be negotiated after it.
CUT: Severity rows.
SOURCE: Workshop red-team gate pattern; numbers on this slide are illustrative.
NEXT: Observability is how you find out whether the gate saw the same system you tested.
```

Original 50: keep the “no global ID” claim; if a row names an internal service topology that is not already public, replace the name with a role (`CDN logs`, `player telemetry`, `origin`, `app logs`, `session store`).

- [ ] **Step 4: Re-run assert_revised.py — expect those bans gone, notes no longer duplicated**

- [ ] **Step 5: Stamp TASK-3.ok**

---

### Task 4: Sources, labels, hyperlinks, Arbon citation

**Files:**

- Modify: revised orig 10, 15, 34, 36, 51 (if still present), 54, 64
- Create: `.../04_sources.py`

**Interfaces:**

- Produces: bibliography URLs on the sources slide; `Development` on OTel; full Testing AI subtitle

- [ ] **Step 1: Add assertions**

```python
required = [
    "Engineering Confidence in Non-Deterministic Systems",
    "December 9, 2025",
    "Development",
    "banking_knowledge",
    "predominantly LLM-annotated",
]
for token in required:
    if token not in text:
        fails.append(f"missing source token: {token!r}")
# at least 5 http hyperlinks on the sources slide
href_count = 0
for s in prs.slides:
    blob = "\n".join(sh.text_frame.text for sh in s.shapes if sh.has_text_frame)
    if blob.strip().startswith("SOURCES") or "\nSOURCES\n" in blob:
        for sh in s.shapes:
            if sh.has_text_frame:
                for p in sh.text_frame.paragraphs:
                    for r in p.runs:
                        if r.hyperlink and r.hyperlink.address:
                            href_count += 1
if href_count < 5:
    fails.append(f"sources slide hyperlinks {href_count} < 5")
```

- [ ] **Step 2: Run — expect FAIL (empty notes, missing subtitle, no hyperlinks)**

- [ ] **Step 3: Fetch live titles**

```bash
curl -sI "https://taubench.com/" | head -n 5
curl -sI "https://owasp.org/www-project-top-10-for-large-language-model-applications/" | head -n 5
```

Use WebFetch/WebSearch if curl is not enough. Write the verified titles into `out/bibliography.json` with `title`, `url`, `label`, `date`. Then 04_sources.py reads that JSON.

Required qualifications on-slide, not only in notes:

- τ-bench panel: `PUBLISHED 2024 · GPT-4o · specific harness — not current frontier`
- MAST: `PUBLISHED · NeurIPS · traces mostly LLM-annotated`
- Slide 34: `PREPRINT · single system · not peer reviewed`
- Slide 51 / appendix vendor table: `OTel GenAI conventions: Development`
- Slide 54: `τ-bench 1.0.1 · July 2026 · banking_knowledge only`
- Sources row 6: full subtitle, first edition, July 2026

- [ ] **Step 4: Implement 04_sources.py** — rewrite orig 64 six rows to the bibliography list; set notes using the four-block template; add `run.hyperlink.address` for each URL.

- [ ] **Step 5: Re-run assert_revised.py**

- [ ] **Step 6: Stamp TASK-4.ok**

---

### Task 5: New main-flow slides (clone + fill)

**Files:**

- Modify: revised PPTX (adds 6 clones before reorder)
- Create: `.../05_new_slides.py`
- Create: `.../clone_slide.py` (OOXML clone helper)

**Interfaces:**

- Consumes: donor slide original index 41 (simple cream claim) for short-claim slides; donor 21 for three-column slides
- Produces: six new slides appended (clone always appends, Task 6 moves them)

- [ ] **Step 1: Write clone_slide.py**

Implement the OOXML procedure in “How to edit PPTX reliably” §3. Function:

```python
def clone_slide(pptx_path: Path, donor_index_0: int) -> int:
    """Clone donor (0-based) to the end. Return new 0-based index.
    Preserve notes XML. Do not open ORIGINAL."""
```

After clone, `len(Presentation(pptx).slides)` increases by 1 and `notes_of(new) == notes_of(donor)` until overwritten.

Include a self-check in the helper: unzip to `OUT/unzipped-clone/`, never to the original’s directory.

- [ ] **Step 2: Failing test — new claims absent**

```python
for token in [
    "Retries are selection, not evaluation",
    "Test the trajectory, not just the final answer",
    "Prose assertions stop being enough",
    "never saw the retrieved payload",
    "fluent answer can still cite",
    "Refusing a false premise",
]:
    if token not in text:
        fails.append(f"missing new slide token: {token!r}")
```

Run assert — FAIL.

- [ ] **Step 3: 05_new_slides.py clones six times and fills copy from the “New slide copy” section**

Set notes with the four-block template. Do not copy Arbon layouts. Confirm fonts remain Arial after fill by sampling `run.font.name`.

- [ ] **Step 4: Run inventory; expect 71 slides (65+6). Original still 65 and checksum-stable.**

- [ ] **Step 5: Stamp TASK-5.ok**

---

### Task 6: Reorder main flow and move appendix

**Files:**

- Modify: revised PPTX slide order only (plus agenda rewrite on orig 3; compact orig 47 **after** cloning it to the end for appendix)
- Create: `.../06_reorder.py`
- Create: `.../mapping.json`

**Interfaces:**

- Consumes: mapping table in this plan
- Produces: slides 1–50 = main flow; 51+ = appendix; agenda lists four acts

`mapping.json` stores original 1-based index plus `"role": "main"|"appendix"|"merged-away"|"new"` and `new_index`.

- [ ] **Step 1: Before compacting original 47, clone it to the end so the full ASI table survives in appendix.**

- [ ] **Step 2: Compact original 47 in place** to 4–5 yellow-highlighted risks + guardrail questions. Full list now exists only on the clone.

- [ ] **Step 3: Merge content**

- Orig 18 distinctive sentence onto orig 17, then orig 18 is appendix.
- Orig 32 conservation one-liner onto orig 31.
- Orig 38 invariant: if it still fits on orig 37, copy the pseudo-code; else leave 38 in appendix and say so in 37 notes.
- Orig 57–59: do not keep as main; appendix.

- [ ] **Step 4: Rewrite agenda (orig 3) to four acts**

```
1 The testing contract changed
2 Build evidence in layers
3 Test the oracle and the control plane
4 Operate a compounding loop
```

Drop items 5–6 from the visible grid (hide leftover numbered shapes by setting text to empty **only if** they would clip; prefer deleting those extra numbered groups via `sp.getparent().remove(sp)` after cloning any needed bits). If removal risks layout collapse, cover with a cream rectangle `FEFEF1` matching the card — last resort.

- [ ] **Step 5: Reorder with `move_slide` until the sequence matches the 50-row table.**

Implementation tip: build `desired` as a list of slide XML rIds in target order, then rebuild `sldIdLst` once. Do not bubble-sort with many moves if a single rebuild is clearer:

```python
def set_order(prs, old_indices_in_new_order: list[int]) -> None:
    sldIdLst = prs.slides._sldIdLst
    els = list(sldIdLst)
    for el in els:
        sldIdLst.remove(el)
    for i in old_indices_in_new_order:
        sldIdLst.append(els[i])
```

`old_indices_in_new_order` is computed from `mapping.json` after clones.

- [ ] **Step 6: Assertions**

```python
if len(prs.slides) < 62:
    fails.append(f"expected >= 62 slides (50 main + appendix), got {len(prs.slides)}")
main = prs.slides[:50]
app = "\n".join(all_text(s) for s in prs.slides[50:])
main_text = "\n".join(all_text(s) for s in main)
if "Thank you" not in all_text(main[-1]) and "THANK YOU" not in all_text(main[-1]).upper():
    fails.append("slide 50 must be the thank-you closer")
if "The 2026 tooling landscape" in main_text:
    fails.append("vendor landscape still in main flow")
if "Nine fixtures, one run, nine passes" in main_text:
    fails.append("nine-fixture grid still in main flow")
if "Five properties, five test types" in main_text:
    fails.append("5x5 matrix still in main flow")
if "The 2026 tooling landscape" not in app:
    fails.append("vendor landscape missing from appendix")
if "The testing contract changed" not in all_text(prs.slides[2]):
    fails.append("agenda missing four-act language")
```

If a merge forces 49 or 51, stop and fix mapping rather than loosening the assert. Spec says approximately 50; this plan locks 50 so timing notes stay honest.

- [ ] **Step 7: Stamp TASK-6.ok**

---

### Task 7: Notes pass, thank-you jumps, identity check

**Files:**

- Modify: notes on every main-flow slide; thank-you notes
- Create: `.../07_notes.py`

**Interfaces:**

- Produces: every main slide notes contain `SPOKEN:`; thank-you jump list uses revised indices for dry-run, grader, poison, sources

- [ ] **Step 1: Assertion**

```python
for i, s in enumerate(prs.slides[:50], 1):
    n = s.notes_slide.notes_text_frame.text if s.has_notes_slide else ""
    if "SPOKEN:" not in n:
        fails.append(f"main {i} missing SPOKEN:")
    if len(n.strip()) < 40:
        fails.append(f"main {i} notes too short")
# duplicate notes in main flow
from collections import Counter
c = Counter(s.notes_slide.notes_text_frame.text for s in prs.slides[:50] if s.has_notes_slide)
dups = [k for k,v in c.items() if v > 1 and len(k) > 80]
if dups:
    fails.append("duplicate long notes in main flow")
```

- [ ] **Step 2: 07_notes.py** walks main slides. If `SPOKEN:` missing, wrap existing notes:

```
SPOKEN: {first sentence of old notes}
CUT: {rest}
SOURCE: none
NEXT: {keep last sentence if it was a transition}
```

Do not invent a new voice. Fix thank-you notes: `Keep the dry-run, grading-the-grader, poisoned-retrieval, and sources slides ready to jump.`

Optional appendix slide for Arbon extras: notes only, cream donor clone, title `Q&A · extra reading`. Body four bullets max. Not in the 50.

- [ ] **Step 3: Identity assertion**

```python
from zipfile import ZipFile
from lxml import etree
with ZipFile(REVISED) as z:
    xml = z.read("ppt/slides/slide1.xml")
root = etree.fromstring(xml)
vals = set(el.get("val") for el in root.xpath(".//*[local-name()='srgbClr']"))
if "FEFEF1" not in vals and "FFE67F" not in vals:
    fails.append(f"title slide lost cream/yellow fills: {vals}")
```

Fonts: still Arial + Courier New only in sampled runs (allow `None` which inherits).

- [ ] **Step 4: Stamp TASK-7.ok**

---

### Task 8: Render, contact sheets, hyperlink check, original checksum

**Files:**

- Create: `.../08_verify.sh`
- Create: `.../out/slide-*.png`, `.../out/contact-sheet.png`, `.../out/Herding_Cats_in_the_Cloud_-_STARWEST_2026-Revised.pdf`
- Modify: revised PPTX only if render shows clipping

**Interfaces:**

- Consumes: LibreOffice / pdftoppm / montage paths in this plan
- Produces: visual pass + `assert_original.py` still green

- [ ] **Step 1: Export PDF and PNGs using the exact commands in “How to edit PPTX reliably” §5**

If `soffice` fails because the file is open, close the lock (`~$`) and retry. Never convert the original.

- [ ] **Step 2: `pdfinfo` page count equals `len(prs.slides)`**

```bash
/opt/homebrew/bin/pdfinfo "$PDF" | sed -n 's/Pages: *//p'
```

- [ ] **Step 3: Contact sheet + targeted reads**

Read these PNGs (1-based PDF page = slide index):

- 1 title
- 3 agenda
- 9 metrics
- 10 anti-patterns
- 11 contract
- 19 generalized tools
- 23 grader V1/V2/V3
- 35–37 new workshop examples
- 40 red-team
- 48 takeaways
- 49 sources
- 50 thank you
- 51 first appendix slide

Look for: clipped Courier, overlapping footer `Herding Cats in the Cloud · STARWEST 2026` vs body, missing yellow rule, empty cloned leftover shapes, Arbon orange, overflow past the cream card.

If clipping: fix in python-pptx by reducing font size on that shape’s runs only (`run.font.size` keep ≥ 18pt on body, ≥ 28pt on claims). Re-export that page.

- [ ] **Step 4: Hyperlink smoke**

```python
# collect run.hyperlink.address from sources slide; curl -I each; allow 200/301/302
```

Fail on 404.

- [ ] **Step 5: Final assert_revised.py + assert_original.py**

`assert_revised.py` final bundle:

- original SHA-256 unchanged
- revised path contains `-Revised`
- revised SHA-256 **differs** from original (edits happened)
- 50 main slides
- appendix contains vendor landscape, nine-fixture, sample-size, 5×5 or dense contract
- banned sensitive strings absent from **main** (appendix may retain orig 8 numbers because it is off the 45-minute path; still avoid encoder mutation anywhere)
- encoder mutation absent from entire deck
- metric terminology constraints
- `SPOKEN:` on all main notes
- ≥5 bibliography hyperlinks
- geometry 20.0 × 11.25 in
- fonts Arial / Courier New only

- [ ] **Step 6: Stamp TASK-8.ok**

Do not copy the PDF back over the PPTX. Do not overwrite the original. Leave `Gregory-Goldshteyn-Herding_Cats_in_the_Cloud_-_STARWEST_2026.pptx` untouched.

---

## Self-review (plan author)

**Spec coverage**

| Spec requirement | Task |
|---|---|
| ~50 main + appendix; original unchanged; `-Revised` beside it | 1, 6, 8 |
| Four acts / thesis “test the workflow” | 6 agenda + mapping |
| Repo examples (taxonomy, triplet, grader, route/citations, overreliance, injection, inverted scoring, CI, traces) | 5, 6, 7 |
| Metric terminology + sample-size independence | 2, appendix 11–12 |
| Compact contract + model/app/agent | 5 |
| Arbon punch lines only | 5, 7 extras |
| Move dense tables to appendix | 6 |
| Public-conference safety | 3 |
| Evidence qualifications + Testing AI subtitle + OTel Development + τ-bench 1.0.1 + MAST + OWASP date | 4 |
| Cream/black/yellow; one claim per main slide; notes template; 40–42 min | 5–7 |
| Hyperlinks, QR, PDF, contact sheets, checksum | 8 |
| python-pptx / OOXML / reorder / notes preservation | intro + 5–6 |

**Placeholder scan:** no TBD/TODO. Clone helper, mapping, copy, asserts, and render commands are specified.

**Type/name consistency:** `ORIGINAL`, `REVISED`, `SCRATCH`, `OUT`, `set_run_text`, `move_slide`, `clone_slide`, `load_revised`, `save_revised`, `assert_original.py`, `assert_revised.py` used with the same paths throughout.

**Risks the implementer must not “fix” by loosening asserts**

- Slide count drifting to 58 because appendix slides were left in the main path.
- `shape.text =` wiping Arial.
- Deleting slides instead of moving them (notes/QR loss).
- Saving onto the Autosaved original.
- Rebuilding in 16:9 13.33"×7.5".
)
