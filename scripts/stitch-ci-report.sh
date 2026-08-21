#!/usr/bin/env bash
# Stitch Promptfoo HTML artifacts from the Actions demo into a tiny site.
# Usage: ./scripts/stitch-ci-report.sh <artifacts-dir> <site-dir>
set -euo pipefail

artifacts="${1:?artifacts dir}"
site="${2:?site dir}"
mkdir -p "$site"

copy_html() {
  local src="$1" dest="$2"
  if [ -f "$src" ]; then
    cp "$src" "$site/$dest"
    echo "ok $dest"
  else
    echo "missing $src"
  fi
}

copy_html "$artifacts/eval-ordinary-results/eval-ordinary.html" ordinary.html
copy_html "$artifacts/redteam-medibot-results/redteam-medibot.html" medibot.html
copy_html "$artifacts/payflow-eval-results/payflow-eval.html" payflow.html

link_or_missing() {
  local file="$1" label="$2"
  if [ -f "$site/$file" ]; then
    printf '<div class="card"><a href="%s" target="_blank" rel="noopener noreferrer">%s</a></div>\n' "$file" "$label"
  else
    printf '<div class="card muted">%s — not produced on this run</div>\n' "$label"
  fi
}

cat > "$site/index.html" <<'HDR'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Promptfoo CI reports</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 42rem; margin: 2rem auto; padding: 0 1rem; line-height: 1.45; color: #1f2328; }
    h1 { font-size: 1.4rem; }
    a { color: #0969da; }
    .muted { color: #57606a; font-size: 0.95rem; }
    .card { border: 1px solid #d0d7de; border-radius: 8px; padding: 0.9rem 1.1rem; margin: 0.7rem 0; }
  </style>
</head>
<body>
  <h1>Promptfoo eval &amp; red team</h1>
  <p class="muted">Latest classroom demo from GitHub Actions. These are Promptfoo HTML reports — the same UI as <code>npx promptfoo view</code>, which only sees evals that ran on your laptop. Not Allure.</p>
HDR

{
  link_or_missing ordinary.html "Ordinary eval — Module 0 contains (fail = defect)"
  link_or_missing medibot.html "Inverted red team — MediBot (fail = finding)"
  link_or_missing payflow.html "Ordinary eval — PayFlow routing sample (fail = defect)"
  cat <<'FTR'
  <p class="muted">Each demo run overwrites this site. JSON artifacts remain on the workflow run as a fallback.</p>
</body>
</html>
FTR
} >> "$site/index.html"

echo "wrote $site/index.html"
