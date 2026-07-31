# Debugger — learn by fixing
Each stage ships an intentionally-BROKEN config. Your job: make it run.
Debug workflow: read the error → check YAML indentation → check `file://` paths →
check provider IDs → check assertion types → `npx promptfoo@latest eval -c <config>`.
Each stage has a `SOLUTION.md` — try first, peek after.
- `1_basic/` — one planted bug (assertion type mismatch).
- `2_moderate/` — provider-prefix + key-name bugs.
- `3_advance/` — a `file://` path bug.
