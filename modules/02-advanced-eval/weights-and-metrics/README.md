# Weights, Thresholds & Named Metrics

> **Day 4** · [session index](../../../days/04-metrics-and-model-graded.md)

```bash
npx promptfoo@latest eval -c modules/02-advanced-eval/weights-and-metrics/promptfooconfig.yaml
npx promptfoo@latest view
```

Three ideas in one config:

- **`weight:`** — how much an assertion counts. Default is `1`. A `weight: 2` assertion
  contributes twice as much to the test's score.
- **`metric:`** — a name several assertions can share, so the report aggregates by
  something a stakeholder recognises (Tone, Accuracy) instead of by test index.
- **`threshold:`** — the bar the test's overall score has to clear.

The score is `Σ(weight of passing assertions) / Σ(all weights)`. Model-graded assertions
can score fractionally (0.5), so it is not strictly pass/fail.

## The threshold is `>=`, not `>`

A score exactly equal to the threshold **passes**. Verified against the current release
with a config that removes the model from the question entirely:

```yaml
- threshold: 0.5
  assert:
    - { type: javascript, value: "true",  weight: 1 }   # passes
    - { type: javascript, value: "false", weight: 1 }   # fails
# score = 0.5000, threshold = 0.5  ->  PASS
```

## …and two-thirds does not clear `0.67`

The classic worked example — 2 critical assertions at `weight: 3` passing, 3 normal ones
at `weight: 1` failing — scores `6/9 = 0.6667`. Against `threshold: 0.67` that **fails**:

| Assertions | Score | Threshold | Result |
|---|---|---|---|
| 2×w3 pass, 3×w1 fail | 0.6667 | 0.67 | **FAIL** |
| same | 0.6667 | 0.66 | PASS |

`6/9` is 66.67%, not 67%. The rule is `>=`, and the arithmetic still misses. Pick
thresholds from the weights you actually have rather than from a percentage that reads
nicely — or set the threshold to the exact ratio (`0.6666`) if that is what you mean.

Both claims are re-checked by `./scripts/outcome-check.sh day4`, since either could
change under promptfoo and both are taught as fact.

## Try it

1. Drop the `threshold` to `0.5` and watch a test pass that previously failed.
2. Move `weight: 2` from the rubric to the `icontains` and see the score change without
   any assertion changing its verdict.
3. Give the two `Tone` assertions different metric names and compare the report.
