# Promptfoo’s own MCP server

This is **not** `providers: [{ id: mcp }]`.

| Lesson | Role of MCP |
|--------|-------------|
| [`mcp-deepwiki/`](../mcp-deepwiki/), [`mcp-local/`](../mcp-local/) | MCP server = **system under test** (Promptfoo’s `mcp` provider calls tools) |
| **This lesson** | Promptfoo **is** the MCP server — your IDE agent gets eval tools |

Official docs: [Promptfoo MCP Server](https://www.promptfoo.dev/docs/integrations/mcp-server/).

## Setup (once) — portable for everyone

The repo ships a **project** MCP config (no absolute paths, no personal nvm):

[`.cursor/mcp.json`](../../../.cursor/mcp.json)

```json
{
  "mcpServers": {
    "promptfoo": {
      "command": "npx",
      "args": ["-y", "promptfoo@latest", "mcp", "--transport", "stdio"]
    }
  }
}
```

### Steps

1. **Open the repo root** in Cursor (`Break-Into-AI-Testing`), not a subfolder.
2. Ensure `node` / `npx` work in a terminal **inside Cursor** (`node -v`, `npx -v`).  
   If those fail, fix PATH for GUI apps (nvm/asdf users: open Cursor from a login shell, or install Node so `/usr/local/bin/npx` exists).
3. **Fully quit Cursor** (Cmd+Q / quit), reopen this project.
4. **Customize → MCPs** → enable **`promptfoo`** if it appears disabled.
5. In chat, open **Available Tools** and confirm tools like `list_evaluations` and
   `validate_promptfoo_config`.

First connect may take a few seconds while `npx -y` fetches `promptfoo@latest`. No
repo `npm install` is required for this lesson.

### If `promptfoo` still does not list

Some Cursor setups only show **user** MCPs. Add the **same** block via the UI
(do **not** hard-code a machine-specific `npx` path in the shared repo):

1. **Customize → MCPs → New MCP Server**
2. Type: stdio  
   Name: `promptfoo`  
   Command: `npx`  
   Args: `-y` `promptfoo@latest` `mcp` `--transport` `stdio`
3. Save → toggle on → check **Output → MCP Logs** if it errors.

Optional local-only override: put that same JSON under `~/.cursor/mcp.json`. Keep
personal PATH hacks out of git.

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
| No `promptfoo` in **Customize → MCPs** | Workspace = repo root; quit/reopen Cursor; or add via UI (same `npx -y …` args). |
| `npx` / `spawn ENOENT` in MCP Logs | Node not on PATH for GUI Cursor — fix Node install or launch Cursor from a terminal. |
| `promptfoo` listed but red / no tools | **Output → MCP Logs**; retry after network allows `npx` to download the package. |
| Tools missing in chat | Enable the server under **Customize → MCPs**; check **Available Tools**. |
| `Config error` | Pass a real config path under this repo to `validate_promptfoo_config`. |
| `Eval not found` | `list_evaluations` first — IDs come from prior runs in this project. |
| Provider / 401 on a Groq suite | `GROQ_API_KEY` must be available to processes Cursor spawns. |

## Try it next

1. Validate `mcp-deepwiki/promptfooconfig.yaml`, then run it via MCP (needs network + Groq
   for the rubric case).
2. Ask the agent to compare two recent eval IDs with `get_evaluation_details`.
3. On Day 5, try `redteam_generate` / `redteam_run` against MediBot — same MCP server,
   different tools.
