// PayFlow OTLP export — same encoder and backends as the Day 8 TutorBot lesson.
//
// Zero npm dependencies. The protobuf is hand-encoded in
// modules/02-advanced-eval/observability/otlp.mjs; this file is the redact +
// POST half, copied from that lesson's provider.mjs so PayFlow (CommonJS) can
// call it without turning the eval provider into an app dependency.
//
// Skips whichever backends are unconfigured. A telemetry outage must not fail
// the /chat request it is only observing.

const { createHash } = require('node:crypto');
const { AsyncLocalStorage } = require('node:async_hooks');

const SCOPE_NAME = 'openinference.instrumentation.openai';
const otlpReady = import('../../02-advanced-eval/observability/otlp.mjs');
const als = new AsyncLocalStorage();

function sha256(text) {
  return createHash('sha256').update(text).digest('hex');
}

// Telemetry is itself a place user data leaks, so raw text is opt-in.
// Default off: the backend receives a hash and a length, never the prompt.
function redactForTelemetry(text) {
  if (process.env.LOG_RAW_PROMPTS === 'true') return text;
  return `sha256:${sha256(text)} (len=${text.length})`;
}

// Two vendors, one payload. Both accept the exact same protobuf bytes — so all
// that differs is where it goes and how the request is signed.
//
// Arato:  <OTEL_EXPORTER_OTLP_ENDPOINT>/v1/traces      Authorization: Bearer <key>
// Agenta: <AGENTA_HOST>/api/otlp/v1/traces             Authorization: ApiKey <key>
const BACKENDS = [
  {
    name: 'arato',
    keyVar: 'ARATO_API_KEY',
    hostVar: 'OTEL_EXPORTER_OTLP_ENDPOINT',
    defaultHost: null,
    path: '/v1/traces',
    auth: (k) => `Bearer ${k}`,
  },
  {
    name: 'agenta',
    keyVar: 'AGENTA_API_KEY',
    hostVar: 'AGENTA_HOST',
    defaultHost: 'https://eu.cloud.agenta.ai',
    path: '/api/otlp/v1/traces',
    auth: (k) => `ApiKey ${k}`,
  },
];

let skippedLogged = false;

function compactAttributes(attrs) {
  const out = {};
  for (const [key, value] of Object.entries(attrs)) {
    if (value === null || value === undefined || value === '') continue;
    out[key] = value;
  }
  return out;
}

function llmAttributes(entry) {
  const question = [...entry.messages].reverse().find((m) => m.role === 'user')?.content ?? '';
  const usage = entry.usage || {};
  return compactAttributes({
    'openinference.span.kind': 'LLM',
    'llm.system': 'groq',
    'llm.provider': 'groq',
    'llm.model_name': entry.model,
    'llm.token_count.prompt': usage.prompt_tokens ?? 0,
    'llm.token_count.completion': usage.completion_tokens ?? 0,
    'llm.token_count.total': usage.total_tokens ?? 0,
    ...Object.fromEntries(entry.messages.flatMap((m, i) => [
      [`llm.input_messages.${i}.message.role`, m.role],
      [`llm.input_messages.${i}.message.content`, redactForTelemetry(m.content)],
    ])),
    'llm.output_messages.0.message.role': 'assistant',
    'llm.output_messages.0.message.content': redactForTelemetry(entry.content),
    'input.value': redactForTelemetry(question),
    'output.value': redactForTelemetry(entry.content),
    'prompt.sha256': sha256(question),
    'payflow.stage': entry.stage,
  });
}

async function sendTo(backend, body, traceId) {
  const host = (process.env[backend.hostVar] || backend.defaultHost).replace(/\/+$/, '');
  const url = host + backend.path;
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-protobuf',
        Authorization: backend.auth(process.env[backend.keyVar]),
      },
      body,
    });
    const detail = res.ok ? '' : ` — ${(await res.text()).replace(/\s+/g, ' ').slice(0, 200)}`;
    console.log(`[${backend.name}] OTLP ${res.status} trace_id=${traceId}${detail}`);
  } catch (err) {
    console.error(`[${backend.name}] OTLP export to ${url} failed: ${err.message}`);
  }
}

async function exportSpans(params) {
  const { encodeTrace } = await otlpReady;
  const body = encodeTrace(params);
  const traceId = params.traceId.toString('hex');

  const active = BACKENDS.filter((b) => process.env[b.keyVar]
    && (process.env[b.hostVar] || b.defaultHost));

  if (active.length === 0) {
    if (!skippedLogged) {
      console.log('[otlp] skipped — set ARATO_API_KEY (+OTEL_EXPORTER_OTLP_ENDPOINT) '
        + 'or AGENTA_API_KEY to export for real');
      skippedLogged = true;
    }
    return;
  }

  await Promise.all(active.map((b) => sendTo(b, body, traceId)));
}

function currentTrace() {
  return als.getStore();
}

async function withRequestTrace(meta, fn) {
  const { newTraceId, newSpanId } = await otlpReady;
  const traceId = newTraceId();
  const parentSpanId = newSpanId();
  const startMs = Date.now();
  const children = [];
  const store = {
    recordLlm(entry) {
      children.push({ ...entry, spanId: newSpanId() });
    },
  };

  let result;
  try {
    result = await als.run(store, fn);
  } catch (err) {
    await finish(undefined);
    throw err;
  }
  await finish(result);
  return result;

  async function finish(outcome) {
    try {
      const endMs = Date.now();
      const latency = outcome?.debug?.latency_ms ?? (endMs - startMs);
      const spans = [
        {
          spanId: parentSpanId,
          name: 'payflow.chat',
          kind: 2,
          startMs,
          endMs,
          attributes: compactAttributes({
            'openinference.span.kind': 'CHAIN',
            session_id: typeof meta.session_id === 'string' ? meta.session_id : undefined,
            user_role: typeof meta.user_role === 'string' ? meta.user_role : undefined,
            'route.guard_status': outcome?.route?.guard_status,
            'route.orchestrator_decision': outcome?.route?.orchestrator_decision,
            'debug.latency_ms': latency,
          }),
        },
        ...children.map((child) => ({
          spanId: child.spanId,
          parentSpanId,
          name: 'llm.chat.completion',
          kind: 3,
          startMs: child.startMs,
          endMs: child.endMs,
          attributes: llmAttributes(child),
        })),
      ];

      console.log(JSON.stringify({
        span: 'payflow.chat',
        trace_id: traceId.toString('hex'),
        span_id: parentSpanId.toString('hex'),
        duration_ms: latency,
        session_id: typeof meta.session_id === 'string' ? meta.session_id : null,
        stages: children.map((c) => c.stage),
      }));

      await exportSpans({
        traceId,
        scopeName: SCOPE_NAME,
        serviceName: process.env.OTEL_SERVICE_NAME || 'break-into-ai-testing',
        spans,
      });
    } catch (err) {
      console.error(`[otlp] export failed: ${err.message}`);
    }
  }
}

module.exports = { withRequestTrace, currentTrace, redactForTelemetry, sha256 };
