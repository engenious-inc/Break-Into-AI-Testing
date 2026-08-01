#!/usr/bin/env node
// Regenerate docs/qr.png and docs/scan-me.svg for the workshop slides.
// Usage: REPO_URL=https://github.com/you/promptfoo-redteam-workshop node scripts/generate-qr.js

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const REPO_URL = process.env.REPO_URL || 'https://github.com/YOUR_USERNAME/promptfoo-redteam-workshop';

try {
  require.resolve('qrcode');
} catch {
  console.log('Installing qrcode…');
  execSync('npm install --no-save qrcode', { stdio: 'inherit' });
}

const QRCode = require('qrcode');
const outDir = path.join(__dirname, '..', 'docs');
fs.mkdirSync(outDir, { recursive: true });

(async () => {
  // Plain QR
  await QRCode.toFile(path.join(outDir, 'qr.png'), REPO_URL, {
    width: 600,
    margin: 2,
    color: { dark: '#000000', light: '#FFFFFF' },
  });
  console.log('✓ docs/qr.png');

  // Slide-ready "scan me" card: QR on white with caption
  const qrSvg = await QRCode.toString(REPO_URL, { type: 'svg', margin: 1, width: 800 });
  const inner = qrSvg.replace(/<\?xml[^?]*\?>/, '').replace(/<svg[^>]*>/, '').replace(/<\/svg>/, '');
  const card = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1350" viewBox="0 0 1080 1350">
  <rect width="1080" height="1350" fill="#ffffff"/>
  <text x="540" y="120" font-family="Helvetica, Arial, sans-serif" font-size="56" font-weight="bold" text-anchor="middle" fill="#111">Breaking GPT &amp; Claude</text>
  <text x="540" y="180" font-family="Helvetica, Arial, sans-serif" font-size="32" text-anchor="middle" fill="#555">Promptfoo Red-Team Workshop</text>
  <g transform="translate(140, 240) scale(1)">
    <svg width="800" height="800" viewBox="0 0 800 800">${inner}</svg>
  </g>
  <text x="540" y="1130" font-family="Helvetica, Arial, sans-serif" font-size="36" text-anchor="middle" fill="#111">Scan to clone the repo</text>
  <text x="540" y="1190" font-family="Menlo, Consolas, monospace" font-size="24" text-anchor="middle" fill="#666">${REPO_URL}</text>
</svg>`;
  fs.writeFileSync(path.join(outDir, 'scan-me.svg'), card);
  console.log('✓ docs/scan-me.svg (render to PNG with: rsvg-convert or any browser)');
})();
