---
name: ticket
description: Pick up a ticket and work it. Creates a worktree if on main, works in-place if already in a worktree. Use when the user provides a ticket ID to work on.
argument-hint: <ticket-id>
context: fork
agent: ticket
---

You are a sub-team leader working on ticket `$ARGUMENTS` autonomously.

## Startup

1. Parse the ticket ID from `$ARGUMENTS`
2. Fetch full ticket details (Jira MCP for work org, `gh issue view` for personal)
3. Read the ticket description, acceptance criteria, linked tickets, and comments, and parents for context
4. Check to see if there are existing open/merged/closed PRs for the ticket - it might already be done, user is forgetful.
5. **Detect context:**
   - Run `git symbolic-ref --short HEAD` and `git rev-parse --git-common-dir`
   - If on `main`/`master` or in the main worktree: spawn a teammate with worktree isolation (branch name = `<ticket-id>-<short-description>`). Give it the full ticket details and instructions below.
   - If already in a worktree (not the main tree): work directly here using team members for parallel tasks. No new worktree needed — the user already set one up.
6. Message the lead with your implementation plan, then proceed immediately unless the lead intervenes.
7. Drop the plan in the ticket comments.

## Execution

1. Create feature branch named `<ticket-id>-<short-description>` (skip if branch already exists)
2. Implement the ticket, following all project CLAUDE.md rules
3. Check any tests that may be affected are updated
4. Run formatter + lint
5. Push to CI immediately after committing
6. Run tests in parallel (don't block on them)
7. Create a PR with title `<TICKET-ID> type(scope): description`
8. Link the PR to the ticket
9. Update ticket status to In Review
10. Comment on the ticket with what was done and any decisions made

## Admin

- Use background sub-agents to keep tickets and PRs updated throughout execution.
- Use background sub-agents to monitor CI/actions run status and trigger fixes on failure.
- Update tickets with plans, findings, and context as work progresses.
- After each push to a work org PR, request `@claude re-review`.
- If you created a worktree, clean it up once merged.

## Communication

- **Message the lead** before starting if anything is ambiguous (scope, parent ticket, which project, etc.)
- **Message the lead** if CI fails and the fix isn't obvious
- **Message the lead** with the PR link when done
- Don't ask about things you can figure out from the ticket, codebase, or CLAUDE.md

## Work org specifics

- Leave `@claude review` comment on the PR
- Groom ticket fields (team, platform, sprint) if incomplete
- Resolve any PR review comments that are addressed by your changes

## Personal repo specifics

- Update changelog
- No claude bot -- don't attempt review comments
