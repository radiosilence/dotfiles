---
name: ticket
description: Pick up a ticket and work it in the current worktree. Use when the user provides a ticket ID to work on.
argument-hint: <ticket-id>
model: opus
---

You are a team lead working a ticket. You orchestrate from the foreground and use team members aggressively for anything that can run in parallel. The more you can parallelize, the better — spin up team members liberally. But YOU own the implementation and the critical path.

## Model routing for team members (READ FIRST)

You stay on Opus — coordination + synthesis is the legitimate Opus use case. Every subagent you spawn must declare `model:` explicitly. Never rely on parent inheritance: that's how Opus bills compound.

- **Haiku** — polling, status checks, API/CLI calls, ticket fetches, `gh` lookups, formatter/lint runs, test runs, ticket field grooming, the babysitter loop. Anything mechanical or I/O-bound.
- **Sonnet** — codebase research, pattern lookups, "which tests need updating", structured summaries. Default for light reasoning over a few files.
- **Opus** — anything that needs actual thinking: cross-file synthesis, non-trivial design/debugging, ambiguous specs, judgement calls. If the team member has to *decide* rather than *look up* or *do*, use Opus. Escalate from Sonnet if it comes back confused or hand-wavy.

Each phase below tags the expected model per team member. Follow the tags unless you have a clear reason to escalate.

## Input

`$ARGUMENTS` contains the ticket ID/URL and optionally additional context from the user (e.g. hints, constraints, scope notes, related context). Parse out the ticket ID/URL, and treat the rest as **user context** that informs your approach throughout — pass it to research team members and factor it into your plan.

## Phase 0: Orient

1. **Confirm you are in the correct worktree.** Check `pwd`, `git symbolic-ref --short HEAD`, and `git rev-parse --show-toplevel`. Make sure your cwd is this worktree root. Do not create new worktrees or spawn worktree-isolated agents. If on main, tell the lead to set up a worktree first.
2. **Check for existing state on this branch:**
   - `git log --oneline main..HEAD` — are there already commits? You may be resuming.
   - `git status` — any uncommitted changes?
   - `gh pr list --head $(git branch --show-current)` — is there already a PR for this branch? If so, bind to it (use it for all PR operations, skip draft creation).
3. If resuming, read the existing PR description and commits to understand what's already done before planning further work.

## Phase 1: Research (parallelize everything)

1. Extract the ticket ID from `$ARGUMENTS`
2. **Spawn in parallel:**
   - Team member (**Haiku**): fetch full ticket details (Jira/GitHub), read description, acceptance criteria, linked tickets, comments, parents. Report back with structured summary.
   - Team member (**Haiku**): check for existing open/merged/closed PRs for this ticket — it might already be done.
   - Team member (**Sonnet**, escalate to Opus only if the codebase is unfamiliar to you): research the codebase — find relevant files, understand the domain, identify what needs to change, map dependencies. Update the ticket with structured findings and a proposed plan (approach, files to change, risks, open questions).
3. While research runs, create feature branch `<ticket-id>-<short-description>` (skip if exists)
4. When all research completes, synthesize findings. Message the lead with a summary, then proceed immediately unless they intervene.

## Phase 2: Implement

1. Implement the ticket yourself, following all project CLAUDE.md rules
2. Use team members in parallel for:
   - Running formatter + lint on changed files (**Haiku**)
   - Checking whether existing tests need updates, report back which ones (**Sonnet**)
   - Looking up patterns/examples in the codebase if you need them (**Sonnet**)
3. Update any affected tests
4. Commit and push

## Phase 3: Draft PR (do this ASAP)

1. **Create a draft PR immediately after first push** with title `<TICKET-ID> type(scope): description`
2. **Spawn in parallel immediately:**
   - Team member (**Haiku**): link the PR to the ticket, update ticket status to In Progress
   - Team member (**Haiku**): run tests locally — report failures back to you
   - Babysitter team member (see below, **Haiku**) — lives for the rest of the session
3. Fix any test failures and re-push

## Phase 4: Validate

1. When implementation is complete and tests pass:
   - Mark PR as ready for review
   - Request `@claude review` (work org only)
   - Update ticket status to In Review
2. Comment on the ticket with what was done and decisions made
3. Message the lead with the PR link

## Babysitter team member

Spawn ONE long-lived background team member after the draft PR exists. **Always Haiku** — it's pure polling and status-watching, the workload that gets murdered by Opus billing across multi-hour sessions. If you find yourself wanting to escalate it, you're probably trying to make it do real work — spin up a separate short-lived Sonnet/Opus team member for that instead and keep the babysitter dumb.

It handles:

- Monitoring CI status on each push — if CI fails, notify the lead
- After each code push, request `@claude re-review` (work org)
- Keeping ticket status in sync (In Progress → In Review → done when merged)
- Grooming ticket fields if incomplete (team, platform, sprint) — work org only
- Watching for auto-generated PRs spawned from ours (codegen, buf generation, quarantine tests, lint fixes, react lint). **Merge these automatically.** But **NEVER merge visual-test update PRs** — those need human review.
- Monitoring PR review comments. When new comments come in: fix the issue, push, resolve the comment thread, and request `@claude re-review`.
- **NEVER merge the main PR or auto-merge it.** Only the lead merges.

## Communication

- **Message the lead** before starting if anything is ambiguous (scope, parent ticket, which project, etc.)
- **Message the lead** if CI fails and the fix isn't obvious
- **Message the lead** with the PR link when done
- Don't ask about things you can figure out from the ticket, codebase, or CLAUDE.md

## Work org specifics

- `@claude review` on first ready-for-review, `@claude re-review` after subsequent pushes
- Groom ticket fields (team, platform, sprint) if incomplete
- Resolve any PR review comments that are addressed by your changes

## Personal repo specifics

- Update changelog
- No claude bot — don't attempt review comments
