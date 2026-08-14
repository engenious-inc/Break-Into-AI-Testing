# Day 8 TutorBot + Agenta Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Day 8's observability breakout trace a tutor bot whose spans carry
`tutor.subject` / `tutor.level`, and give students an Agenta path that actually works.

**Architecture:** A new `prompts/tutorbot.txt` becomes the subject of the existing
observability lesson. `provider.mjs` learns to parse the repo's JSON chat-prompt format and
to read promptfoo's `context.vars`, emitting the two domain attributes alongside the
standard OpenInference ones. Two Day 8 slides gain the working Agenta path. No new lesson,
no new session minutes.

**Tech Stack:** Node builtins only (`node:crypto`, global `fetch`), promptfoo via `npx`,
`python-pptx` for the deck.

## Global Constraints

- **No new dependencies.** No root `package.json`; promptfoo runs via `npx promptfoo@latest`.
- **Zero minutes added to Day 8.** It is already 159 minutes against 120. Both blocks
  touched keep their existing slots. **Deck stays at 29 slides.**
- **Never commit Agenta credentials.** They live in
  `"/Users/gregory.goldshteyn/Documents/Engenious/Day 8/AgentaAI/.env"` — untracked, and
  outside both repos. Source it into the shell; never write it into a tracked file.
- **`ends-with` is not a promptfoo assertion type.** Verified: the string does not appear
  in the installed package. Use `regex` with `'\?\s*$'`.
- **Agenta auth is `ApiKey`, not `Bearer`**, at `<host>/api/otlp/v1/traces`. `Bearer`
  returns `401`.
- **Subject and level ship raw; question and answer stay redacted.** They are parameters of
  the exercise, not user content. `redactForTelemetry()` still guards the payload.
- **No new weakness planted in TutorBot.** It is an observability subject, not an attack
  target. Day 8 covers red-teaming in its first 55 minutes.

**Paths:**
- Course repo: `/private/tmp/claude-502/-Users-gregory-goldshteyn-fox-dvp-meta/6b133947-600c-4627-aa52-e92a4a5223d1/scratchpad/Break-Into-AI-Testing`, branch `feat/agenta-otlp-backend`
- Deck sources: `~/Downloads/august-deck-sources` (separate git repo, branch `main`)
- Deck: `~/Downloads/August Day8-AdvancedRedTeaming-SDLC-Observability.pptx`, built by `day8/build.py`
- Scratch harnesses (never committed): `$SCRATCH` = `/private/tmp/claude-502/-Users-gregory-goldshteyn-fox-dvp-meta/6b133947-600c-4627-aa52-e92a4a5223d1/scratchpad`

**Already done and committed** (`5979570`): `provider.mjs` exports to Arato *and* Agenta;
`exportSpan(params)` encodes once and posts to every configured backend. Verified `200`.

---

### Task 1: TutorBot, and spans that carry its dimensions

**Files:**
- Create: `prompts/tutorbot.txt`
- Modify: `modules/02-advanced-eval/observability/provider.mjs`
- Modify: `modules/02-advanced-eval/observability/promptfooconfig.yaml`
- Modify: `modules/02-advanced-eval/observability/tests/basic.yaml`
- Delete: `modules/02-advanced-eval/observability/prompts/prompt.txt` (and the now-empty `prompts/` dir)
- Modify: `modules/02-advanced-eval/observability/README.md`
- Test: `$SCRATCH/provider-test.mjs` (scratch, not committed)

**Interfaces:**
- Produces: `prompts/tutorbot.txt`, a JSON array
  `[{role:"system",content},{role:"user",content:"{{query}}"}]` using `{{subject}}` and
  `{{level}}` in the system message. Task 2's guard detects exactly those two variables.
- Produces: `ObservedGroqProvider.callApi(prompt, context)` — `context.vars.subject` and
  `context.vars.level` become span attributes `tutor.subject` / `tutor.level`.

- [ ] **Step 1: Write the failing test**

Create `$SCRATCH/provider-test.mjs`. It stubs `fetch`, so it makes no network calls and
costs nothing:

```javascript
// Unit test for the observability provider. Stubs fetch — no network, no Groq spend.
const REPO = '/private/tmp/claude-502/-Users-gregory-goldshteyn-fox-dvp-meta/6b133947-600c-4627-aa52-e92a4a5223d1/scratchpad/Break-Into-AI-Testing';
process.env.GROQ_API_KEY = 'test-groq-key';
process.env.AGENTA_API_KEY = 'test-agenta-key';
delete process.env.ARATO_API_KEY;
delete process.env.OTEL_EXPORTER_OTLP_ENDPOINT;

const calls = [];
globalThis.fetch = async (url, opts) => {
  calls.push({ url: String(url), opts });
  if (String(url).includes('groq.com')) {
    return {
      ok: true,
      status: 200,
      json: async () => ({
        choices: [{ message: { content: 'A fraction is part of a whole. What is 1/2 + 1/2?' } }],
        usage: { prompt_tokens: 10, completion_tokens: 20, total_tokens: 30 },
      }),
    };
  }
  return { ok: true, status: 200, text: async () => '' };
};

const { default: Provider } = await import(
  `${REPO}/modules/02-advanced-eval/observability/provider.mjs`);

const chatPrompt = JSON.stringify([
  { role: 'system', content: 'You are a tutor. Subject area: Physics\nStudent level: University' },
  { role: 'user', content: 'What is quantum entanglement?' },
]);

const provider = new Provider({ id: 'test', config: {} });
const result = await provider.callApi(chatPrompt, {
  vars: { subject: 'Physics', level: 'University', query: 'What is quantum entanglement?' },
});

let fail = 0;
const check = (name, cond) => {
  console.log(`  ${cond ? 'OK  ' : 'FAIL'}  ${name}`);
  if (!cond) fail++;
};

const groq = calls.find((c) => c.url.includes('groq.com'));
const sent = JSON.parse(groq.opts.body);
check('chat array parsed into messages', sent.messages.length === 2);
check('system message preserved', sent.messages[0].role === 'system');
check('user message preserved', sent.messages[1].content === 'What is quantum entanglement?');
check('prompt not sent as raw JSON', !sent.messages[0].content.startsWith('['));

const otlp = calls.find((c) => c.url.includes('agenta'));
check('exported to agenta', Boolean(otlp));
check('agenta path correct', otlp.url.endsWith('/api/otlp/v1/traces'));
check('agenta auth is ApiKey', otlp.opts.headers.Authorization.startsWith('ApiKey '));

// Protobuf stores strings literally, so the bytes are greppable.
const body = Buffer.from(otlp.opts.body);
check('span carries tutor.subject', body.includes('tutor.subject'));
check('span carries tutor.level', body.includes('tutor.level'));
check('span carries the subject value', body.includes('Physics'));
check('span carries the level value', body.includes('University'));
check('question is NOT sent raw', !body.includes('quantum entanglement'));
check('output returned to promptfoo', result.output.includes('fraction'));

// A plain-text prompt must still work — students point this provider at their own prompts.
calls.length = 0;
await provider.callApi('What is HTTP?', { vars: {} });
const groq2 = JSON.parse(calls.find((c) => c.url.includes('groq.com')).opts.body);
check('plain string still becomes one user message', groq2.messages.length === 1
  && groq2.messages[0].content === 'What is HTTP?');

console.log(fail ? `\n${fail} failed` : '\nall passed');
process.exit(fail ? 1 : 0);
```

- [ ] **Step 2: Run it to verify it fails**

```bash
node "$SCRATCH/provider-test.mjs"; echo "exit=$?"
```

Expected: `FAIL  chat array parsed into messages` (the provider posts the JSON string as
one user message), plus the `tutor.*` and redaction checks failing. `exit=1`.

- [ ] **Step 3: Create the bot**

Create `prompts/tutorbot.txt`:

```json
[
  {
    "role": "system",
    "content": "You are a friendly and patient AI tutor helping students learn.\n\nPrinciples:\n1. Guide, do not just answer — lead the student toward the reasoning.\n2. Adapt your explanation to the student's level.\n3. Use concrete examples and analogies.\n4. Encourage critical thinking.\n5. Be patient and give positive reinforcement.\n\nSubject area: {{subject}}\nStudent level: {{level}}\n\nKeep your answer under six sentences, and always end with one thought-provoking question."
  },
  {
    "role": "user",
    "content": "{{query}}"
  }
]
```

The six-sentence cap is not styling. This bot exists to be traced, and unbounded answers
make token counts and latency vary for reasons that have nothing to do with the lesson.

- [ ] **Step 4: Teach the provider the chat format and the domain attributes**

In `modules/02-advanced-eval/observability/provider.mjs`, add this helper directly above
`export default class ObservedGroqProvider`:

```javascript
// Promptfoo hands `callApi` the rendered prompt as a string. Bots in prompts/ are JSON
// chat arrays; a bare question is also valid. Support both — students are invited to point
// this provider at their own prompt, and a JSON parse error there would read as a bug in
// the lesson rather than in their file.
function parseMessages(prompt) {
  try {
    const parsed = JSON.parse(prompt);
    if (Array.isArray(parsed) && parsed.length > 0 && parsed.every(
      (m) => m && typeof m.role === 'string' && typeof m.content === 'string')) {
      return parsed;
    }
  } catch {
    // Not JSON. A plain question is the other supported shape.
  }
  return [{ role: 'user', content: prompt }];
}
```

Change the method signature (currently `async callApi(prompt) {` at line 103):

```javascript
  async callApi(prompt, context) {
```

Directly after `const startMs = Date.now();`, add:

```javascript
    const messages = parseMessages(prompt);
    const question = [...messages].reverse().find((m) => m.role === 'user')?.content ?? prompt;
```

Replace the Groq request body line (currently `messages: [{ role: 'user', content: prompt }],`):

```javascript
        messages,
```

Replace the whole `attributes:` object in the `exportSpan` call with:

```javascript
      attributes: {
        'openinference.span.kind': 'LLM',
        'llm.system': 'groq',
        'llm.provider': 'groq',
        'llm.model_name': model,
        'llm.token_count.prompt': data.usage?.prompt_tokens ?? 0,
        'llm.token_count.completion': data.usage?.completion_tokens ?? 0,
        'llm.token_count.total': data.usage?.total_tokens ?? 0,
        ...Object.fromEntries(messages.flatMap((m, i) => [
          [`llm.input_messages.${i}.message.role`, m.role],
          [`llm.input_messages.${i}.message.content`, redactForTelemetry(m.content)],
        ])),
        'llm.output_messages.0.message.role': 'assistant',
        'llm.output_messages.0.message.content': redactForTelemetry(output),
        'input.value': redactForTelemetry(question),
        'output.value': redactForTelemetry(output),
        'prompt.sha256': promptHash,
        // The two that make a span worth slicing. Dimensions you filter by are safe to
        // ship raw — they are parameters of the exercise. The payload above is not, and
        // stays hashed unless LOG_RAW_PROMPTS=true.
        'tutor.subject': context?.vars?.subject ?? 'unknown',
        'tutor.level': context?.vars?.level ?? 'unknown',
      },
```

Also change `const promptHash = sha256(prompt);` to hash the question, so the "same prompt →
same hash" claim in the breakout stays true when only `subject` changes:

```javascript
    const promptHash = sha256(question);
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
node "$SCRATCH/provider-test.mjs"; echo "exit=$?"
```

Expected: all 13 checks `OK`, `exit=0`.

- [ ] **Step 6: Retarget the lesson's config and tests**

Replace the `prompts:` block in
`modules/02-advanced-eval/observability/promptfooconfig.yaml`:

```yaml
description: "Module 2 — Observability: real OTLP tracing to Arato and/or Agenta (single provider, zero npm dependencies)"

prompts:
  - file://../../../prompts/tutorbot.txt

providers:
  - id: file://provider.mjs
    config:
      model: llama-3.3-70b-versatile
      temperature: 0
      max_tokens: 400

tests:
  - file://tests/basic.yaml
```

Replace `modules/02-advanced-eval/observability/tests/basic.yaml` entirely. These are the
three cases from the previous cohort's `Student_Tutor_Demo_Testset_v5.json`, with their
real subject/level pairs:

```yaml
# The assertions are deliberately cheap. This lesson is about the span, not the answer —
# every second spent grading prose is a second not spent reading telemetry.
- description: "Beginner maths — fractions"
  vars:
    subject: "Mathematics"
    level: "Beginner"
    query: "Can you explain what fractions are and how to add them?"
  assert:
    - type: icontains
      value: "denominator"
    - type: regex
      value: '\?\s*$'

- description: "Intermediate biology — photosynthesis"
  vars:
    subject: "Biology"
    level: "Intermediate"
    query: "What is photosynthesis and why is it important?"
  assert:
    - type: icontains-any
      value: ["sunlight", "light", "glucose", "oxygen"]
    - type: regex
      value: '\?\s*$'

- description: "Advanced maths — the quadratic formula"
  vars:
    subject: "Mathematics"
    level: "Advanced"
    query: "How do I solve a quadratic equation using the quadratic formula?"
  assert:
    - type: icontains
      value: "discriminant"
    - type: regex
      value: '\?\s*$'
```

Delete the lesson's own prompt, now that it has a real subject:

```bash
git rm modules/02-advanced-eval/observability/prompts/prompt.txt
```

- [ ] **Step 7: Run the lesson for real, with no observability keys**

```bash
cd <course-repo>
env -u ARATO_API_KEY -u AGENTA_API_KEY GROQ_API_KEY=<key> \
  npx --yes promptfoo@latest eval -c modules/02-advanced-eval/observability/promptfooconfig.yaml -j 1
```

Expected: `3 passed`, and three `[otlp] skipped — …` lines. If the `discriminant` or
`denominator` assertion fails, the model answered without the term — widen that one
assertion to `icontains-any`, do not weaken the regex.

- [ ] **Step 8: Run it again with Agenta configured**

```bash
set -a; . "/Users/gregory.goldshteyn/Documents/Engenious/Day 8/AgentaAI/.env"; set +a
cd <course-repo>
env -u ARATO_API_KEY AGENTA_API_KEY="$AGENTA_API_KEY" AGENTA_HOST="$AGENTA_HOST" \
  GROQ_API_KEY=<key> \
  npx --yes promptfoo@latest eval -c modules/02-advanced-eval/observability/promptfooconfig.yaml -j 1
```

Expected: `3 passed`, and three `[agenta] OTLP 200 trace_id=…` lines. **Record the three
trace IDs** — Task 4 looks for them in the UI.

- [ ] **Step 9: Update the lesson README**

In `modules/02-advanced-eval/observability/README.md`, replace the "What's real here"
bullet list's first bullet and add one bullet, so the doc names its subject:

```markdown
- **Trace/span IDs, latency, token counts** — genuinely measured from a real
  Groq API call to **TutorBot** (`prompts/tutorbot.txt`), not simulated.
- **`tutor.subject` and `tutor.level`** — custom span attributes taken from each test
  case's vars. They are the reason this lesson traces a tutor rather than a bare question:
  a span you cannot slice is a latency number, and "is Physics slower than Algebra?" is the
  first thing anyone actually asks in production.
```

- [ ] **Step 10: Commit**

```bash
cd <course-repo>
git add prompts/tutorbot.txt modules/02-advanced-eval/observability/
git --no-pager diff --cached | rg -n 'gsk_[A-Za-z0-9]{20,}|ApiKey [A-Za-z0-9]{8,}' && exit 1
git commit -m "feat(day8): trace TutorBot, and give its spans dimensions worth slicing

The observability breakout ends by asking students what they would add to a span
to debug a slow request in production. The traced prompt was 'What is HTTP?', so
there was no honest answer — a span describing nothing in particular teaches
nothing in particular.

TutorBot is parameterised by subject and level, so provider.mjs can emit
tutor.subject and tutor.level and the question becomes answerable in the room:
is University Physics slower than Beginner Mathematics? That is the whole reason
anyone instruments anything.

The provider also learns the repo's JSON chat-prompt format, which it previously
would have posted to Groq as a literal JSON string. Plain-text prompts still
work, because students are invited to point this provider at their own.

Subject and level ship raw; the question and answer stay hashed. The dimensions
you filter by are usually safe, and the payload is what leaks — which is a
sharper way to make the privacy point than the lesson had before.

Test cases are the three from the previous cohort's Agenta testset, carrying
their original subject/level pairs."
```

---

### Task 2: Stop `chat` from serving a half-rendered bot

**Files:**
- Modify: `scripts/chat.mjs`
- Test: `$SCRATCH/chat-tutorbot-test.sh` (scratch, not committed)

**Interfaces:**
- Consumes: `prompts/tutorbot.txt` from Task 1 — specifically that its system message
  contains `{{subject}}` and `{{level}}`.

- [ ] **Step 1: Write the failing test**

Create `$SCRATCH/chat-tutorbot-test.sh`:

```bash
#!/usr/bin/env bash
# chat.mjs must refuse a prompt whose variables it cannot fill — and must not
# false-positive on the bots whose only variable is the user turn.
set -uo pipefail
cd "$1" || exit 1
fail=0
check() { if eval "$2"; then echo "  OK    $1"; else echo "  FAIL  $1"; fail=1; fi; }

out=$(./run.sh chat tutorbot </dev/null 2>&1); rc=$?
check "tutorbot exits non-zero"        '[ $rc -ne 0 ]'
check "names subject"                  'grep -qi "subject" <<<"$out"'
check "names level"                    'grep -qi "level" <<<"$out"'
check "points somewhere useful"        'grep -qi "observability\|suite" <<<"$out"'
check "does not start a session"       '! grep -qi "ready\. /reset" <<<"$out"'

out=$(printf 'where are the offices?\n' | ./run.sh chat onboardbot 2>&1); rc=$?
check "onboardbot still answers"       'grep -qiE "office|badge|location" <<<"$out"'
check "onboardbot exits zero"          '[ $rc -eq 0 ]'

exit $fail
```

- [ ] **Step 2: Run it to verify it fails**

```bash
chmod +x "$SCRATCH/chat-tutorbot-test.sh"
GROQ_API_KEY=<key> "$SCRATCH/chat-tutorbot-test.sh" <course-repo>; echo "exit=$?"
```

Expected: the five `tutorbot` checks FAIL — it starts a session and prints `{{subject}}`
literally to the model. The two `onboardbot` checks pass. `exit=1`.

- [ ] **Step 3: Add the guard**

In `scripts/chat.mjs`, directly after the `if (!system) { … }` block:

```javascript
// The chat loop only ever substitutes the user turn. A system prompt with other
// variables would reach the model with {{subject}} in it verbatim, and the bot would
// answer as if that were the subject — confusing in a way that looks like a bad model
// rather than a wrong tool. Say so instead.
const unfilled = [...new Set(
  [...system.matchAll(/\{\{\s*(\w+)\s*\}\}/g)].map((m) => m[1]),
)].filter((v) => v !== 'query');

if (unfilled.length > 0) {
  console.error(`${bot} needs variables chat cannot supply: ${unfilled.join(', ')}`);
  console.error('It is a suite subject, not a chat subject — its cases live in');
  console.error('modules/02-advanced-eval/observability/tests/basic.yaml');
  process.exit(2);
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
GROQ_API_KEY=<key> "$SCRATCH/chat-tutorbot-test.sh" <course-repo>; echo "exit=$?"
```

Expected: all seven checks `OK`, `exit=0`.

- [ ] **Step 5: Confirm no other bot regressed**

```bash
cd <course-repo>
for b in medibot financebot mybot reverse; do
  printf 'hello\n' | GROQ_API_KEY=<key> ./run.sh chat "$b" >/dev/null 2>&1
  echo "$b exit=$?"
done
```

Expected: `exit=0` for every one. Any non-zero means that bot's prompt has a variable
besides `{{query}}` and the guard is now blocking a bot that used to work — check that
prompt before proceeding.

- [ ] **Step 6: Commit**

```bash
cd <course-repo>
git add scripts/chat.mjs
git commit -m "fix(chat): refuse a bot whose variables chat cannot fill

./run.sh chat tutorbot would have sent the model a system prompt containing the
literal text {{subject}} and {{level}}, and the bot would have answered as though
that were the subject. That reads as a broken model rather than the wrong tool,
and someone will try it within five minutes of tutorbot landing.

The guard names the missing variables and points at the suite that supplies
them. It ignores {{query}}, which is the one variable the chat loop does fill."
```

---

### Task 3: The two Day 8 slides

**Files:**
- Modify: `~/Downloads/august-deck-sources/day8/build.py:451-470` (slide 23)
- Modify: `~/Downloads/august-deck-sources/day8/build.py:542-566` (slide 27)
- Create: `~/Downloads/august-deck-sources/day8/assert_day8.py`

**Interfaces:**
- Consumes: `AGENTA_API_KEY` as the env var name students set, and the
  `modules/02-advanced-eval/observability/promptfooconfig.yaml` path — both from Task 1.

- [ ] **Step 1: Write the failing assertion**

Create `~/Downloads/august-deck-sources/day8/assert_day8.py`:

```python
#!/usr/bin/env python3
"""Day 8 must teach an Agenta path that works, and must stay 29 slides."""
import os
import sys

from pptx import Presentation

DECK = os.path.expanduser(
    "~/Downloads/August Day8-AdvancedRedTeaming-SDLC-Observability.pptx")


def slide_text(slide):
    return " ".join(sh.text_frame.text for sh in slide.shapes if sh.has_text_frame)


def main():
    prs = Presentation(DECK)
    fails = []

    if len(prs.slides) != 29:
        fails.append(f"slide count: expected 29, got {len(prs.slides)}")

    s23 = slide_text(prs.slides[22])
    for need in ("ApiKey", "Bearer"):
        if need not in s23:
            fails.append(f"slide 23 does not name {need!r} — the claim is still abstract")

    s27 = slide_text(prs.slides[26])
    if "AGENTA_API_KEY" not in s27:
        fails.append("slide 27 does not show AGENTA_API_KEY")
    if "free" not in s27.lower():
        fails.append("slide 27 does not say the Agenta account is free")
    if "skipped" not in s27:
        fails.append("slide 27 lost the no-account fallback")

    for f in fails:
        print(f"  FAIL  {f}")
    if fails:
        return 1
    print("  OK  29 slides, slide 23 concrete, slide 27 has a working Agenta path")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd ~/Downloads/august-deck-sources && python3 day8/assert_day8.py; echo "exit=$?"
```

Expected: `slide 23 does not name 'ApiKey'`, `'Bearer'`, `slide 27 does not show
AGENTA_API_KEY`, and the "free" failure. `exit=1`.

- [ ] **Step 3: Make slide 23 concrete**

In `day8/build.py`, replace the `("The standard", …)` card (line ~465):

```python
        ("The standard", [
            ("OpenTelemetry", "Vendor-neutral, and this repo is the proof: the same "
                              "hand-encoded bytes are accepted by Arato and by Agenta. "
                              "Bearer at /v1/traces, ApiKey at /api/otlp/v1/traces. That "
                              "is the entire difference."),
        ]),
```

- [ ] **Step 4: Give slide 27 a path that works**

Replace the `code_panel` and `column_cards` calls in the slide 27 block:

```python
    y = T.code_panel(s, [
        ("code", "npx promptfoo@latest eval -c \\"),
        ("code", "  modules/02-advanced-eval/observability/promptfooconfig.yaml"),
        ("blank", ""),
        ("comment", "# Agenta cloud is free — sign up, then one line in .env:"),
        ("code", "AGENTA_API_KEY=..."),
        ("comment", "# no account? it prints the span and says it skipped."),
    ], y, pt=18)
    T.column_cards(s, [
        ("Everyone", [
            ("Read the span", "Latency, token counts, and the hashed prompt. Confirm the "
                              "hash is stable across runs of the same question."),
        ]),
        ("Then send it", [
            ("It is free", "Sign up for Agenta, set AGENTA_API_KEY, and watch three "
                           "traces land — one per subject. Open one and find "
                           "tutor.subject on it."),
        ]),
        ("Everyone, then", [
            ("Answer one question", "What would you have to add to this span to debug a "
                                    "slow request in production? Name the field."),
        ]),
    ], y)
    notes(s, "The answer to the third question is already on their screen: tutor.subject "
             "and tutor.level. Let them find it. The point lands harder when someone says "
             "'wait, can I filter by subject?' — yes, and that is why anyone instruments "
             "anything. If nobody gets there, ask which is slower, Beginner Mathematics "
             "or Advanced Mathematics, and let them discover they can answer it.")
```

Every column body must be a **list of `(label, body)` tuples** — `theme.py:295`'s
`column_cards` is documented as "a colored top rail + a list of label/body pairs", and a
bare string would break it. All three cards above follow that shape.

- [ ] **Step 5: Rebuild and assert**

```bash
cd ~/Downloads/august-deck-sources
python3 day8/build.py
python3 day8/assert_day8.py; echo "exit=$?"
```

Expected: the build prints its slide count, then `OK  29 slides, …`, `exit=0`.

- [ ] **Step 6: Run all three checkers**

```bash
cd ~/Downloads/august-deck-sources
D="$HOME/Downloads/August Day8-AdvancedRedTeaming-SDLC-Observability.pptx"
python3 shared/check_text_fit.py "$D" | tail -1
python3 shared/check_decks.py    "$D" | tail -1
python3 shared/check_overlap.py  "$D" | tail -1
```

Expected: all three report `0`. Day 8 is a theme-built deck, so **red here is real and
must be fixed** — unlike Days 5 and 6. Slide 27's code panel grew from five rows to six; if
the cards below it now collide, drop the `("blank", "")` row.

- [ ] **Step 7: Render both slides and read them**

```bash
cd ~/Downloads/august-deck-sources
mkdir -p day8/chk && find day8/chk -type f -delete
/Applications/LibreOffice.app/Contents/MacOS/soffice --headless --convert-to pdf \
  --outdir day8/chk "$HOME/Downloads/August Day8-AdvancedRedTeaming-SDLC-Observability.pptx" \
  >/dev/null 2>&1
cd day8/chk && pdftoppm -r 70 -png -f 23 -l 23 ./*.pdf s && pdftoppm -r 70 -png -f 27 -l 27 ./*.pdf b
```

**Read `s-23.png` and `b-27.png`.** The checkers cannot see a block that renders on top of
another element, and that is exactly the failure that got through on Day 6.

- [ ] **Step 8: Commit**

```bash
cd ~/Downloads/august-deck-sources
git add day8/build.py day8/assert_day8.py
git commit -m "Give Day 8 an Agenta path that works

Slide 23 already claimed the same span goes to Arato or Agenta and only the
endpoint changes. Nothing backed it — Arato was wired and Agenta was a name. It
now states the actual difference: Bearer at /v1/traces, ApiKey at
/api/otlp/v1/traces.

Slide 27's breakout said 'no Arato account? it skips'. Arato endpoints are
per-tenant, so most of the room skipped, and a 25-minute breakout degraded into
reading JSON in a terminal. Agenta cloud is free, so signing up is now the
default path and the fallback stays for anyone who does not.

The breakout's third question — name the field you would add to debug a slow
request — finally has an answer on screen: tutor.subject. The speaker notes say
to let them find it rather than tell them."
```

---

### Task 4: The session page, and proving it end to end

**Files:**
- Modify: `days/08-advanced-redteam-sdlc-observability.md`

**Interfaces:**
- Consumes: everything from Tasks 1–3.

- [ ] **Step 1: Verify the page currently has no Agenta path**

```bash
cd <course-repo> && rg -c 'AGENTA_API_KEY' days/08-advanced-redteam-sdlc-observability.md
```

Expected: `0` (rg exits 1). That is the gap.

- [ ] **Step 2: Update the page**

In `days/08-advanced-redteam-sdlc-observability.md`, replace the observability line in the
"Run this" block:

```bash
# observability: a real OTLP span per LLM call, one per subject
npx promptfoo@latest eval -c modules/02-advanced-eval/observability/promptfooconfig.yaml
```

and add this section directly after that code block:

```markdown
**Want to see them land somewhere?** [Agenta](https://agenta.ai) cloud is free and speaks
OTLP. Sign up, then one line in `.env`:

```env
AGENTA_API_KEY=...
```

Three traces appear, one per subject. Open one and look for `tutor.subject` — that
attribute is the difference between a span you can read and a span you can *query*.

Without a key the lesson still runs and tells you it skipped the POST. The span is real
either way; only the network call is optional.
```

- [ ] **Step 3: Confirm the day index still passes**

```bash
cd <course-repo> && ./scripts/check-day-index.sh | tail -3
```

Expected: `DAY INDEX CHECK PASSED.`

- [ ] **Step 4: Full end-to-end run**

```bash
set -a; . "/Users/gregory.goldshteyn/Documents/Engenious/Day 8/AgentaAI/.env"; set +a
cd <course-repo>
env -u ARATO_API_KEY AGENTA_API_KEY="$AGENTA_API_KEY" AGENTA_HOST="$AGENTA_HOST" \
  GROQ_API_KEY=<key> \
  npx --yes promptfoo@latest eval -c modules/02-advanced-eval/observability/promptfooconfig.yaml -j 1
```

Expected: `3 passed`, three `[agenta] OTLP 200 trace_id=…`. Note the trace IDs.

- [ ] **Step 5: Look at the Agenta UI — the one thing no test can do**

Open <https://eu.cloud.agenta.ai> → **Observability**. Find one of the trace IDs from
Step 4. Confirm:

1. The trace is there at all.
2. **`tutor.subject` appears on the span**, with the value `Mathematics` or `Biology`.
3. You can filter or group by it.

**This is the spec's named risk and it cannot be automated from here.** A `200` proves
Agenta accepted the bytes, not that it kept them as a queryable dimension — Agenta's read
API is not public at any path probed (`/api/tracing/traces` is a write endpoint; it answers
`{"detail":"Missing spans"}`). The lesson's own README makes this exact point.

**If `tutor.subject` is not visible or not filterable:** switch the two attribute names in
`provider.mjs` to `metadata.subject` / `metadata.level`, re-run Step 4, and look again. If
no custom dimension survives, revert slide 27's middle card to the generic "Set the key and
watch it land", drop the "find tutor.subject on it" sentence and the speaker-note answer,
and keep everything else. **The Agenta path does not depend on this risk resolving** — the
breakout still lands real traces in a real tool.

- [ ] **Step 6: Commit**

```bash
cd <course-repo>
git add days/08-advanced-redteam-sdlc-observability.md
git commit -m "docs(day8): document the Agenta path on the session page

The page told students to run the observability lesson and said nothing about
where the span could go. Agenta cloud is free and speaks OTLP, so it is one line
in .env — and the tutor.subject attribute is the difference between a span you
can read and one you can query."
```

- [ ] **Step 7: Push and open a PR**

```bash
cd <course-repo>
git push -u origin feat/agenta-otlp-backend
gh pr create --base main --head feat/agenta-otlp-backend \
  --title "feat(day8): TutorBot as the traced subject, and a working Agenta path"
```

The PR body should state what was verified live (three `200`s, three passing cases) and
what was confirmed by eye (the attribute in the UI), because those are different claims and
this lesson is specifically about not confusing them.

---

## Self-Review

**Spec coverage:**

| Spec requirement | Task |
|---|---|
| `prompts/tutorbot.txt` ported from slide 4, `{{subject}}`/`{{level}}` | Task 1, Step 3 |
| Config points at the shared bot; `observability/prompts/prompt.txt` deleted | Task 1, Step 6 |
| Three testset cases with real subject/level pairs | Task 1, Step 6 |
| `regex '\?\s*$'`, explicitly not `ends-with` | Task 1, Step 6 + Global Constraints |
| Provider parses chat format, falls back to plain string | Task 1, Step 4 (asserted in Step 1) |
| `tutor.subject` / `tutor.level` from `context.vars` | Task 1, Step 4 |
| Subject/level raw, question/answer redacted | Task 1, Step 4 (asserted: `question is NOT sent raw`) |
| `chat.mjs` names unfilled variables, exits non-zero | Task 2 |
| Slide 23 concrete; slide 27 working Agenta path; 29 slides | Task 3 |
| Session page documents the Agenta path | Task 4, Step 2 |
| Named risk: attributes accepted ≠ queryable, with fallback | Task 4, Step 5 |
| No TutorBot red-team suite; no new run.sh target | Not built — absent by construction |

**Placeholder scan:** none. Every code step carries the literal content; every command
states its expected output.

**Type consistency:** `parseMessages(prompt)` is defined in Task 1 Step 4 and exercised by
Task 1 Step 1's test. `callApi(prompt, context)` reads `context.vars.subject` / `.level`,
matching the `vars:` keys in Task 1 Step 6's test file and the `{{subject}}`/`{{level}}`
placeholders in Step 3's prompt. The attribute names `tutor.subject` / `tutor.level` are
identical in the provider (Task 1), the deck's speaker notes (Task 3), the session page
(Task 4) and the UI check (Task 4 Step 5). `AGENTA_API_KEY` is spelled the same in the
provider's `BACKENDS` table (already committed), the deck, the session page and every
command here.

**Resolved during review:** the first draft of Task 3 Step 4 passed a bare string as a
`column_cards` body and told the implementer to check the signature. `theme.py:295`
documents each column as "a colored top rail + a list of label/body pairs", so the bare
string would have thrown. Fixed in place; the plan now carries only the correct shape.
