# Structured outputs — JSON schema + transform

> **Day 4** · [session index](../../../days/04-metrics-and-model-graded.md)

Models love to be helpful. APIs need a **contract**. This lesson is the gap between
those two: enforce a JSON Schema, then **normalize** chatty wrappers so the same
contract still holds.

```bash
npx promptfoo@latest eval -c modules/02-advanced-eval/structured-outputs/promptfooconfig.yaml
npx promptfoo@latest view
```

Single Groq provider. No paid key. Schema lives in `schema/capital.json` so the
assert stays readable.

## Three cases, one product lesson

| # | Instruction style | Assert strategy | Metric |
|---|-------------------|-----------------|--------|
| 1 | “JSON only, no fences” | `is-json` + schema + `javascript` payload check | Schema / Payload |
| 2 | “Explain, then \`\`\`json fence” | `contains-json` + same schema | Schema |
| 3 | Same chatty prompt | `options.transform` unwraps fence → **`is-json`** + schema | Schema / Payload |

**Takeaway:** prefer `is-json` when the *entire* response must be the payload (API
handler). Use `contains-json` when prose is allowed. Use `transform` when you want
the strict contract but the model still wraps — normalize once, assert forever.

## The schema

```json
{
  "type": "object",
  "required": ["city", "country", "confidence"],
  "additionalProperties": false,
  "properties": {
    "city": { "type": "string", "minLength": 1 },
    "country": { "type": "string", "minLength": 1 },
    "confidence": { "type": "number", "minimum": 0, "maximum": 1 }
  }
}
```

Wired as `value: file://schema/capital.json` on the JSON asserts.

## The transform

```js
let s = String(output).trim();
const fenced = s.match(/```(?:json)?\s*([\s\S]*?)```/i);
if (fenced) return fenced[1].trim();
// fallback: first {...} object in the string
```

Runs **before** assertions (`options.transform`). Same idea as stripping HTML before
you parse — don’t soften the schema; clean the wire format.

## Try it

1. Comment out the transform on case 3 and re-run — predict whether `is-json` fails.
2. Add `"timezone": "Europe/Paris"` to a model answer (or loosen the prompt) and watch
   `additionalProperties: false` reject it.
3. Point case 1 at a different capital question; keep the schema, change only the
   `javascript` city check.
4. Swap `is-json` for `equals` on case 1 and feel how brittle exact string match is
   next to a schema.
