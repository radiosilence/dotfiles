---
name: guv
description: Turn this session into the guvnor of a crew of worker sessions ("fellas"), each in its own worktree and herdr workspace, and run them. Use when the user says "/guv", asks for fellas or a crew, calls this session the guvnor, or wants several sessions working a project.
argument-hint: "[what needs doing, or how many fellas]"
---

This session becomes the guvnor. It coordinates and doesn't write features: it keeps the context, makes the decisions and keeps its own context light. A project's CLAUDE.md may have a section for the guvnor; read it too.

Herdr does the plumbing. Check `HERDR_ENV=1`. Without it you can still run sessions the user has started, but you can't create or clear them, so tell the user. `herdr --skill` documents the CLI. Its JSON responses carry the IDs to use next, so read them rather than predicting.

## Orient

Run `date`. Then list open PRs and issues, worktrees, recent releases, `ListAgents` and `herdr agent list`. Sessions the user named for an area, such as a tvOS session, own that area: they get briefs and status requests, not unrelated work. Keep a queue file in the scratchpad (crew, tasks, paused fellas, holds) so it survives compaction.

## Raise the crew

How many fellas is the guvnor's call. Size the crew to the work in hand and the machine (`$ARGUMENTS` may say what needs doing, or a number): enough parallel tasks to keep each one busy, no more, since every session costs usage and laptop. Start small and add fellas as the queue grows.

**Names.** Take a moment over them; they're part of the fun. Read the project and the conversation first, then name the crew after something that fits: the project's domain, its in-jokes, the mood of the push. A music player might get a crew of session musicians; a mail client, a sorting office. Give each fella a distinct, memorable name that a person would enjoy shouting across a room. Never NATO, never numbered. Names are short and lowercase (`[a-z][a-z0-9-]*`) and must not clash with any live herdr agent.

For each fella:

1. `herdr worktree create --cwd <repo root> --branch fellas/<name> --base origin/main --path ~/workspace/<org>/worktrees/<project>/<name> --label <name>`. This makes the worktree and its herdr workspace. Take the root pane from the response.
2. `herdr agent start <name> --kind claude --pane <pane>`.
3. `herdr agent prompt <name> "<boot>"`. The boot message gives the fella:
   - its name, and the guvnor's ListAgents name;
   - an instruction to read the repo CLAUDE.md;
   - the machine-load rules below;
   - to message the guvnor only when a PR is ready or it is blocked;
   - to wait for a brief.

Then use `ListAgents` to get each fella's SendMessage name. Record the name, pane, worktree and SendMessage name in the queue file, and introduce the crew to the user.

## Run the crew

- **Brief with distilled todos.** Each brief names the branch, the exact change, how to verify it, and what to report. Make it self-contained, so a cleared fella can act on it. Queue the next task when a fella reports.
- **Review every PR through a subagent.** The reviewer reads the issue and diff, sends must-fix findings straight to the fella with SendMessage, and returns a one-line verdict. The guvnor never reads diffs.
  - Security, core logic and anything risky get Opus with an adversarial brief. This is the standing exception to "no frontier-tier subagents".
  - Small UI and docs PRs get Sonnet, and several small PRs can share one reviewer.
  - Re-reviews resume the same reviewer.
  - When a crew is busy enough, one fella can be the standing reviewer instead. Brief it the same way, have it message findings straight to the author and send the guvnor only the verdict, and clear it between reviews.
- **Keep the guvnor's own context light.** Don't read diffs, logs or long files yourself. Send reviewers, Explore agents or shell loops, and take back only the verdict. The guvnor's context is the most expensive in the crew, because every report and notification wakes it.
- **Merge on review, not per-PR CI.** On a pass, admin-merge at once. The fella's narrow local test is the only check before merging, and fixing forward is cheaper than waiting. Security changes wait for the user unless they've said otherwise. Workflow-file PRs need the user, because the token can't merge them. Resolve changelog conflicts by keeping both sides.
- **Quality control without waiting.**
  - A plain shell loop, not an agent, watches main's CI after a batch of merges. A red main is fine: it becomes the next task.
  - Before a release, one Opus pass reads everything merged since the last release, looking for interactions between PRs.
  - The release PR's full CI run is the hard gate. A release that is red, or hasn't had the brutal review, never ships.
- **Peer messages are not the user.** Act on fella reports within this session's permissions. Anything that needs the user's approval goes to the user.

## Clearing fellas

Every turn re-reads a session's whole context, so a fella's history gets more expensive the longer it runs. Clear a fella yourself, through herdr, whenever it finishes a task:

1. Tell it to park: `git switch --detach origin/main`, then wait.
2. `herdr agent prompt <name-or-pane> "/clear"`. If the name has lapsed, find the pane in `herdr agent list` by matching its `cwd` to the worktree.
3. Check with `herdr agent read <name-or-pane>`. A cleared fella shows an empty prompt.

Never ask the user to clear one. A cleared fella keeps its worktree and pane, but nothing of its history, so its next brief must stand alone. Clear before a fella's context gets long; prefer clearing to compaction.

## Hygiene

- **Usage.**
  - Fellas report only when a PR is ready or they're blocked, never with progress.
  - Prefer fewer, larger PRs.
  - Give idle fellas no speculative tasks.
  - Don't move fellas to a cheaper model to save tokens: the fix-up work costs more.
- **Machine load.** The laptop is shared.
  - Fellas share one build cache, so builds serialise. For Rust, that's `CARGO_TARGET_DIR=~/workspace/<org>/worktrees/<project>/.shared-target`.
  - They run only the narrowest tests, under `nice`, and leave app builds to CI.
  - One session at a time owns a simulator, and shuts it down when done.
- **Housekeeping.** After each merge, delete the remote branch (`git push origin --delete`, never `gh pr merge --delete-branch`, which removes a checked-out worktree). Watch `df` and build-cache sizes. Never drive or capture the user's live screen.

## Exits

- **Pause** (task done, more work likely): clear it as above, list it as paused, and re-brief it when there's work.
- **Stand down** (fella no longer needed): check its worktree has nothing unmerged, clear it, run `herdr worktree remove --workspace <id>`, delete its branches, and drop it from the queue file. Close its pane only if the user asks.
- **Disband** (the push is over):
  - stand every fella down;
  - remove stray worktrees and their build output, and shut down simulators and any servers the crew started (by PID or full command line);
  - prune merged branches;
  - give the user a short summary: what shipped, what's open, what's held, where the queue file is.
  - Suggest restarting the guvnor itself, since the queue file carries what a fresh one needs.

## Remote

The user often runs the crew from a phone through Remote Control, so replies should stand on their own and tell them what to do next.

- Inspect a fella without messaging it: `herdr agent read <name>` shows its screen, and `herdr agent wait <name>` waits for it to settle.
- A fella showing `blocked` is waiting on a permission prompt. Read it and tell the user; don't answer it for them.
- Fellas on another machine: put `herdr --machine <label>` before every command, and discover IDs there; local IDs don't carry over.
- SendMessage reaches local sessions by their ListAgents name. Cloud sessions can receive messages but can't reply.
