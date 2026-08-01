// Custom Promptfoo provider that wraps a REAL Groq chat-completion call with
// hand-rolled OTel-shaped tracing (console output, no SDK — this repo has no
// package.json anywhere) and a REAL Arato.ai REST log call (skipped
// gracefully if ARATO_API_URL/ARATO_API_KEY aren't set). Zero npm
// dependencies: only Node builtins (fetch, node:crypto).

import { randomBytes, createHash } from 'node:crypto';

function hex(bytes) {
  return randomBytes(bytes).toString('hex');
}

async function logToArato(entry) {
  const url = process.env.ARATO_API_URL;
  const key = process.env.ARATO_API_KEY;
  if (!url || !key) {
    console.log('[arato] skipped — ARATO_API_URL/ARATO_API_KEY not set');
    return;
  }
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
      body: JSON.stringify(entry),
    });
    console.log(`[arato] POST ${url} -> ${res.status}`);
  } catch (err) {
    console.log(`[arato] request failed: ${err.message}`);
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
    const promptHash = createHash('sha256').update(prompt).digest('hex');

    console.log(JSON.stringify({
      span: 'llm.chat.completion',
      trace_id: traceId,
      span_id: spanId,
      model,
      duration_ms: durationMs,
      tokens: data.usage,
      'prompt.sha256': promptHash,
    }, null, 2));

    await logToArato({
      model,
      tokenUsage: data.usage,
      latencyMs: durationMs,
      traceId,
      spanId,
      promptHash,
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
