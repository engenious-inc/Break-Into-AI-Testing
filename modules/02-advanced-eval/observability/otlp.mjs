// Minimal OTLP/protobuf trace encoder — zero dependencies, Node builtins only.
//
// This repo has no package.json anywhere, so `@opentelemetry/exporter-trace-otlp-proto`
// is not available. This encodes just enough of
// opentelemetry/proto/trace/v1/trace.proto by hand to export one or more spans.
//
// It is NOT a general protobuf library — it handles the field types this one
// message needs (bytes, string, varint, fixed64) and nothing else.

import { randomBytes } from 'node:crypto';

// Protobuf base-128 varint: 7 bits per byte, high bit = "more bytes follow".
function varint(n) {
  const out = [];
  let v = BigInt(n);
  do {
    let b = Number(v & 0x7fn);
    v >>= 7n;
    if (v) b |= 0x80;
    out.push(b);
  } while (v);
  return Buffer.from(out);
}

// Wire tag = (field_number << 3) | wire_type.
// 0 = varint, 1 = fixed64, 2 = length-delimited.
const tag = (field, wire) => varint((field << 3) | wire);
const lenDelim = (field, buf) => Buffer.concat([tag(field, 2), varint(buf.length), buf]);
const str = (field, s) => lenDelim(field, Buffer.from(s, 'utf8'));
const vint = (field, n) => Buffer.concat([tag(field, 0), varint(n)]);

function fixed64(field, n) {
  const b = Buffer.alloc(8);
  b.writeBigUInt64LE(BigInt(n));
  return Buffer.concat([tag(field, 1), b]);
}

function fixed32(field, n) {
  const b = Buffer.alloc(4);
  b.writeUInt32LE(n);
  return Buffer.concat([tag(field, 5), b]);
}

// KeyValue { key = 1; value = 2 } wrapping AnyValue { string_value = 1; int_value = 3 }
function attribute(key, value) {
  const anyValue = typeof value === 'number' ? vint(3, value) : str(1, String(value));
  return Buffer.concat([str(1, key), lenDelim(2, anyValue)]);
}

export const newTraceId = () => randomBytes(16);
export const newSpanId = () => randomBytes(8);

// Span { trace_id=1 span_id=2 parent_span_id=4 name=5 kind=6 start=7 end=8
//        attributes=9 status=15 flags=16 }
// A root span omits parent_span_id and sets flags=256 (bit 8, "context has
// is_remote") — byte-for-byte what the official SDK emits. Children set field 4
// and flags=0. kind defaults to SPAN_KIND_CLIENT (3); PayFlow's parent uses
// SPAN_KIND_SERVER (2).
function encodeOneSpan(traceId, span) {
  const attributes = Object.entries(span.attributes || {}).map(([k, v]) => lenDelim(9, attribute(k, v)));
  const parts = [
    lenDelim(1, traceId),
    lenDelim(2, span.spanId),
  ];
  if (span.parentSpanId) parts.push(lenDelim(4, span.parentSpanId));
  const kind = span.kind == null ? 3 : span.kind;
  parts.push(
    str(5, span.name),
    vint(6, kind),
    fixed64(7, BigInt(span.startMs) * 1000000n),
    fixed64(8, BigInt(span.endMs) * 1000000n),
    ...attributes,
    lenDelim(15, Buffer.alloc(0)),
    fixed32(16, span.parentSpanId ? 0 : 256),
  );
  return Buffer.concat(parts);
}

// Builds a full TracesData message. Pass a single span at the top level
// (TutorBot) or `spans: [...]` sharing one traceId (PayFlow parent + children).
//
// scopeName matters: Arato dispatches on the instrumentation scope and rejects
// anything it doesn't recognise with `Unknown span type: <scope>`. Only
// `openinference.instrumentation.*` names are accepted.
export function encodeTrace(params) {
  const items = params.spans || [{
    spanId: params.spanId,
    parentSpanId: params.parentSpanId,
    name: params.name,
    kind: params.kind,
    startMs: params.startMs,
    endMs: params.endMs,
    attributes: params.attributes,
  }];
  const encodedSpans = items.map((span) => encodeOneSpan(params.traceId, span));

  const scope = Buffer.concat([str(1, params.scopeName), str(2, '1.0')]);
  const scopeSpans = Buffer.concat([
    lenDelim(1, scope),
    ...encodedSpans.map((span) => lenDelim(2, span)),
  ]);
  const resource = Buffer.concat([
    lenDelim(1, attribute('telemetry.sdk.language', 'nodejs')),
    lenDelim(1, attribute('telemetry.sdk.name', 'opentelemetry')),
    lenDelim(1, attribute('service.name', params.serviceName)),
  ]);
  const resourceSpans = Buffer.concat([lenDelim(1, resource), lenDelim(2, scopeSpans)]);

  return lenDelim(1, resourceSpans); // TracesData { resource_spans = 1 }
}
