// Custom Promptfoo provider that wraps a REAL Groq chat-completion call with
// hand-rolled OTel-shaped tracing (console output, no SDK — this repo has no
// package.json anywhere) and REAL Arato.ai REST monitoring (skipped
// gracefully if ARATO_API_URL/ARATO_API_KEY aren't set). Zero npm
// dependencies: only Node builtins (fetch, node:crypto).
//
// The Arato payload below is not invented — it matches the shape a working
// Arato integration sends (see Jaimeman84/financial-chat-bot, lib/arato.ts).

import { randomBytes, createHash } from 'node:crypto';

function hex(bytes) {
  return randomBytes(bytes).toString('hex');
}

function sha256(text) {
  return createHash('sha256').update(text).digest('hex');
}

// Telemetry is itself a place user data leaks, so raw text is opt-in.
// Default off: Arato receives a hash and a length, never the prompt.
function redactForTelemetry(text) {
  if (process.env.LOG_RAW_PROMPTS === 'true') return text;
  return `sha256:${sha256(text)} (len=${text.length})`;
}

async function postAratoLog(entry) {
  const url = process.env.ARATO_API_URL;
  const key = process.env.ARATO_API_KEY;
  if (!url || !key) {
    console.log('[arato] skipped — ARATO_API_URL/ARATO_API_KEY not set');
    return;
  }

  // Wire field names are snake_case and differ from the camelCase we use
  // internally — send exactly what Arato expects.
  const body = {
    model: entry.model,
    id: entry.id,
    messages: entry.messages,
    response: entry.response,
    variables: entry.variables,
    usage: entry.usage,
    performance: entry.performance,
    tool_calls: null,
    arato_thread_id: entry.threadId,
    prompt_id: entry.promptId,
    prompt_version: entry.promptVersion,
    tags: entry.tags,
  };

  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
      body: JSON.stringify(body),
    });
    const detail = res.ok ? '' : ` — ${(await res.text()).slice(0, 200)}`;
    console.log(`[arato] POST ${url} -> ${res.status}${detail}`);
  } catch (err) {
    // Loud, not silent — but a telemetry outage must not fail the eval it is
    // only observing.
    console.error(`[arato] request to ${url} failed: ${err.message}`);
  }
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
    const traceId = hex(16);
    const spanId = hex(8);
    const start = Date.now();

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

    const durationMs = Date.now() - start;
    const data = await response.json();

    if (!response.ok) {
      return { error: `Groq API error ${response.status}: ${JSON.stringify(data)}` };
    }

    const output = data.choices[0].message.content;
    const promptHash = sha256(prompt);

    console.log(JSON.stringify({
      span: 'llm.chat.completion',
      trace_id: traceId,
      span_id: spanId,
      model,
      duration_ms: durationMs,
      tokens: data.usage,
      'prompt.sha256': promptHash,
    }, null, 2));

    await postAratoLog({
      model,
      id: `msg-${hex(8)}`,
      messages: [{ role: 'user', content: redactForTelemetry(prompt) }],
      response: redactForTelemetry(output),
      // trace_id/span_id here are what let you line an Arato record up against
      // the span printed above.
      variables: { trace_id: traceId, span_id: spanId, prompt_sha256: promptHash },
      usage: {
        prompt_tokens: data.usage?.prompt_tokens,
        completion_tokens: data.usage?.completion_tokens,
      },
      // This call is not streamed, so the first token and the last one arrive
      // together as far as the client can observe. TTFT is only a distinct
      // measurement when you stream.
      performance: { ttft: durationMs, ttlt: durationMs },
      threadId: null,
      promptId: 'observability-lesson',
      promptVersion: '1.0',
      tags: { environment: process.env.NODE_ENV ?? 'development', feature: 'eval' },
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
