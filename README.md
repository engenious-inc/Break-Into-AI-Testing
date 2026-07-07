# Breaking GPT & Claude — Promptfoo Red-Team Workshop

Hands-on AI bug-bounty workshop. You'll red-team two chatbots — **MediBot** (healthcare triage) and **FinanceBot** (retail brokerage) — using [Promptfoo](https://www.promptfoo.dev). Both are built the way most production AI assistants are built: an open-weight LLM + a guardrail system prompt, served via Groq's free tier. Same attack surface, different domain rules.

The default config is **free-tier-safe**: a curated subset (4–6 cases) run against three Groq models — a small Llama (`llama-3.1-8b-instant`), a large Llama (`llama-3.3-70b-versatile`), and an OpenAI open-weight (`gpt-oss-20b`). This stays comfortably under Groq's free-tier rate limit (~30 req/min). To widen the matrix, uncomment the extra Groq models (or the paid `openai:gpt-4o-mini` / `anthropic:claude-haiku-4-5` providers) in the config — but watch the rate limit on the free tier.

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

The script will: check Node ≥ 20, install Promptfoo, prompt for your Groq key (and optionally an OpenRouter fallback key — press Enter to skip), write `.env`, and run a smoke test.

## Run the workshop eval

```bash
npx promptfoo@latest eval -c promptfooconfig.medibot.yaml   # MediBot (free-tier-safe)
npx promptfoo@latest eval -c promptfooconfig.finance.yaml   # FinanceBot (free-tier-safe)
npx promptfoo@latest view                                   # opens the web UI
```

> **Hitting Groq throttling?** promptfoo runs 4 calls at once by default, which can burst past Groq's ~30 req/min limit (especially on a reused key). Add `-j 2` (or `-j 1`) to serialize: `npx promptfoo@latest eval -c promptfooconfig.medibot.yaml -j 2`.

> **Groq down entirely?** Use the OpenRouter fallback. Put the cohort `OPENROUTER_API_KEY` (your instructor shares it) in `.env`, then run `npx promptfoo@latest eval -c promptfooconfig.openrouter.medibot.yaml` (or `promptfooconfig.openrouter.finance.yaml`). Same tests, routed to OpenRouter instead of Groq.

## What you'll do

1. **Prompt-injection / jailbreaks** — try to bypass system-prompt guardrails
2. **Hallucination traps** — confirm the model refuses to invent facts
3. **Cost & context** — assert latency and response-length thresholds
4. **Multi-model comparison** — the default config runs three Groq-hosted models (free-tier-safe). Uncomment the extra Groq models, or the paid `openai:gpt-4o-mini` / `anthropic:messages:claude-haiku-4-5` lines, in the config to widen the matrix. Add any paid-vendor keys to `.env` first.

All cases live in `tests/smoke.medibot.yaml` (MediBot) and `tests/smoke.finance.yaml` (FinanceBot) — one curated case per category. Add your own attacks there.

### Notes on the default lineup

- The configs run **three** providers over a curated subset (MediBot 6 cases, FinanceBot 4), so a full pass stays well under Groq's free-tier rate limit (~30 req/min per key) and finishes in seconds. Adding all six Groq models can queue behind the shared grader and hit request timeouts on the free tier — widen the matrix only with paid keys or `-j 2`.
- gpt-oss models emit hidden reasoning tokens, so they spend ~2× the tokens of the Llama models per response. The `javascript` length assertion (≤ 40 words) can fail for the more verbose gpt-oss models — that's intentional, it's a signal you're meant to spot. (Note: `cost` assertions are avoided — Groq's free tier returns no cost field, which makes them *error* rather than pass.)
- The grader (judge LLM for `llm-rubric` assertions) is `groq:llama-3.3-70b-versatile`, set via `defaultTest.options.provider`. Workshop attendees don't need an OpenAI key for grading.

## Hackathon challenges

Running this as a competition? See [docs/04-challenges.md](docs/04-challenges.md) — three challenges (Break → Fix → Build), all teams do all three, judged on creativity and originality.

## Troubleshooting

See [docs/03-troubleshooting.md](docs/03-troubleshooting.md).
