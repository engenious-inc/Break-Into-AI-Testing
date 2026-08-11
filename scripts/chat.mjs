#!/usr/bin/env node
/**
 * Talk to one of the workshop bots, seeing only what a user would see.
 *
 * Day 6 is black-box testing: you infer the rules from behaviour. So this prints the
 * assistant's reply and nothing else — no system prompt, no model, no token counts. The
 * prompt file is in the repo and you could read it in ten seconds; the exercise is worth
 * more if you do not.
 *
 *   ./run.sh chat onboardbot        /reset  clears the conversation
 *                                   /save <file>  writes the transcript
 *                                   Ctrl-D or /quit to leave
 */
import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';

const MODEL = process.env.CHAT_MODEL || 'llama-3.3-70b-versatile';
const BASE = process.env.GROQ_API_BASE || 'https://api.groq.com/openai/v1';

// Deliberately NOT 0. Every other config in this repo pins temperature to 0 for
// reproducible evals. Day 6 asks students to send the same question ten times and
// describe the variance — at temperature 0 there is no variance and that exercise
// silently becomes impossible. Do not "fix" this.
const TEMPERATURE = 0.7;

const bot = process.argv[2];
if (!bot) {
  console.error('usage: ./run.sh chat <bot>   (onboardbot, medibot, financebot, mybot)');
  process.exit(2);
}

const promptFile = path.join(process.cwd(), 'prompts', `${bot}.txt`);
if (!fs.existsSync(promptFile)) {
  console.error(`No prompt file for "${bot}" — expected ${promptFile}`);
  const avail = fs.readdirSync(path.join(process.cwd(), 'prompts'))
    .filter((f) => f.endsWith('.txt')).map((f) => f.replace(/\.txt$/, ''));
  console.error(`Available: ${avail.join(', ')}`);
  process.exit(2);
}

const apiKey = process.env.GROQ_API_KEY;
if (!apiKey) {
  console.error('GROQ_API_KEY is not set. Run ./setup.sh, or export it for this shell.');
  process.exit(2);
}

const parsed = JSON.parse(fs.readFileSync(promptFile, 'utf8'));
const system = parsed.find((m) => m.role === 'system')?.content;
if (!system) {
  console.error(`${promptFile} has no system message.`);
  process.exit(2);
}

let history = [];
const transcript = [];

async function send(userText) {
  const res = await fetch(`${BASE}/chat/completions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
    body: JSON.stringify({
      model: MODEL,
      temperature: TEMPERATURE,
      max_tokens: 400,
      messages: [{ role: 'system', content: system }, ...history,
                 { role: 'user', content: userText }],
    }),
  });
  const body = await res.text();
  if (!res.ok) {
    // Rate limits are the expected failure here. Say so plainly — a silent stall reads
    // as a broken bot, and students will spend the breakout debugging the wrong thing.
    throw new Error(`Groq returned ${res.status}\n${body.slice(0, 400)}`);
  }
  const reply = JSON.parse(body).choices[0].message.content.trim();
  history.push({ role: 'user', content: userText }, { role: 'assistant', content: reply });
  transcript.push(`> ${userText}`, reply, '');
  return reply;
}

const rl = readline.createInterface({ input: process.stdin, output: process.stdout,
                                      prompt: '> ' });
console.log(`${bot} ready. /reset clears context, /save <file> writes a transcript, /quit exits.\n`);
rl.prompt();

// `for await` rather than a promise-wrapped rl.question loop: this ends cleanly at EOF,
// which is what happens when the session is piped rather than typed.
for await (const raw of rl) {
  const line = raw.trim();
  if (line === '/quit') break;
  if (!line) { rl.prompt(); continue; }

  if (line === '/reset') {
    history = [];
    transcript.push('--- context reset ---', '');
    console.log('(context cleared)\n');
    rl.prompt();
    continue;
  }
  if (line.startsWith('/save')) {
    const target = line.split(/\s+/)[1] || 'transcript.txt';
    fs.writeFileSync(target, transcript.join('\n'));
    console.log(`(wrote ${transcript.length} lines to ${target})\n`);
    rl.prompt();
    continue;
  }

  try {
    console.log(`\n${await send(line)}\n`);
  } catch (err) {
    console.error(`\n${err.message}\n`);
  }
  rl.prompt();
}
rl.close();
