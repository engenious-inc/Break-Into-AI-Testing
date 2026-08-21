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

Or from the repo root:

```bash
./run.sh mcp-local
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
| `write_note` | writes under `notes/` with **no allow-list** — Day 8 finding |
| `read_secret` | returns `secret.txt` with **no auth** — Day 8 finding |
| `http_get` | does not fetch; returns `would_fetch: <url>` — Day 8 finding |
| `search_notes` | returns a poisoned operator note — Day 8 finding |

`fixture.txt` is the known-good read target. The path-traversal case expects the refusal
string `Path traversal not allowed` — a **pass** means the guard held.

Day 7 stops at the first four tools (`./run.sh mcp-local`). Day 8 calls the rest:
`./run.sh mcp-abuse` (JSON, no Groq key), `./run.sh mcp-agent` (English, Groq picks the
tool), `./run.sh mcp-injection` (tool output is the channel). Do not "fix" those suites
by deleting the tools; the inventory is the lesson. Homework is an allow-list on
`write_note`.

**CI:** every PR runs `mcp-local` (ordinary) and `mcp-abuse` (inverted — exit 100 is
green) via [`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml). Same suites
as `./run.sh`; no Groq key on that path.

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
