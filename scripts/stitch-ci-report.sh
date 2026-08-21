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

# args: file tab idx kicker_class kicker title hint
card() {
  local file="$1" tab="$2" idx="$3" kclass="$4" kicker="$5" title="$6" hint="$7"
  if [ -f "$site/$file" ]; then
    cat <<EOF
<a class="card report-link" href="${file}" data-tab="${tab}" target="${tab}" rel="noopener noreferrer">
  <span class="idx">${idx}</span>
  <span class="copy">
    <span class="kicker ${kclass}">${kicker}</span>
    <span class="title">${title}</span>
    <span class="hint">${hint}</span>
  </span>
  <span class="go" aria-hidden="true">→</span>
</a>
EOF
  else
    cat <<EOF
<div class="card missing">
  <span class="idx">${idx}</span>
  <span class="copy">
    <span class="kicker ${kclass}">${kicker}</span>
    <span class="title">${title}</span>
    <span class="hint">Not produced on this run</span>
  </span>
</div>
EOF
  fi
}

cat > "$site/index.html" <<'HDR'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Eval reports</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,520&family=Source+Sans+3:wght@400;600&display=swap" rel="stylesheet">
  <style>
    :root {
      --ink: #1a1612;
      --muted: #6b645c;
      --rule: #e4ddd4;
      --paper: #f6f1e8;
      --card: #fffdf8;
      --ordinary: #2f6f4e;
      --inverted: #a33b24;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      color: var(--ink);
      background:
        radial-gradient(ellipse 80% 50% at 100% -10%, #efe4d4 0%, transparent 50%),
        var(--paper);
      font-family: "Source Sans 3", sans-serif;
    }
    main { max-width: 40rem; margin: 0 auto; padding: 3.25rem 1.4rem 4rem; }
    header { margin-bottom: 2rem; padding-bottom: 1.25rem; border-bottom: 1px solid var(--rule); }
    .eyebrow {
      font-size: 0.72rem;
      font-weight: 600;
      letter-spacing: 0.16em;
      text-transform: uppercase;
      color: var(--muted);
    }
    h1 {
      margin: 0.35rem 0 0;
      font-family: Fraunces, serif;
      font-size: clamp(2rem, 5vw, 2.6rem);
      font-weight: 520;
      letter-spacing: -0.03em;
      line-height: 1.1;
    }
    .list { display: grid; gap: 0.75rem; }
    .card {
      display: grid;
      grid-template-columns: auto 1fr auto;
      gap: 1rem;
      align-items: center;
      padding: 1.05rem 1.15rem;
      background: var(--card);
      border: 1px solid var(--rule);
      border-radius: 4px;
      text-decoration: none;
      color: inherit;
      box-shadow: 0 1px 0 rgba(26, 22, 18, 0.04);
      transition: transform 0.15s ease, border-color 0.15s ease, box-shadow 0.15s ease;
    }
    a.card:hover, a.card:focus-visible {
      transform: translateY(-1px);
      border-color: #c9beb0;
      box-shadow: 0 8px 24px rgba(26, 22, 18, 0.07);
      outline: none;
    }
    .idx {
      font-family: Fraunces, serif;
      font-size: 1.15rem;
      color: var(--muted);
      width: 1.6rem;
    }
    .copy { display: flex; flex-direction: column; gap: 0.15rem; min-width: 0; }
    .kicker {
      font-size: 0.68rem;
      font-weight: 600;
      letter-spacing: 0.14em;
      text-transform: uppercase;
    }
    .kicker.ordinary { color: var(--ordinary); }
    .kicker.inverted { color: var(--inverted); }
    .title { font-size: 1.12rem; font-weight: 600; letter-spacing: -0.015em; }
    .hint { font-size: 0.88rem; color: var(--muted); }
    .go { color: var(--muted); font-size: 1.15rem; transition: transform 0.15s ease, color 0.15s ease; }
    a.card:hover .go { color: var(--ink); transform: translateX(3px); }
    .missing { opacity: 0.55; }
    #frame-wrap { margin-top: 1.5rem; }
    iframe {
      width: 100%;
      min-height: 70vh;
      border: 1px solid var(--rule);
      border-radius: 4px;
      background: var(--card);
    }
  </style>
</head>
<body>
  <main>
    <header>
      <p class="eyebrow">Break Into AI Testing</p>
      <h1>Eval reports</h1>
    </header>
    <div class="list">
HDR

{
  card ordinary.html pf-ordinary "01" ordinary Ordinary "Module 0 · contains" "Fail = defect"
  card medibot.html pf-medibot "02" inverted Inverted "MediBot red team" "Fail = finding"
  card payflow.html pf-payflow "03" ordinary Ordinary "PayFlow routing" "Fail = defect"
  cat <<'FTR'
    </div>
    <div id="frame-wrap" hidden>
      <iframe id="frame" title="Promptfoo report"></iframe>
    </div>
  </main>
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
