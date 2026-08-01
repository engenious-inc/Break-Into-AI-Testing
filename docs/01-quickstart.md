# Quickstart

1. Clone this repo and `cd` into it.
2. Run `./setup.sh` (macOS/Linux) or `.\setup.ps1` (Windows).
3. Paste your free Groq API key when prompted (get one at <https://console.groq.com/keys>).
4. `npx promptfoo@latest eval -c promptfooconfig.medibot.yaml` — runs the MediBot tests.
5. `npx promptfoo@latest view` — opens the result UI in your browser.

## File map

| File | What it does |
|---|---|
| `promptfooconfig.medibot.yaml` | MediBot eval config (free-tier-safe: 3 models, curated subset) |
| `promptfooconfig.finance.yaml` | FinanceBot eval config |
| `promptfooconfig.openrouter.medibot.yaml` | MediBot OpenRouter fallback (use if Groq is down) |
| `promptfooconfig.openrouter.finance.yaml` | FinanceBot OpenRouter fallback |
| `prompts/medibot.txt` | MediBot's system prompt — healthcare triage |
| `prompts/financebot.txt` | FinanceBot's system prompt — retail brokerage |
| `tests/smoke.medibot.yaml` | MediBot test cases — 6 curated cases across jailbreak / safety / hallucination / cost / exfiltration |
| `tests/smoke.finance.yaml` | FinanceBot test cases — one curated case per category |
| `preflight.sh` / `preflight.ps1` | read-only readiness probe; run before the workshop to confirm your key, network, and environment are good |

> Not sure you're ready? Run `./preflight.sh` (`.\preflight.ps1` on Windows) — it's safe to run repeatedly.

## Enabling GPT vs Claude

1. Add `ANTHROPIC_API_KEY=sk-ant-...` to `.env`.
2. Uncomment the `anthropic:messages:claude-haiku-4-5` block in `promptfooconfig.medibot.yaml`.
3. Re-run `npx promptfoo@latest eval -c promptfooconfig.medibot.yaml`. The UI will show side-by-side outputs and per-test pass/fail per provider.
