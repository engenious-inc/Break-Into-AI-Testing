# Troubleshooting

### `node: command not found` / `node` is not recognized
The setup script tries to install Node 20 via Homebrew (macOS) or winget (Windows). If it can't, install manually from <https://nodejs.org> (LTS), then re-run the setup script.

### `401 Unauthorized` from OpenAI
Your `OPENAI_API_KEY` in `.env` is missing or wrong. Verify at <https://platform.openai.com/api-keys>, then re-run `npx promptfoo@latest eval`.

### `429 Rate limit` from OpenAI
You're being throttled on the per-minute request limit. Wait a few seconds and re-run, or lower concurrency:
```bash
npx promptfoo@latest eval -j 1
```

### Groq eval hangs or times out (free-tier rate limit)
Groq's free tier allows ~30 requests/min per key. promptfoo runs 4 calls concurrently by default, so it can burst past that — calls queue and may hit the request timeout, which looks like a hang. Serialize the run so it stays under the limit:
```bash
npx promptfoo@latest eval -j 2        # or -j 1 for one call at a time
```
A single default run (3 models × the curated subset) is small enough to finish in seconds this way. If it still stalls, you may have exhausted the key's daily quota — wait for the reset or use a fresh key. Avoid the `*.full.yaml` configs on the free tier (6 models + grader overwhelm the limit).

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
