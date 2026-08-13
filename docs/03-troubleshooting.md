# Troubleshooting

### `node: command not found` / `node` is not recognized
The setup script tries to install Node 20 via Homebrew (macOS) or winget (Windows). If it can't, install manually from <https://nodejs.org> (LTS), then re-run the setup script.

### `401 Unauthorized` from Groq (default path)
Groq is the default provider, so this is the 401 most students hit: your `GROQ_API_KEY` in `.env` is missing, wrong, or expired. Get a fresh key at <https://console.groq.com/keys>, paste it into `.env`, then run `./preflight.sh` (`.\preflight.ps1` on Windows) to confirm before re-running the eval.

### `Cost assertion does not support providers that do not return cost`
Groq's free tier returns no cost field, so `type: cost` **errors** rather than fails:
```
  0 passed (0%)   0 failed (0%)   1 error (100%)
```
Errored is a third outcome: a failed assertion is a finding about the model, an errored one is a defect in your harness. Measure `latency` and token counts as cost proxies instead, and keep `type: cost` inside a commented-out paid-provider block. See `modules/02-advanced-eval/assert-sets-and-budgets/`.

### `ECONNREFUSED 127.0.0.1:1234` (local model)
```
API call error: Error: Request failed after 4 retries:
TypeError: fetch failed (Cause: Error: connect ECONNREFUSED 127.0.0.1:1234)
```
The LM Studio server isn't running. Open LM Studio → **Developer** tab → **Start Server**, confirm a model is loaded, then re-run. This error means your config is fine and the server is down — nothing to change in the YAML. Setup: `modules/00-promptfoo-basics/02-providers/local-model/README.md`.

### `comparing-models` fails 2 of 6 — is the repo broken?
No. That lesson fails **on purpose**: `groq:openai/gpt-oss-20b` prefixes its visible answer with its own chain of thought (`"Thinking: ..."`), and the suite's `not-icontains` catches it. See that lesson's README. `scripts/smoke-check.sh` counts promptfoo *errors*, not failures, so a red-by-design lesson still passes the smoke check.

### `ENOENT` on a `file://` prompt or test path
`file://` resolves relative to the **config file**, not the repo root — that's why `modules/00-promptfoo-basics/01-prompts/file-based/` climbs four levels to reach `prompts/`. Count the `../` from the config's own directory. (The run-from-repo-root rule governs `.env` discovery, a separate mechanism that happens to point the same direction.)

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
A single default run (3 models × the curated subset) is small enough to finish in seconds this way. If it still stalls, you may have exhausted the key's daily quota — wait for the reset or use a fresh key. If you widen the matrix by uncommenting the extra Groq models, expect throttling on the free tier — use `-j 1 --delay 1000` (what `./run.sh` already does) or paid keys.

### PayFlow & generated red team

These traps look like broken tests until you know the shape. Prefer `./run.sh …` — it
already bakes in the fixes.

**App is down → connection errors that look like assertion failures.** Start it first:
```bash
./run.sh payflow-serve      # terminal 1
./run.sh payflow-health     # terminal 2 — must print status: ok
./run.sh payflow
```
`./run.sh payflow` refuses to start if health fails, on purpose.

**Edited the corpus, re-ran, still got the old answer (`Duration: 0s`, empty server log).**
Promptfoo caches by request text and has no idea the documents behind `/chat` changed.
Bust the cache:
```bash
./run.sh payflow --no-cache
```

**`payflow-redteam` hangs / dies in 300s queue timeouts.** Promptfoo's `redteam run`
defaults to **4 concurrent** probes and ignores YAML `maxConcurrency`. Four PayFlow
requests is twelve Groq calls at once — that blows the free-tier **6000 TPM** cap, not
just the ~30 req/min request cap. Use `./run.sh payflow-redteam` (passes `-j 1 --delay
1000`), or if you call promptfoo yourself:
```bash
npx promptfoo@latest redteam eval -c redteam.yaml -j 1 --delay 1000
```

**`Invalid strategy(s): multilingual`.** Not a real strategy in current promptfoo. Use
`base64` / `rot13` (already in the recipe), or `homoglyph` / `leetspeak` / `morse` /
`piglatin`. See `modules/03-app-testing/LAB-GUIDE-NOTES.md`.

**`jailbreak` fails the whole scan with "requires remote generation".** Promptfoo turns
off its remote generator the moment it sees `OPENAI_API_KEY`, even if nothing here uses
OpenAI. `./run.sh payflow-redteam` clears that variable for the run. If you invoke
`npx promptfoo redteam run` yourself, unset it first: `env -u OPENAI_API_KEY …`.

**`credit_balance_exhausted` on a PayFlow / quality eval.** Promptfoo fell back to its
default OpenAI grader. Every shipped config that uses `llm-rubric` already sets
`defaultTest.options.provider: groq:llama-3.3-70b-versatile` — if you author a new one,
copy that block.

**PayFlow lab checklist.** Commands, inverted vs ordinary semantics, and redteam
gotchas: [`modules/03-app-testing/LAB-GUIDE-NOTES.md`](../modules/03-app-testing/LAB-GUIDE-NOTES.md).

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

