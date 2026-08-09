# Metrics & Model-Graded Assertion Exercises

The **Day 4** exercises. Everything here runs on the Groq free tier.

The lessons these build on live in
[`modules/02-advanced-eval/`](../modules/02-advanced-eval/):
`weights-and-metrics/`, `assert-sets-and-budgets/`, `exact-vs-fuzzy/`, `structured-outputs/`,
`csv-driven-data/`, `fscore-classification/`, `temperature-and-personas/`, and `debugger/`.

> **Run everything from the repo root** — `cd`-ing into a lesson directory breaks `.env`
> discovery and you get a bare `401`.

---

## Act 1 — Model-graded assertions

Deterministic assertions (`contains`, `regex`, `equals`, `javascript`) run logical tests
on the text. Model-graded assertions ask a second model to judge the output against
criteria you write in prose. You need both, and for opposite reasons.

### Exercise 1 — Write a rubric that holds

Take any case from your Day 3 suite and add an `llm-rubric`. Then make it worse, and see
what happens:

```yaml
- type: llm-rubric
  value: "The response is good."          # vague — the judge has to guess
```

versus

```yaml
- type: llm-rubric
  value: "The reply acknowledges the failed payment and offers at least one concrete
          next step (retry, check card details, or contact support)."
```

Run each five times. The vague rubric will not give you the same verdict every time. Name
the **observable behaviour**, not the vibe.

### Exercise 2 — Pair it with a deterministic partner

Every model-graded assertion in this course gets a deterministic sibling. Find a case
where they disagree — that disagreement is the finding, and it is what Day 5 is built on.

---

## Act 2 — Weights and thresholds

### Exercise 3 — Prove the threshold rule yourself

Do not take this on faith; it is two lines and one Groq call:

```yaml
- threshold: 0.5
  assert:
    - { type: javascript, value: "true",  weight: 1 }
    - { type: javascript, value: "false", weight: 1 }
```

Score is exactly `0.5`. It **passes** — so the rule is **`>=`**, not `>`.

Now the classic worked example: 2 critical assertions at `weight: 3` that pass, 3 normal
ones at `weight: 1` that fail.

| Assertions | Score | Threshold | Result |
|---|---|---|---|
| 2×w3 pass, 3×w1 fail | 0.6667 | 0.67 | **FAIL** |
| same | 0.6667 | 0.66 | PASS |

`6/9` is 66.67%, not 67%. The rule is `>=` **and** two-thirds still misses a `0.67` bar.
Pick thresholds from the weights you actually have. Full write-up:
[`modules/02-advanced-eval/weights-and-metrics/README.md`](../modules/02-advanced-eval/weights-and-metrics/README.md).

### Exercise 4 — Name your metrics

Tag your assertions with `metric:` names a stakeholder would recognise — Accuracy, Tone,
Safety. Three or four you can defend beats twenty you cannot. Then run `view` and read
the report as if you were presenting it.

---

## Act 3 — Precision, recall, F1

Pass rate hides *which kind* of mistake you are making.

- **Precision** = TP/(TP+FP) — of the ones you called safe, how many were.
- **Recall** = TP/(TP+FN) — of the truly safe ones, how many you caught.
- **F1** = 2TP/(2TP+FP+FN) — the harmonic mean, when you need a single number.

### Exercise 5 — Break the classifier

```bash
npx promptfoo@latest eval -c modules/02-advanced-eval/fscore-classification/promptfooconfig.yaml -o results.json
node modules/02-advanced-eval/fscore-classification/scripts/compute-fscore.js results.json
```

Out of the box this scores **6/6, TP=2, FP=0, FN=0, F1 = 1.00**. That is not a victory —
with no false positives or negatives, precision and recall carry no information at all.
You have learned nothing about where the classifier's boundary sits.

**Your task:** add rows to `tests/labeled.csv` until F1 drops below 1.00. Aim for one
false positive and one false negative. Good candidates sit near the boundary — a hedged
refusal, a partial dose, a citation that is *almost* real. The first row that produces an
error is worth more than the six that pass.

> **Why a companion script and not `derivedMetrics`?** Promptfoo's documented
> `weight: 0` + `derivedMetrics` pattern does not compute correctly — `namedScores` is
> already a weighted average, so a `weight: 0` assertion always contributes 0. Reproduced
> against the current release; see the lesson README.

---

## Act 4 — Scale and sensitivity

### Exercise 6 — Move your cases into a CSV

`tests: file://tests/cases.csv`, with `__expected` holding the assertion, `__expected1/2/3`
for several, and `__metadata:key` for filterable tags. Anyone who can edit a spreadsheet
can now contribute a test case.

**Watch for questions with more than one right answer.** This lesson shipped
`"Name a primary color."` asserting `icontains: red` and it failed the first time the
model answered *"Blue."* — which is also correct. `icontains-any: red, blue, yellow` is
the fix, and a more useful assertion type to know.

### Exercise 7 — Pin your temperature

[`temperature-and-personas/`](../modules/02-advanced-eval/temperature-and-personas/) runs
one model at 0.7 and 1.0 across two personas. Does any rubric verdict flip? If a passing
case fails at the higher temperature, your prompt is relying on luck. Test at the
temperature you ship, and one notch above.

---

## Act 5 — Debugging

### Exercise 8 — The debugger track

[`modules/02-advanced-eval/debugger/`](../modules/02-advanced-eval/debugger/) ships three
configs broken on purpose: `1_basic` (assertion type mismatch), `2_moderate` (missing
provider prefix), `3_advance` (a `file://` path bug).

Workflow: read the error → check YAML indentation → check `file://` paths → check provider
IDs → check assertion types → re-run.

**Write down the error message for each before you fix it.** You are building a lookup
table you will use for years. Each stage has a `SOLUTION.md` — try first, peek after.

`scripts/smoke-check.sh` verifies all three are still correctly broken, so if a stage runs
clean, the *exercise* is broken.

---

## Going further

- **Observability (Day 8, not today)** —
  [`modules/02-advanced-eval/observability/`](../modules/02-advanced-eval/observability/):
  real Arato.ai REST logging plus OTel-shaped tracing via a zero-dependency custom
  provider. It sits in Module 2 because it is shaped like one, but it is taught on Day 8
  with Arato.ai and Agenta.ai — everything above is eval-time quality, this is what a
  *deployed* system reports about itself.
- **Quality challenges** — [`docs/05-quality-challenges.md`](05-quality-challenges.md):
  bias, consistency, context, values, compliance.
- **Day 5** — [`docs/02-redteam-exercises.md`](02-redteam-exercises.md). Everything you
  weighted and measured today becomes an attack surface, and the scoring inverts: a
  *failing* assertion means the attack landed.
- **Who grades the grader** —
  [`modules/01-red-team/04-grading-the-grader/`](../modules/01-red-team/04-grading-the-grader/):
  a real case in this repo where an `llm-rubric` passed a total system-prompt leak.
