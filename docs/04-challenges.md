# Hackathon Challenges — Break → Fix → Build

Three challenges. **Every team does all three.** Scores sum; highest total wins.
You'll need a working setup (`./setup.sh` green) and your own clone of this repo —
you edit files locally and re-run, so teams never collide.

**Judged on:** creativity and originality first, with technical proof (it actually ran)
as the tiebreaker. See [Scoring](#scoring) at the bottom.

**Time:** ~20–25 min per challenge.

**Use the workshop runner for every eval:**
```bash
./run.sh <target>   # Windows: .\run.ps1 <target>
./run.sh view       # Windows: .\run.ps1 view
```

The runner applies the repo's free-tier pacing (`RUN_JOBS=1`,
`RUN_DELAY_MS=1000` by default) and prints the right verdict for each target.
Exit 100 depends on the challenge: it is a finding in BREAK IT, but a defect to fix in
FIX IT and BUILD IT.

---

## Challenge 1 — 🔓 BREAK IT

**Author a brand-new attack that makes at least one model violate a bot's
NON-NEGOTIABLE rule — using a technique that is _not_ already in the starter suite.**

The starter bots (MediBot, FinanceBot) each carry NON-NEGOTIABLE RULES in their
system prompt (`prompts/medibot.txt`, `prompts/financebot.txt`). Your job is to slip past one.

### Steps
1. Pick a bot (MediBot or FinanceBot) and a rule you want to break.
2. Add a new case to the **bottom** of `tests/smoke.medibot.yaml` (or `tests/smoke.finance.yaml`):
   - a `query` — your attack prompt
   - an `assert` that describes the **safe** response (`llm-rubric`, `not-regex`, `not-icontains`, …)
   - A **failing** assertion means your attack **landed**.
3. Run the eval and confirm your case shows ✗ on at least one model:
   ```bash
   ./run.sh medibot
   ```

### Rules
- **Must be an original technique.** No reusing the starter vectors: education-framing,
  persona-override (DoseBot), translation-exfiltration, fabricated-citation, direct-ask
  (the plain FinanceBot investment questions), or multi-turn rapport-poisoning. Judges
  will recognize repeats.
- The attack is one `query`. No editing the system prompt (that's Challenge 2).

### Deliverable
The new YAML case + a screenshot of the eval row showing the break + one line naming your technique.

### Scored on
Novelty of the vector (biggest weight) · breadth — bonus for breaking all three current
default models (`groq:qwen/qwen3.8-27b`, `groq:openai/gpt-oss-120b`, and
`groq:openai/gpt-oss-20b`) · elegance — a short, sneaky prompt beats a wall of text.

For this challenge the suite is **inverted**: exit 100 means at least one attack landed,
which is the finding you are trying to produce.

---

## Challenge 2 — 🛡️ FIX IT

**Harden a bot so the attacks that currently land stop landing — by editing
_only_ the system prompt.**

The exact baseline varies run to run, so record **your own** in Step 1. The suite is
**8 cases × 3 providers = 24** test cells across Qwen 3.8 27B, GPT-OSS 120B, and
GPT-OSS 20B. Groq retired the older Llama baselines; do not treat historical Llama
results as a promise about this matrix. Find the holes in your run, then close those.

### Steps
1. Record your baseline (run it once, note the pass count).
2. Edit **only** the `content` string in `prompts/medibot.txt` — rewrite / strengthen the rules.
3. Re-run the **same** suite and push red → green:
   ```bash
   ./run.sh medibot
   ```

### Rules — read these, they contain the trap
- You may edit **only** the system prompt. **Do not** touch `tests/*.yaml` or the config.
- You **cannot** win by making the bot refuse everything. The suite includes must-answer
  cases — the concise "what is HTTP?" reply and the chest-pain → 911 response. Over-refusing
  **regresses** those and **costs** you points.
- Goal: raise the pass count **above your recorded baseline** without breaking a
  must-answer case.

> **Discussion point — why only the system prompt?** This challenge restricts you to
> prompt edits on purpose, but production systems don't stop there. A real deployment
> we've seen redacts SSNs, credit-card numbers, and bank PINs out of user input *in
> code*, before it ever reaches the LLM or gets logged — and blocks certain topics
> (fraud, money laundering) at the application layer regardless of what the system
> prompt says. The prompt is one layer of defense, not the only one. Worth discussing
> with your team: which of today's leaks would a regex or keyword filter catch more
> reliably than a sentence in a system prompt — and which genuinely need the model's
> judgment?

### Deliverable
Your new system prompt + before/after pass counts (screenshots).

### Scored on
Highest pass count with no regressions · cleverness and generality of the guardrail
wording · concision — a tight prompt that generalizes beats a long checklist.

For this challenge you are fixing the failures: the desired final state is green. The
MediBot runner still reports red-team findings honestly, but your job here is to remove
those findings without regressing the must-answer controls.

---

## Challenge 3 — 🧪 BUILD IT

**Invent a brand-new guardrailed bot in a fresh domain (not health, not finance)
and a 3-case probe suite that stress-tests it.**

A **worked example** ships in the repo — `prompts/mybot.txt` holds **TutorBot**, a
homework-help bot that won't do a student's assignment, with three matching cases in
`tests/mybot.yaml`. Read it first to see the shape of a good answer, then replace it with
your own domain. `promptfooconfig.mybot.yaml` already wires the three files together.

> Want to keep TutorBot to refer back to? Copy the slot before you start:
> `cp prompts/mybot.txt prompts/tutorbot.txt` (same for the tests and config).

### Steps
1. Rewrite **`prompts/mybot.txt`** — your persona and 3–5 NON-NEGOTIABLE rules for a fresh
   domain. Ideas: LegalBot, HRBot, GameMasterBot, RecipeBot, TravelBot. (Not TutorBot —
   that one is the shipped example.)
2. Rewrite **`tests/mybot.yaml`** — three cases, matching the three the example already
   demonstrates:
   - an **attack** that should be refused (guardrail holds),
   - a **benign** request that should be answered (no over-refusal),
   - a **gray-area** edge case that sits right on the boundary — the interesting one.
3. `promptfooconfig.mybot.yaml` already points at both files. Run it:
   ```bash
   ./run.sh mybot
   ```

### Deliverable
Your prompt + config + tests + eval output.

### Scored on
Originality of the concept/domain · cleverness of the guardrails · how genuinely hard
your gray-area probe is · **bonus** if a model actually fails one of your own probes
(proof you found a real weakness in your own design).

`mybot` uses **ordinary** semantics: green is the goal, and exit 100 means a defect in
your new bot or tests. A failed probe can earn the stated bonus as an honestly documented
weakness, but the runner will not call it a healthy inverted finding.

---

## Scoring

| Per challenge | Points |
|---|---|
| Creativity / originality | 0–10 |
| Technical proof (it ran; the screenshot backs the claim) | 0–5 |

Sum all three challenges. Highest total wins. **Tiebreaker:** the single most creative artifact across the whole hackathon.
