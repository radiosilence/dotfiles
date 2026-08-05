# wt-herdr

[herdr](https://herdr.dev) backend for `wt-core`. Opens worktrees as herdr
workspaces, and checks out PRs into them.

## Why not herdr's own worktree management

herdr's `[worktrees] directory` is a single global root — no `{org}` placeholder,
no per-repo layout — and defaults to `~/.herdr/worktrees`. If you scope
environment per directory, worktrees created there fall outside it and silently
pick up the wrong config. `wt-core` derives paths from the repo, so they land in
the right tree.

herdr still associates them correctly: it groups workspaces by the main repo's
`.git` path, resolved from the checkout, so worktrees created at any path nest
under their repo in the sidebar.

## Install (sheldon)

Requires `wt-core`. Load order doesn't matter — zsh resolves function bodies at
call time.

```toml
[plugins.wt-core]
local = "~/.dotfiles/zsh-plugins/wt-core"

[plugins.wt-herdr]
local = "~/.dotfiles/zsh-plugins/wt-herdr"
```

## Commands

| Command | Does |
| --- | --- |
| `wth [-b] <name> [base]` | upsert worktree, open as a herdr workspace. No args: fzf picker |
| `wtpr <n\|url\|owner/repo#n>` | check out a PR's branch into a worktree and open it |
| `wti <n\|url\|owner/repo#n>` | worktree for a GitHub issue, named `<n>-<slug>`, with claude primed on `/ticket <n>` |

`wtpr` takes a PR number (repo from `$PWD`), a full URL, or `owner/repo#n`. URLs
resolve the local checkout themselves, so it works from anywhere — the GitHub
owner is matched against directory names under `~/workspace`. Fetches via
`refs/pull/N/head`, so fork PRs work without the branch existing on origin.

## herdr popup bindings

```toml
[[keys.command]]
key = "alt+w"
type = "popup"
command = "zsh -ic 'wth'"
description = "worktree picker"

[[keys.command]]
key = "alt+shift+p"
type = "popup"
command = "zsh -ic 'wtpr-pick'"
description = "PR picker"

[[keys.command]]
key = "alt+i"
type = "popup"
command = "zsh -ic 'wti-pick'"
description = "issue picker"
```

`wti` primes the new pane by way of `herdr pane send-text`. `claude <prompt>`
starts an **interactive** session — `-p`/`--print` is what makes it batch — so
the agent comes up live with the skill already invoked.

Popups close the moment the command returns, so a wrapper that holds the window
open on failure is worth having — otherwise errors flash past unseen.

## Gotcha

`herdr worktree open` requires `--cwd` to be the **main checkout**; a linked
worktree is rejected with `linked_worktree_source`. It also reports errors as
JSON with **exit code 0**, so the payload must be inspected rather than the exit
status — otherwise failures are silent.
