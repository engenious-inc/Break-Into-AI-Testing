# App testing — local stdio MCP

> **Day 7** · [session index](../../../days/07-testing-an-application.md)

[`mcp-deepwiki/`](../mcp-deepwiki/) hits a **remote URL**. This lesson hits a **local
server Promptfoo spawns** (`command` + `args` over stdio). You own the tools, so you can
assert on happy paths *and* on security refusals — without waiting on a third-party model.

To run the **same** eval from chat via Promptfoo’s IDE MCP server, see
[`mcp-promptfoo/`](../mcp-promptfoo/).

| | `mcp-deepwiki/` | this lesson (`mcp-local/`) |
|--|-----------------|---------------------------|
| Transport | remote `url:` | local `command:` / `args:` |
| Who runs the server | DeepWiki | Promptfoo (`node …/server.mjs`) |
| Best for | output-shape / rubric strategy | deterministic + **guard** asserts |
| Setup | none | one-time `npm install` in this folder |

## Setup (once)

```bash
npm install --prefix modules/03-app-testing/mcp-local
```

Needs Node ≥ 20 (same as the rest of the course). Installs `@modelcontextprotocol/sdk`
and `zod` into this lesson’s `node_modules/` (gitignored).

## Run (from repo root)

```bash
npx promptfoo@latest eval -c modules/03-app-testing/mcp-local/promptfooconfig.yaml
npx promptfoo@latest view
```

No `GROQ_API_KEY` — every assert here is deterministic.

## The provider block

```yaml
providers:
  - id: mcp
    config:
      enabled: true
      server:
        command: node
        args:
          - modules/03-app-testing/mcp-local/server.mjs
        name: workshop-local
```

Promptfoo starts `server.mjs`, speaks MCP over stdio for the eval, then tears it down.
Paths in `args` are relative to the **repo root** (always run evals from there).

## What the server exposes

| Tool | Behaviour |
|------|-----------|
| `echo` | returns `text` unchanged |
| `add` | returns `a + b` as text |
| `read_workspace_file` | reads a file under this lesson folder; rejects `..`, `~`, and absolute paths |

`fixture.txt` is the known-good read target. The path-traversal case expects the refusal
string `Path traversal not allowed` — a **pass** means the guard held.

## When install was skipped

```
Cannot find package '@modelcontextprotocol/sdk'
```

Run the `npm install --prefix …` command above and retry. That is a harness setup error,
not a failing assertion.

## Try it

1. Break the guard in `server.mjs` (comment out the `..` check), re-run, and watch the
   Security case go red — then put the check back.
2. Add a `multiply` tool and a fourth test with `regex` for the product.
3. Point `args` at a missing file and read the connection error so you can recognize a
   spawn failure vs an assertion failure in `promptfoo view`.
