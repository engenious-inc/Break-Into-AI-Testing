#!/usr/bin/env node
// PayFlow GenAI demo — HTTP surface.
//
//   GET  /        -> workshop chat UI (public/index.html)
//   GET  /health  -> {"status":"ok", ...}   run this before an eval
//   POST /chat    -> {answer, route, citations, debug}
//
// Usage: node modules/03-app-testing/payflow/server.js   (or ./run.sh payflow-serve)
// Port:  PAYFLOW_PORT, default 8000.

const fs = require('fs');
const http = require('http');
const path = require('path');
const { loadKey, loadCorpus, handleChat } = require('./pipeline');

const PORT = Number(process.env.PAYFLOW_PORT || 8000);
const MAX_BODY_BYTES = 64 * 1024;
const PUBLIC_DIR = path.join(__dirname, 'public');
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
};

function send(res, status, payload) {
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
}

function sendFile(res, filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const type = MIME[ext] || 'application/octet-stream';
  const body = fs.readFileSync(filePath);
  res.writeHead(200, {
    'Content-Type': type,
    'Content-Length': body.length,
  });
  res.end(body);
}

function resolvePublic(pathname) {
  const rel = pathname === '/' ? 'index.html' : pathname.replace(/^\//, '');
  const resolved = path.resolve(PUBLIC_DIR, rel);
  if (!resolved.startsWith(PUBLIC_DIR + path.sep) && resolved !== PUBLIC_DIR) {
    return null;
  }
  if (!fs.existsSync(resolved) || !fs.statSync(resolved).isFile()) {
    return null;
  }
  return resolved;
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        reject(new Error(`request body exceeded ${MAX_BODY_BYTES} bytes`));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

const apiKey = loadKey();
const corpus = loadCorpus();
const docCount = Object.values(corpus).reduce((n, docs) => n + docs.length, 0);
const poisoned = process.env.PAYFLOW_POISON === '1';

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);

  if (req.method === 'GET' && url.pathname === '/health') {
    return send(res, 200, {
      status: 'ok',
      service: 'payflow-genai-demo',
      specialists: Object.keys(corpus),
      documents: docCount,
      poisoned,
    });
  }

  if (req.method === 'GET') {
    const filePath = resolvePublic(url.pathname);
    if (filePath) return sendFile(res, filePath);
  }

  if (req.method === 'POST' && url.pathname === '/chat') {
    let payload;
    try {
      payload = JSON.parse(await readBody(req));
    } catch (err) {
      return send(res, 400, { error: `invalid JSON body: ${err.message}` });
    }
    const message = payload.message;
    if (typeof message !== 'string' || message.trim() === '') {
      return send(res, 400, { error: 'field "message" is required and must be a non-empty string' });
    }
    try {
      const result = await handleChat(apiKey, corpus, message, {
        session_id: payload.session_id,
        user_role: payload.user_role,
      });
      console.log(`  ${result.route.orchestrator_decision.padEnd(28)} ${result.debug.latency_ms}ms  ${message.slice(0, 58)}`);
      return send(res, 200, { ...result, session_id: payload.session_id ?? null });
    } catch (err) {
      console.error(`  ERROR  ${err.message}`);
      return send(res, 502, { error: err.message });
    }
  }

  return send(res, 404, { error: `no route for ${req.method} ${url.pathname}` });
});

server.listen(PORT, () => {
  console.log(`PayFlow GenAI demo listening on http://localhost:${PORT}`);
  console.log(`  ${docCount} documents across ${Object.keys(corpus).join(', ')}`);
  if (poisoned) {
    console.log('  PAYFLOW_POISON=1 — corpus/poisoned.json is loaded (Day 8 lesson)');
  }
  console.log(`  GET  /         GET /health   POST /chat`);
});
