# App testing — remote MCP (DeepWiki)

PayFlow points Promptfoo at an HTTP app. This lesson points it at an **MCP server** —
DeepWiki’s public endpoint — and treats the *tools* as the system under test.

No local process to start. Prompts are **JSON tool calls**, not chat messages. The three
cases are deliberately different assertion strategies for three different output shapes.
For the **local `command:`** counterpart (happy path + path-traversal guard), see
[`mcp-local/`](../mcp-local/). To drive evals from Cursor via **Promptfoo’s own MCP
server**, see [`mcp-promptfoo/`](../mcp-promptfoo/).

```bash
npx promptfoo@latest eval -c modules/03-app-testing/mcp-deepwiki/promptfooconfig.yaml
npx promptfoo@latest view
```

`GROQ_API_KEY` is required only for the `llm-rubric` case. The MCP calls themselves need
no API key.

## The provider block

```yaml
providers:
  - id: mcp
    config:
      enabled: true
      timeout: 120000
      server:
        url: https://mcp.deepwiki.com/mcp
        name: deepwiki
```

`id: mcp` means Promptfoo talks MCP, not a chat model. Each test’s `vars.prompt` must be
a tool call:

```json
{"tool": "read_wiki_structure", "args": {"repoName": "promptfoo/promptfoo"}}
```

If you paste a normal English sentence here, the provider will not “chat with DeepWiki” —
it will fail to invoke a tool.

## Three shapes, three assertion styles

| # | Tool | Output shape | Assertion | Metric |
|---|------|--------------|-----------|--------|
| 1 | `read_wiki_structure` (known repo) | Stable structured text/JSON | `is-json` + `contains` | Deterministic |
| 2 | `ask_question` | Free-form, AI-written prose | `llm-rubric` + length floor | ModelGraded |
| 3 | `read_wiki_structure` (fake repo) | Error string | `icontains: error` | ErrorHandling |

That table *is* the lesson. Same provider, same remote server — the right assert type
depends on how stable the response is.

### Case 1 — assert structure when you can

Wiki outlines for a fixed repo change rarely. Prefer cheap deterministic checks. You are
not grading English; you are checking that the tool returned usable structure that
mentions the repo.

### Case 2 — grade meaning when wording drifts

`ask_question` answers vary run to run. A `contains: "assertions"` check is brittle. The
rubric asks whether the answer conveys the *idea*; the `javascript` length check is the
deterministic companion so an empty/truncated response fails even if the grader is
generous. Same pairing rule as Module 1 / Module 0 model-graded lessons.

### Case 3 — assert the error path exists

A real tool surface must fail cleanly on bad input. This case expects the word “error”
somewhere in the response. DeepWiki returns `Error fetching wiki…` with a capital **E** —
so the assert is `icontains`, not `contains`. Flip it to `contains: error` and watch a
correct failure report as a red test. That is an underspecified assertion, not a broken
server.

## What to look for in `promptfoo view`

1. **Deterministic** column green, latency from the remote MCP (not Groq).
2. **ModelGraded** shows a grading call (Groq tokens) *and* the DeepWiki answer text.
3. **ErrorHandling** still “passes” when the tool errors — because the *assertion* is that
   an error was returned. Pass = the failure mode you wanted.

## Common failures

| Symptom | Likely cause |
|---------|----------------|
| `401` / Invalid API Key on case 2 only | `GROQ_API_KEY` missing (login shell / `.env` at repo root) |
| Tool / connection errors on all cases | Network blocked to `mcp.deepwiki.com`, or timeout too low |
| Case 3 fails with output containing `Error…` | You switched back to case-sensitive `contains: error` |
| Weird parse errors | Prompt is not valid JSON tool-call shape |

Set `debug: true` under the MCP `config:` block when you need the connection handshake
logged; leave it off for normal cohort runs (this config ships with it off).

## Try it

1. Point case 1 at another public repo DeepWiki knows (e.g. change `repoName`) and adjust
   the `contains` value so the assert still matches the new outline.
2. Replace the case-2 rubric with a wrong claim (e.g. “assertions are only for red-team”)
   and confirm the suite goes red for the right reason.
3. Change case 3 to `contains: error` (lowercase, case-sensitive). Predict the result,
   then run it.
4. Add a fourth case for a second DeepWiki tool if the server lists one — pick
   deterministic vs rubric based on output stability, not habit.
