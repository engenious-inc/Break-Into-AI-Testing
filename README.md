# Breaking GPT & Claude — Promptfoo Red-Team Workshop

Hands-on AI bug-bounty workshop. You'll red-team two chatbots — **MediBot** (healthcare triage) and **FinanceBot** (retail brokerage) — using [Promptfoo](https://www.promptfoo.dev). Both are built the way most production AI assistants are built: an open-weight LLM + a guardrail system prompt, served via Groq's free tier. Same attack surface, different domain rules.

The default config is **free-tier-safe**: a curated subset (4 cases) run against three Groq models — a small Llama (`llama-3.1-8b-instant`), a large Llama (`llama-3.3-70b-versatile`), and an OpenAI open-weight (`gpt-oss-20b`). This stays comfortably under Groq's free-tier rate limit (~30 req/min). The full six-model lineup lives in `promptfooconfig.full.yaml` — run it only with paid keys or a tolerance for throttling. Optionally add the paid `openai:gpt-4o-mini` or `anthropic:claude-haiku-4-5` for cross-vendor comparison.

<p align="center">
  <img src="docs/qr.png" alt="Scan to clone" width="220" />
</p>

## Quickstart (≈ 3 minutes)

You need: a terminal, internet, and a free Groq API key.

> **Step 0 — get your free Groq API key first:** go to **<https://console.groq.com/keys>**, sign in, and click **Create API Key**. It's free, no credit card required. Copy the `gsk_…` key — `setup.sh` will prompt you to paste it. Keep it handy before running the steps below.

### macOS / Linux
```bash
git clone https://github.com/engenious-inc/breaking-gpt-claude-workshop.git
cd breaking-gpt-claude-workshop
./setup.sh
```

### Windows (PowerShell)
```powershell
git clone https://github.com/engenious-inc/breaking-gpt-claude-workshop.git
cd breaking-gpt-claude-workshop
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

> If `.\setup.ps1` fails with *"running scripts is disabled on this system"*, use the `-ExecutionPolicy Bypass` invocation shown above (or run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` first).

The script will: check Node ≥ 20, install Promptfoo, prompt for your Groq key, write `.env`, and run a smoke test.

## Run the workshop eval

```bash
npx promptfoo@latest eval                                       # MediBot (default — free-tier-safe)
npx promptfoo@latest eval -c promptfooconfig.finance.yaml       # FinanceBot (default — free-tier-safe)
npx promptfoo@latest view                                       # opens the web UI

# Full 6-model lineup — paid keys recommended; will throttle on Groq's free tier:
npx promptfoo@latest eval -c promptfooconfig.full.yaml          # MediBot, all 6 models
npx promptfoo@latest eval -c promptfooconfig.full.finance.yaml  # FinanceBot, all 6 models
```

## What you'll do

1. **Prompt-injection / jailbreaks** — try to bypass system-prompt guardrails (`tests/jailbreaks.yaml`)
2. **Hallucination traps** — confirm the model refuses to invent facts (`tests/hallucinations.yaml`)
3. **Cost & context** — assert latency and response-length thresholds (`tests/cost-context.yaml`)
4. **Multi-model comparison** — the default config runs three Groq-hosted models (free-tier-safe). For the full six-model lineup use `-c promptfooconfig.full.yaml`; uncomment the paid `openai:gpt-4o-mini` / `anthropic:messages:claude-haiku-4-5` lines there to add closed-weight vendors. Add their keys to `.env` first.

### Notes on the default lineup

- The default configs run **three** providers over a curated 4-case subset, so a full pass stays well under Groq's free-tier rate limit (~30 req/min per key) and finishes in seconds. The six-model lineup (`promptfooconfig.full.yaml` / `.full.finance.yaml`) queues behind the shared Groq grader and can hit request timeouts on the free tier — use paid keys for it.
- gpt-oss models emit hidden reasoning tokens, so they spend ~2× the tokens of the Llama models per response. The `javascript` length assertion (≤ 40 words) in `tests/cost-context.yaml` can fail for the more verbose gpt-oss models — that's intentional, it's a signal you're meant to spot. (Note: `cost` assertions were removed — Groq's free tier returns no cost field, which makes them *error* rather than pass.)
- The grader (judge LLM for `llm-rubric` assertions) is `groq:llama-3.3-70b-versatile`, set via `defaultTest.options.provider`. Workshop attendees don't need an OpenAI key for grading.

## Troubleshooting

See [docs/03-troubleshooting.md](docs/03-troubleshooting.md).
