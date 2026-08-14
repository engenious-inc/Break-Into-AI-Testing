// Custom Promptfoo provider that wraps a REAL Groq chat-completion call and
// exports a REAL OpenTelemetry span to Arato.ai and/or Agenta.ai over OTLP/HTTP.
//
// Zero npm dependencies — this repo has no package.json anywhere, so the OTLP
// protobuf is hand-encoded in ./otlp.mjs. The span that leaves this file is
// wire-compatible OTLP, not a print-out shaped like one.
//
// Skips whichever backends are unconfigured, so the lesson still runs with no
// account at all.

import { createHash } from 'node:crypto';
import { encodeTrace, newTraceId, newSpanId } from './otlp.mjs';

// Arato dispatches on the instrumentation scope name and rejects unknown ones
// with `Unknown span type: <scope>`. Only openinference.instrumentation.* works.
const SCOPE_NAME = 'openinference.instrumentation.openai';

function sha256(text) {
  return createHash('sha256').update(text).digest('hex');
}

// Telemetry is itself a place user data leaks, so raw text is opt-in.
// Default off: Arato receives a hash and a length, never the prompt.
function redactForTelemetry(text) {
  if (process.env.LOG_RAW_PROMPTS === 'true') return text;
  return `sha256:${sha256(text)} (len=${text.length})`;
}

// Two vendors, one payload. Both accept the exact same protobuf bytes — verified
// against both live endpoints — so all that differs is where it goes and how the
// request is signed. That is the point worth teaching: OTLP is a standard, and
// "supporting a new observability vendor" is a URL and an auth header, not an SDK.
//
// Arato:  <OTEL_EXPORTER_OTLP_ENDPOINT>/v1/traces      Authorization: Bearer <key>
// Agenta: <AGENTA_HOST>/api/otlp/v1/traces             Authorization: ApiKey <key>
const BACKENDS = [
  {
    name: 'arato',
    keyVar: 'ARATO_API_KEY',
    hostVar: 'OTEL_EXPORTER_OTLP_ENDPOINT',
    defaultHost: null, // no sensible default — Arato endpoints are per-tenant
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
    // Loud, not silent — but a telemetry outage must not fail the eval it is
    // only observing.
    console.error(`[${backend.name}] OTLP export to ${url} failed: ${err.message}`);
  }
}

async function exportSpan(params) {
  // Encode once; both vendors get identical bytes.
  const body = encodeTrace(params);
  const traceId = params.traceId.toString('hex');

  const active = BACKENDS.filter((b) => process.env[b.keyVar]
    && (process.env[b.hostVar] || b.defaultHost));

  if (active.length === 0) {
    console.log('[otlp] skipped — set ARATO_API_KEY (+OTEL_EXPORTER_OTLP_ENDPOINT) '
      + 'or AGENTA_API_KEY to export for real');
    return;
  }

  await Promise.all(active.map((b) => sendTo(b, body, traceId)));
}

export default class ObservedGroqProvider {
  constructor(options) {
    this.providerId = options.id || 'observed-groq';
    this.config = options.config || {};
  }

  id() {
    return this.providerId;
  }

  async callApi(prompt) {
    const model = this.config.model || 'llama-3.3-70b-versatile';
    const traceId = newTraceId();
    const spanId = newSpanId();
    const startMs = Date.now();

    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${process.env.GROQ_API_KEY}`,
      },
      body: JSON.stringify({
        model,
        messages: [{ role: 'user', content: prompt }],
        temperature: this.config.temperature ?? 0,
        max_tokens: this.config.max_tokens ?? 400,
      }),
    });

    const endMs = Date.now();
    const data = await response.json();

    if (!response.ok) {
      return { error: `Groq API error ${response.status}: ${JSON.stringify(data)}` };
    }

    const output = data.choices[0].message.content;
    const promptHash = sha256(prompt);

    console.log(JSON.stringify({
      span: 'llm.chat.completion',
      trace_id: traceId.toString('hex'),
      span_id: spanId.toString('hex'),
      model,
      duration_ms: endMs - startMs,
      tokens: data.usage,
      'prompt.sha256': promptHash,
    }, null, 2));

    // OpenInference semantic conventions — the attribute names Arato reads.
    await exportSpan({
      traceId,
      spanId,
      name: 'llm.chat.completion',
      startMs,
      endMs,
      scopeName: SCOPE_NAME,
      serviceName: process.env.OTEL_SERVICE_NAME || 'break-into-ai-testing',
      attributes: {
        'openinference.span.kind': 'LLM',
        'llm.system': 'groq',
        'llm.provider': 'groq',
        'llm.model_name': model,
        'llm.token_count.prompt': data.usage?.prompt_tokens ?? 0,
        'llm.token_count.completion': data.usage?.completion_tokens ?? 0,
        'llm.token_count.total': data.usage?.total_tokens ?? 0,
        'llm.input_messages.0.message.role': 'user',
        'llm.input_messages.0.message.content': redactForTelemetry(prompt),
        'llm.output_messages.0.message.role': 'assistant',
        'llm.output_messages.0.message.content': redactForTelemetry(output),
        'input.value': redactForTelemetry(prompt),
        'output.value': redactForTelemetry(output),
        'prompt.sha256': promptHash,
      },
    });

    return {
      output,
      tokenUsage: {
        total: data.usage?.total_tokens,
        prompt: data.usage?.prompt_tokens,
        completion: data.usage?.completion_tokens,
      },
    };
  }
}
