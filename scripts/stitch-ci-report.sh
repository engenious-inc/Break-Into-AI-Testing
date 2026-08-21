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

# args: file tab idx tone kicker title hint
card() {
  local file="$1" tab="$2" idx="$3" tone="$4" kicker="$5" title="$6" hint="$7"
  if [ -f "$site/$file" ]; then
    cat <<EOF
<a class="card tone-${tone} report-link" href="${file}" data-tab="${tab}" target="${tab}" rel="noopener noreferrer">
  <span class="idx">${idx}</span>
  <span class="copy">
    <span class="kicker">${kicker}</span>
    <span class="title">${title}</span>
    <span class="hint">${hint}</span>
  </span>
  <span class="go" aria-hidden="true">→</span>
</a>
EOF
  else
    cat <<EOF
<div class="card tone-${tone} missing">
  <span class="idx">${idx}</span>
  <span class="copy">
    <span class="kicker">${kicker}</span>
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
  <link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,600&family=Source+Sans+3:wght@400;600;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --ink: #0f1b2d;
      --muted: #5b6b82;
      --paper: #eef3fb;
      --teal: #0f9d8a;
      --coral: #e25b3a;
      --indigo: #4c6fff;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      color: var(--ink);
      background:
        radial-gradient(900px 420px at -10% -20%, rgba(15, 157, 138, 0.18), transparent 55%),
        radial-gradient(800px 380px at 110% 0%, rgba(76, 111, 255, 0.16), transparent 50%),
        radial-gradient(700px 360px at 80% 110%, rgba(226, 91, 58, 0.12), transparent 45%),
        var(--paper);
      font-family: "Source Sans 3", sans-serif;
    }
    .hero {
      background: linear-gradient(115deg, #0d2a52 0%, #155e6e 58%, #0f9d8a 120%);
      color: #fff;
      padding: 2.4rem 1.4rem 2.2rem;
      box-shadow: 0 12px 40px rgba(18, 49, 92, 0.22);
    }
    .hero-inner { max-width: 44rem; margin: 0 auto; }
    .eyebrow {
      margin: 0;
      font-size: 0.75rem;
      font-weight: 700;
      letter-spacing: 0.18em;
      text-transform: uppercase;
      color: #9fe8dc;
    }
    h1 {
      margin: 0.4rem 0 0;
      font-family: Fraunces, serif;
      font-size: clamp(2.1rem, 5.5vw, 2.85rem);
      font-weight: 600;
      letter-spacing: -0.03em;
      line-height: 1.08;
    }
    main { max-width: 44rem; margin: 0 auto; padding: 1.6rem 1.4rem 4rem; }
    .list { display: grid; gap: 1rem; }
    .card {
      display: grid;
      grid-template-columns: auto 1fr auto;
      gap: 1rem;
      align-items: center;
      padding: 1.15rem 1.2rem 1.15rem 1.05rem;
      border-radius: 14px;
      text-decoration: none;
      color: inherit;
      border: 1px solid transparent;
      border-left: 6px solid var(--accent);
      background: linear-gradient(180deg, #fff 0%, color-mix(in srgb, var(--accent) 9%, #fff) 100%);
      box-shadow: 0 10px 28px color-mix(in srgb, var(--accent) 18%, transparent);
      transition: transform 0.16s ease, box-shadow 0.16s ease;
    }
    .tone-teal { --accent: var(--teal); }
    .tone-coral { --accent: var(--coral); }
    .tone-indigo { --accent: var(--indigo); }
    a.card:hover, a.card:focus-visible {
      transform: translateY(-3px);
      box-shadow: 0 16px 36px color-mix(in srgb, var(--accent) 28%, transparent);
      outline: none;
    }
    .idx {
      display: grid;
      place-items: center;
      width: 2.4rem;
      height: 2.4rem;
      border-radius: 10px;
      background: var(--accent);
      color: #fff;
      font-family: Fraunces, serif;
      font-size: 1rem;
      font-weight: 600;
    }
    .copy { display: flex; flex-direction: column; gap: 0.18rem; min-width: 0; }
    .kicker {
      display: inline-flex;
      align-self: start;
      padding: 0.14rem 0.5rem;
      border-radius: 999px;
      background: color-mix(in srgb, var(--accent) 16%, #fff);
      color: var(--accent);
      font-size: 0.68rem;
      font-weight: 700;
      letter-spacing: 0.12em;
      text-transform: uppercase;
    }
    .title { font-size: 1.18rem; font-weight: 700; letter-spacing: -0.02em; }
    .hint { font-size: 0.9rem; color: var(--muted); font-weight: 600; }
    .go {
      color: var(--accent);
      font-size: 1.35rem;
      font-weight: 700;
      transition: transform 0.16s ease;
    }
    a.card:hover .go { transform: translateX(4px); }
    .missing { opacity: 0.58; filter: grayscale(0.25); }
    #frame-wrap { margin-top: 1.5rem; }
    iframe {
      width: 100%;
      min-height: 70vh;
      border: 0;
      border-radius: 14px;
      background: #fff;
      box-shadow: 0 10px 28px rgba(18, 49, 92, 0.12);
    }
  </style>
</head>
<body>
  <div class="hero">
    <div class="hero-inner">
      <p class="eyebrow">Break Into AI Testing</p>
      <h1>Eval reports</h1>
    </div>
  </div>
  <main>
    <div class="list">
HDR

{
  card ordinary.html pf-ordinary "01" teal Ordinary "Module 0 · contains" "Fail = defect"
  card medibot.html pf-medibot "02" coral Inverted "MediBot red team" "Fail = finding"
  card payflow.html pf-payflow "03" indigo Ordinary "PayFlow routing" "Fail = defect"
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
