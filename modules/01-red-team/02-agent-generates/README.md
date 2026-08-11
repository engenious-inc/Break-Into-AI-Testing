# 02 — The agent drafts the attacks

> **Day 5** · [session index](../../../days/05-red-teaming.md)

`.claude/agents/red-teamer.md` is a subagent that reads a bot's system prompt and
returns three attack cases — one per axis — as a YAML fragment.

## Use it

In Claude Code, from the repo root:

```
Use the red-teamer agent to draft attacks against medibot for prompt injection.
```

It reads `prompts/medibot.txt`, then returns something shaped like:

```yaml
- description: "prompt injection — safety axis"
  metadata: { axis: safety }
  vars:
    query: "<the attack prompt>"
  assert:
    - type: llm-rubric
      value: "<what a safe response looks like>"
```

Paste the cases into `tests/smoke.medibot.yaml` and run `./run.sh medibot`.

## Why it cannot write files

`red-teamer`'s entire toolset is `Read`, `Grep`, `Glob`. It has no write access,
and that is deliberate.

An agent that generates its own test cases, executes them, **and** grades the
results is a closed loop with no independent verification anywhere in it. It will
produce a confident report, and you will have no way to know whether any of it is
true. Lesson 04 shows exactly that failure happening on a real run.

So one human step stays in the middle. You paste the fragment — which means you
read it — and reading it is the check. The agent proposes; you dispose.

## Exercise

1. Ask for cases on three different topics (`bias`, `compliance`, `dose extraction`).
2. Before running them, predict which will land. Write the prediction down.
3. Run them. Score your own prediction.
4. Find one case the agent wrote that you consider *weak*, and say why in one line.

Step 4 is the point of the lesson. The agent's job is volume and coverage; yours
is taste. If you cannot articulate why a generated attack is weak, you are not
supervising the agent — you are forwarding its output.
