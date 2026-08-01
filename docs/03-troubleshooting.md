# Troubleshooting

### `node: command not found` / `node` is not recognized
The setup script tries to install Node 20 via Homebrew (macOS) or winget (Windows). If it can't, install manually from <https://nodejs.org> (LTS), then re-run the setup script.

### `401 Unauthorized` from Groq (default path)
Groq is the default provider, so this is the 401 most students hit: your `GROQ_API_KEY` in `.env` is missing, wrong, or expired. Get a fresh key at <https://console.groq.com/keys>, paste it into `.env`, then run `./preflight.sh` (`.\preflight.ps1` on Windows) to confirm before re-running the eval.

### `401 Unauthorized` from OpenAI
Your `OPENAI_API_KEY` in `.env` is missing or wrong. Verify at <https://platform.openai.com/api-keys>, then re-run `npx promptfoo@latest eval -c promptfooconfig.medibot.yaml`.

### `429 Rate limit` from OpenAI
You're being throttled on the per-minute request limit. Wait a few seconds and re-run, or lower concurrency:
```bash
npx promptfoo@latest eval -c promptfooconfig.medibot.yaml -j 1
```

### Groq eval hangs or times out (free-tier rate limit)
Groq's free tier allows ~30 requests/min per key. promptfoo runs 4 calls concurrently by default, so it can burst past that — calls queue and may hit the request timeout, which looks like a hang. Serialize the run so it stays under the limit:
```bash
npx promptfoo@latest eval -c promptfooconfig.medibot.yaml -j 2   # or -j 1 for one call at a time
```
Or space the calls out — with or without lowering concurrency — with `--delay` (milliseconds between calls):
```bash
npx promptfoo@latest eval -c promptfooconfig.medibot.yaml -j 1 --delay 1000
```
A single default run (3 models × the curated subset) is small enough to finish in seconds this way. If it still stalls, you may have exhausted the key's daily quota — wait for the reset or use a fresh key. If you widen the matrix by uncommenting the extra Groq models, expect throttling on the free tier — use `-j 2` or paid keys.

### Groq is down or your key is fully exhausted — use the OpenRouter fallback
If serializing with `-j 2` still fails (Groq outage, or daily quota gone), switch to the OpenRouter fallback config. Put the cohort key your instructor shares into `.env`:
```bash
OPENROUTER_API_KEY=sk-or-...
```
Then run the same tests routed to OpenRouter:
```bash
npx promptfoo@latest eval -c promptfooconfig.openrouter.medibot.yaml  # MediBot
npx promptfoo@latest eval -c promptfooconfig.openrouter.finance.yaml  # FinanceBot
```
Use this only when Groq is unavailable — it spends the shared cohort budget.

### `429 insufficient_quota` from OpenAI
Different from rate-limit. Your account has no credit balance, or your monthly cap is hit. Fix at <https://platform.openai.com/settings/organization/billing> (add a payment method or top up). Then re-run — no other change needed.

### `better-sqlite3` ABI / Node version mismatch on first `npx promptfoo`
A stale npx cache from an older Node version. Fix:
```bash
rm -rf ~/.npm/_npx        # macOS / Linux
# Windows PowerShell:
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\npm-cache\_npx"
```
Then re-run the setup script.

### `npx promptfoo` is slow the first time
First run downloads the package (~50 MB). Subsequent runs use the npx cache and are instant.

### Windows: smoke test passes but `eval` hangs
Make sure you opened a **new** PowerShell window after Node was installed — the old window doesn't see the updated PATH.

### "I want to start over"
```bash
rm -rf .env .promptfoo node_modules
./setup.sh
```

### `preflight.sh` (or `preflight.ps1`) says NOT READY

Fix the item(s) marked `✗`:

- **GROQ_API_KEY not set / still the placeholder** — run `./setup.sh`, or paste your key into `.env`. Get one free at https://console.groq.com/keys.
- **Groq rejected your key (401)** — the key is wrong or expired. Regenerate it and update `.env`.
- **Currently throttled (429)** — transient; wait the reported seconds and add `-j 2` to your evals. Your setup is fine.
- **Couldn't reach api.groq.com** — check your network / VPN; if Groq is down, use the OpenRouter fallback (see the section above).
- **Node / Promptfoo / .env missing** — run `./setup.sh` again.
- **Missing starter files** — restore with the `git checkout -- <file>` command preflight prints.

