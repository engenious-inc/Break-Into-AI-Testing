# Quickstart

1. Clone this repo and `cd` into it.
2. Run `./setup.sh` (macOS/Linux) or `.\setup.ps1` (Windows).
3. Paste your OpenAI API key when prompted.
4. `npx promptfoo@latest eval` — runs all workshop tests.
5. `npx promptfoo@latest view` — opens the result UI in your browser.

## File map

| File | What it does |
|---|---|
| `promptfooconfig.yaml` | MediBot eval config (**default** — free-tier-safe: 3 models, curated subset) |
| `promptfooconfig.finance.yaml` | FinanceBot eval config (default, run with `-c`) |
| `prompts/medibot.txt` | MediBot's system prompt — healthcare triage |
| `prompts/financebot.txt` | FinanceBot's system prompt — retail brokerage |
| `tests/smoke.medibot.yaml` | MediBot test cases — one curated case per category (jailbreak / hallucination / cost) |
| `tests/smoke.finance.yaml` | FinanceBot test cases — one curated case per category |

## Enabling GPT vs Claude

1. Add `ANTHROPIC_API_KEY=sk-ant-...` to `.env`.
2. Uncomment the `anthropic:messages:claude-haiku-4-5` block in `promptfooconfig.yaml`.
3. Re-run `npx promptfoo@latest eval`. The UI will show side-by-side outputs and per-test pass/fail per provider.
