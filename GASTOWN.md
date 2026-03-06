# Gastown

Multi-agent workspace orchestrator: a Mayor AI coordinates Polecat worker agents across git worktrees, with Dolt for persistent state and Beads for git-backed issues.

## Prerequisites

These are handled by the dotfiles (mise-managed):

- `gt` — gastown CLI (`github:steveyegge/gastown`)
- `bd` — beads CLI (`github:steveyegge/beads`)
- `dolt` — git-for-data DB backend (`github:dolthub/dolt`)
- `tmux` — required for Polecat workers

You need to supply your own AI credentials (e.g. `ANTHROPIC_API_KEY`).

## Quick Start

```sh
gt install ~/gt --git          # bootstrap a gastown workspace
cd ~/gt
gt rig add myproject ~/workspace/myproject  # attach a project
gt mayor attach                # start the Mayor (interactive AI coordinator)
```

Then talk to the Mayor: "build a REST endpoint for user auth" — it decomposes the work, spawns Polecats, and coordinates.

## Key Concepts

- **Mayor** — AI coordinator. Receives goals, plans Convoys, delegates to Polecats. Lives in a dedicated tmux pane.
- **Rigs** — project wrappers. A Rig points at a git repo and holds the Dolt DB, Hooks, and config for that project.
- **Polecats** — ephemeral worker agents. Each runs in its own tmux pane with a git worktree. Spawned per-task, die when done.
- **Hooks** — persistent state stored in git worktrees. How Polecats hand off context without shared memory.
- **Convoys** — batches of work. A Convoy is a set of tasks the Mayor schedules and tracks to completion.
- **Beads** — git-backed issues (`bd` CLI). Replaces GitHub Issues for offline/local-first tracking. Issues live in the repo.

## Workflows

**Mayor-driven (default):**
```sh
gt mayor attach
# > "add pagination to the user list endpoint"
# Mayor creates a Convoy, spawns Polecats, reports when done
```

**Manual Convoy:**
```sh
gt convoy create "refactor auth module"
gt convoy task add "extract token validation"
gt convoy task add "write tests"
gt convoy run
```

**Beads (issue tracking):**
```sh
bd new "fix race condition in worker pool"
bd list
bd close 3
```

## Claude Code Integration

`mise run link` auto-injects a global `PostToolUse` hook (`hooks/gastown-file-changed.sh`) into `~/.claude/settings.json`. It fires `gt hook fire file-changed` on every Write/Edit, but is a no-op outside gastown rigs — so it's safe to have globally.

This lets the Mayor observe file changes made by Claude Code sessions and coordinate across agents without per-project config.

## Notes

- Dolt DB lives at `~/gt/.dolt/` — back it up like a git repo (`dolt push`).
- Each Polecat gets an isolated worktree; merges are the Mayor's job.
- `gt status` gives a live view of active Polecats and Convoy progress.
