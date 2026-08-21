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
  local file="$1" tab="$2" label="$3"
  if [ -f "$site/$file" ]; then
    printf '<a class="card report-link" href="%s" data-tab="%s" target="%s" rel="noopener noreferrer">%s</a>\n' \
      "$file" "$tab" "$tab" "$label"
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
    .card { display: block; border: 1px solid #d0d7de; border-radius: 8px; padding: 0.9rem 1.1rem; margin: 0.7rem 0; text-decoration: none; color: inherit; }
    a.card:hover { border-color: #0969da; }
    #frame-wrap { margin-top: 1.2rem; }
    iframe { width: 100%; min-height: 70vh; border: 1px solid #d0d7de; border-radius: 8px; }
  </style>
</head>
<body>
  <h1>Promptfoo eval &amp; red team</h1>
  <p class="muted">Latest classroom demo from GitHub Actions. Click a report — it opens in its own tab and this index stays. In a one-tab preview, it loads below instead. These are Promptfoo HTML reports, not Allure. <code>npx promptfoo view</code> is local-only.</p>
HDR

{
  link_or_missing ordinary.html pf-ordinary "Ordinary eval — Module 0 contains (fail = defect)"
  link_or_missing medibot.html pf-medibot "Inverted red team — MediBot (fail = finding)"
  link_or_missing payflow.html pf-payflow "Ordinary eval — PayFlow routing sample (fail = defect)"
  cat <<'FTR'
  <div id="frame-wrap" hidden>
    <p class="muted">Preview (this browser blocked a second tab):</p>
    <iframe id="frame" title="Promptfoo report"></iframe>
  </div>
  <p class="muted">Each demo run overwrites this site. JSON artifacts remain on the workflow run as a fallback.</p>
  <script>
    document.querySelectorAll('.report-link').forEach((a) => {
      a.addEventListener('click', (e) => {
        e.preventDefault();
        const name = a.getAttribute('data-tab') || 'pf-report';
        const opened = window.open(a.href, name);
        if (opened) {
          opened.opener = null;
          opened.focus();
          return;
        }
        const wrap = document.getElementById('frame-wrap');
        const frame = document.getElementById('frame');
        wrap.hidden = false;
        frame.src = a.href;
      });
    });
  </script>
</body>
</html>
FTR
} >> "$site/index.html"

echo "wrote $site/index.html"
