---
name: ticket
description: Work a GitHub issue — close it if it is already done, otherwise just do it. Use when given an issue number or URL to pick up.
argument-hint: <issue>
model: opus
---

Get it done. A few pointers:

```
bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/ticket/scripts/orient.sh" $ARGUMENTS
```

Tells you where you are, the issue, and any PR touching it.

- It may already be done. Trust the code over the issue — the issue is older. If it is, close it saying what did it, and stop.
- Branch, then PR with `Closes #<issue>`. Everything else is in CLAUDE.md.
- Ask only what neither the issue nor the code can answer.
