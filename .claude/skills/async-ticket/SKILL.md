---
name: async-ticket
description: Fire-and-forget ticket work. Creates a worktree and runs /ticket in it as a background subagent. Use when the user wants to kick off a ticket without blocking their current session.
argument-hint: <ticket-id>
---

Spawn a single subagent with worktree isolation to work on a ticket.

## Input

`$ARGUMENTS` contains the ticket ID/URL and optionally additional context from the user (e.g. hints, constraints, scope notes). Parse out the ticket ID/URL — pass the **entire** `$ARGUMENTS` string through to the /ticket skill so it gets both the ID and the user's context.

## Steps

1. Extract the ticket ID from `$ARGUMENTS`
2. Derive a branch name: `<ticket-id>-wip` (the /ticket skill will refine it after reading the ticket)
3. Spawn one agent with:
   - `isolation: "worktree"` 
   - `run_in_background: true`
   - Prompt: run `/ticket $ARGUMENTS` — pass the FULL arguments through, not just the ID
4. Tell the lead the agent is running and which worktree it's in
5. You're done. Don't wait, don't poll. The ticket agent handles everything from here.

## Rules

- ONE agent, ONE worktree. Don't spawn multiple.
- Don't fetch the ticket yourself — let the /ticket skill handle it.
- Don't do any implementation — that's the ticket agent's job.
- If the ticket ID looks malformed or missing, ask the lead before spawning.
