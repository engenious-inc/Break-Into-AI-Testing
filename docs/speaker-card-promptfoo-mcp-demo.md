# Promptfoo MCP demo — Day 7 (students)

Two MCP stories in one room. Keep them separate on the whiteboard.

| Role | What it is | Lesson folder |
|------|------------|---------------|
| **SUT** | Local tools Promptfoo *calls* | `mcp-local/` |
| **Control plane** | Promptfoo *is* the MCP server your IDE agent calls | `mcp-promptfoo/` + `.cursor/mcp.json` |

No Groq key for this demo. Every assert is deterministic.

---

## Pre-flight (instructor, once)

```bash
# From repo root
npm install --prefix modules/03-app-testing/mcp-local
./run.sh mcp-local
```

Expect exit **0**, **4/4**. If that fails, stop — fix SUT before showing chat.

Confirm Cursor has **promptfoo** under Customize → MCPs (repo ships `.cursor/mcp.json`).

---

## Live demo (8–10 min)

### Act 1 — CLI proves the app (SUT)

```bash
./run.sh mcp-local
# or: npx promptfoo@latest eval -c modules/03-app-testing/mcp-local/promptfooconfig.yaml
```

| Case | Tool call | Pass means |
|------|-----------|------------|
| echo | `hello cohort` | happy path |
| add | `2 + 40` → `42` | deterministic math |
| read fixture | `fixture.txt` | file inside lesson folder |
| path traversal | `../../../etc/passwd` | guard refused |

**Say:** Same four cases later from chat. Assertions don’t change — only *who* drives the eval.

### Act 2 — Chat drives the same suite (control plane)

In Cursor chat (repo root open), ask the agent these **exact** lines, one at a time:

1. **Validate**  
   `Validate modules/03-app-testing/mcp-local/promptfooconfig.yaml`  
   → tool: `validate_promptfoo_config`  
   → expect: valid, 1×1×4 = 4 evals

2. **Run**  
   `Run the mcp-local eval`  
   → tool: `run_evaluation`  
   → expect: 4 passed (same as CLI)

3. **List**  
   `List my recent evaluations`  
   → tool: `list_evaluations`  
   → expect: newest row is the mcp-local description

4. **Inspect**  
   `Show details for the latest mcp-local eval`  
   → tool: `get_evaluation_details`  
   → expect: echo / add / fixture / path-traversal all PASS

**Say:** CLI and MCP are two remotes for one TV. The show (asserts) is identical.

### Act 3 — One contrast line (optional, 30 sec)

```text
mcp-local:     Promptfoo ──calls──▶ workshop tools
mcp-promptfoo: IDE agent ──calls──▶ Promptfoo tools
```

---

## Student checklist (copy into chat)

```
[ ] npm install --prefix modules/03-app-testing/mcp-local
[ ] ./run.sh mcp-local   → 4/4
[ ] promptfoo MCP enabled in Cursor
[ ] Validate mcp-local config (via agent)
[ ] Run mcp-local (via agent)
[ ] List + open details on that eval ID
```

Pass criteria: CLI pass rate and MCP pass rate both **100%** on the same four cases.

---

## If something breaks

| Symptom | Fix |
|---------|-----|
| `Cannot find package '@modelcontextprotocol/sdk'` | `npm install --prefix modules/03-app-testing/mcp-local` |
| No `promptfoo` in Customize → MCPs | Open **repo root**; quit/reopen Cursor; or add UI entry: `npx` + `-y promptfoo@latest mcp --transport stdio` |
| Validate can’t find config | Pass a path under this repo (prefer absolute if relative fails) |
| Chat invents results | Require Available Tools → Promptfoo tools must appear in the turn |

Full lesson write-up: [`modules/03-app-testing/mcp-promptfoo/README.md`](../modules/03-app-testing/mcp-promptfoo/README.md)
