# Promptfoo’s own MCP server

This is **not** `providers: [{ id: mcp }]`.

| Lesson | Role of MCP |
|--------|-------------|
| [`mcp-deepwiki/`](../mcp-deepwiki/), [`mcp-local/`](../mcp-local/) | MCP server = **system under test** (Promptfoo’s `mcp` provider calls tools) |
| **This lesson** | Promptfoo **is** the MCP server — your IDE agent gets eval tools |

Official docs: [Promptfoo MCP Server](https://www.promptfoo.dev/docs/integrations/mcp-server/).

## Setup (once)

This repo ships [`.cursor/mcp.json`](../../../.cursor/mcp.json) at the root:

```json
{
  "mcpServers": {
    "promptfoo": {
      "command": "npx",
      "args": ["promptfoo@latest", "mcp", "--transport", "stdio"]
    }
  }
}
```

1. Open this project in Cursor (or add the same block to Claude Desktop).
2. **Restart** the IDE / reload MCP servers so `promptfoo` appears in the tool list.
3. Confirm you can see tools like `list_evaluations` and `validate_promptfoo_config`.

No `npm install` for this lesson. First tool call may take a few seconds while `npx`
fetches `promptfoo@latest`.

## What you can ask the agent

Use natural language; the agent should call Promptfoo tools, not invent results.

| Try saying… | Tool(s) you should see used |
|-------------|----------------------------|
| “Validate `modules/03-app-testing/mcp-local/promptfooconfig.yaml`” | `validate_promptfoo_config` |
| “List my recent evaluations” | `list_evaluations` |
| “Show details for the latest eval” | `get_evaluation_details` |
| “Run the mcp-local eval” | `run_evaluation` (config path + optional filters) |
| “Is Groq reachable?” | `test_provider` |

Other tools exist (`generate_test_cases`, `redteam_run`, `share_evaluation`, …) — useful
later; Day 7 only needs validate → list → run → inspect.

## Cohort exercise (10 minutes)

Do this **after** `mcp-local/` is installed (`npm install --prefix modules/03-app-testing/mcp-local`).

1. Ask the agent to **validate** `modules/03-app-testing/mcp-local/promptfooconfig.yaml`.
2. Ask it to **run** that config (or: run only the Security metric / first N cases if the
   tool supports filters).
3. Ask it to **list** evaluations and **open details** on the run you just created.
4. Compare: same suite via CLI vs via MCP —

```bash
npx promptfoo@latest eval -c modules/03-app-testing/mcp-local/promptfooconfig.yaml
```

The assertions and pass/fail should match. The lesson is the *control plane* (agent +
MCP tools), not a new assertion type.

## How this differs from the other MCP lessons

```text
mcp-local / mcp-deepwiki          Promptfoo MCP (this)
─────────────────────────         ────────────────────
Promptfoo ──calls──▶ MCP tools    IDE agent ──calls──▶ Promptfoo tools
              ▲                              ▲
         SUT is the server              SUT is still your
                                        eval configs / apps
```

If you only do one MCP track on Day 7: run `mcp-local` from the terminal, then drive the
**same** config through Promptfoo’s MCP from chat. That contrast sticks.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| No `promptfoo` tools in the IDE | Restart Cursor; check `.cursor/mcp.json` is at repo root |
| `Config error` | Point `validate_promptfoo_config` at a real `-c` path under this repo |
| `Eval not found` | `list_evaluations` first — IDs come from prior runs in this project |
| Provider / 401 on a Groq suite | `GROQ_API_KEY` in the environment the MCP server inherits |
| SDK missing (slim installs) | Rare with `npx promptfoo@latest`; see upstream docs if it appears |

## Try it next

1. Validate `mcp-deepwiki/promptfooconfig.yaml`, then run it via MCP (needs network + Groq
   for the rubric case).
2. Ask the agent to compare two recent eval IDs with `get_evaluation_details`.
3. On Day 5, try `redteam_generate` / `redteam_run` against MediBot — same MCP server,
   different tools.
