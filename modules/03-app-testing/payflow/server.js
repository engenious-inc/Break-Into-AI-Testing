#!/usr/bin/env node
// PayFlow GenAI demo — HTTP surface.
//
//   GET  /health  -> {"status":"ok", ...}   run this before an eval
//   POST /chat    -> {answer, route, citations, debug}
//
// Usage: node modules/03-app-testing/payflow/server.js   (or ./run.sh payflow-serve)
// Port:  PAYFLOW_PORT, default 8000.

const http = require('http');
const { loadKey, loadCorpus, handleChat } = require('./pipeline');

const PORT = Number(process.env.PAYFLOW_PORT || 8000);
const MAX_BODY_BYTES = 64 * 1024;

function send(res, status, payload) {
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
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

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);

  if (req.method === 'GET' && url.pathname === '/health') {
    return send(res, 200, {
      status: 'ok',
      service: 'payflow-genai-demo',
      specialists: Object.keys(corpus),
      documents: docCount,
    });
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
      const result = await handleChat(apiKey, corpus, message);
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
  console.log(`  GET  /health   POST /chat`);
});
