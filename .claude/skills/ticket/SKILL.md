---
name: ticket
description: Pick up a ticket and work it in the current worktree. Use when the user provides a ticket ID to work on.
argument-hint: <ticket-id>
model: opus
---

You are a team lead working a ticket. Orchestrate from the foreground; delegate aggressively to parallel team members for anything that can run alongside your critical path. You own implementation. The more you parallelise, the better.

## Rule: every `Task` spawn declares `model:` explicitly

Never rely on parent inheritance — that is how Opus bills compound. Each spawn block below tags the model; copy the tag into the `Task` call. Tier reference (full version in `~/.claude/CLAUDE.md`):

- **Haiku** — I/O, polling, CLI/API calls, lint, tests, ticket field grooming, babysitter loops
- **Sonnet** — codebase research, pattern lookups, structured summaries
- **Opus** — cross-file synthesis, ambiguous design, judgement calls

## Input

`$ARGUMENTS` = ticket ID/URL plus optional user context (hints, scope notes, constraints). Parse the ID; pass the rest verbatim to research team members and factor it into your plan.

## Phase 0: Orient

Run `bash ~/.claude/skills/ticket/scripts/orient.sh` — one shot for cwd, branch, repo root, commits since `main`, working-tree status, and any existing PR for the current branch.

Then:

- If on `main`: stop, tell the lead to create a worktree first.
- If commits exist on this branch OR a PR already exists: read the PR description and existing commits before planning. You may be resuming.

## Phase 1: Research (parallel)

Spawn all three in a single message:

> **Task** · `model: "haiku"` — Fetch full ticket details (Jira/GitHub): description, acceptance criteria, parents, linked tickets, comments. Return a structured summary.

> **Task** · `model: "haiku"` — Search for existing open/merged/closed PRs for this ticket — it might already be done.

> **Task** · `model: "sonnet"` — Research the codebase: find relevant files, understand the domain, identify what needs to change, map dependencies. Return findings + proposed plan (approach, files to change, risks, open questions). Escalate to `model: "opus"` only if the codebase is unfamiliar to you.

While they run, create branch `<ticket-id>-<short-description>` if it doesn't exist.

When all three return, synthesise. Message the lead with a one-paragraph summary, then proceed unless they intervene.

## Phase 2: Implement

You do the implementation. Follow project CLAUDE.md rules. Alongside your work, parallelise the supporting tasks:

> **Task** · `model: "haiku"` — Run formatter + lint on changed files. Report errors only.

> **Task** · `model: "sonnet"` — Check whether existing tests need updates. Return list of tests + why.

> **Task** · `model: "sonnet"` — Pattern/example lookups in the codebase as needed.

Update affected tests. Commit and push.

## Phase 3: Draft PR

Create the draft PR immediately after first push. Title: `<TICKET-ID> type(scope): description`.

Then spawn in parallel:

> **Task** · `model: "haiku"` — Link the PR to the ticket. Transition ticket status to In Progress.

> **Task** · `model: "haiku"` — Run tests locally. Report failures.

> **Task** · `model: "haiku"` · `run_in_background: true` · `mode: "bypassPermissions"` — Invoke the `babysit` skill on this PR (see "Babysitter delegation" below). Long-lived.

Fix any test failures and re-push.

## Phase 4: Validate

When implementation is complete and tests pass:

- Mark PR ready for review
- Request `@claude review` (work org only)
- Transition ticket to In Review
- Comment on the ticket: what was done, key decisions, anything the reviewer should know
- Message the lead with the PR link

## Babysitter delegation

Do **not** inline a babysitter here — delegate to the dedicated `babysit` skill (fresha-tools / feature-workflow plugin). It is the source of truth for PR shepherding.

> **Task** · `model: "haiku"` · `run_in_background: true` · `mode: "bypassPermissions"`
> Prompt: `Invoke /babysit <pr-url>. Stay alive for the rest of the session.`

The babysit skill handles: CI watching, `@claude re-review` requests, ticket status sync, auto-merging codegen / buf / quarantine-test / lint PRs (never visual-test), and the PR review-comment fix loop. It does **not** merge the main PR — only the lead does that.

If you ever want to escalate the babysitter off Haiku, you are trying to make it do real work. Spin a separate short-lived Sonnet/Opus team member for that and keep the babysitter dumb.

## Communication

- Message the lead before starting if anything is ambiguous (scope, parent ticket, project)
- Message the lead if CI fails and the fix isn't obvious
- Message the lead with the PR link when done
- Do not ask about things derivable from the ticket, the codebase, or CLAUDE.md

## Org specifics

**Work:** `@claude review` on first ready-for-review, `@claude re-review` after subsequent pushes. Groom ticket fields (team, platform, sprint) if incomplete. Resolve PR comments addressed by your changes.

**Personal:** Update changelog. No claude bot — skip review-comment requests.
