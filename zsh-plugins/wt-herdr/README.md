# wt-herdr

[Herdr](https://herdr.dev) app backend for `wt-core`. Opens each worktree as a
Herdr space, and checks out PRs and issues into them.

## Why not Herdr's own worktree management

Herdr's worktree actions keep checkouts under a single global root,
`~/.herdr/worktrees`, with no per-org layout. If you scope environment per
directory, worktrees created there fall outside it and silently pick up the
wrong config. `wt-core` derives paths from the repo, so they land in the right
tree. The spaces sidebar still nests each worktree's space under its main
checkout's, because it groups spaces by the repo's `.git` directory.

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
| `wth [-b] <name> [base]` | upsert worktree, open as a Herdr space. No args: fzf picker |
| `wtpr <n\|url\|owner/repo#n>` | PR **or** issue — a URL disambiguates, a bare number is probed |
| `wti <n\|url\|owner/repo#n>` | worktree for a GitHub issue, named `<n>-<slug>`, with claude primed with "Work issue #<n>" |
| `wtpr-space <ref> <file>` | `wtpr` for programs: primes nothing and writes the space id to `<file>` (on failure, the reason to `<file>.log`) |

The logic lives in `wt-core`; these are bindings of `_wt_pr` / `_wt_issue` to
the Herdr backend, so the zellij backend has the same set. A worktree that
already has a space is selected rather than opened again.

`wtpr` is the single entry point for both. A URL disambiguates itself (`/pull/` vs `/issues/`); a bare number is ambiguous because GitHub numbers PRs and issues from one sequence, so it probes with `gh pr view` and falls through to `wti` when that fails. A `/pull/` URL never falls through: if the probe fails, `wtpr` reports the error.

It takes a number (repo from `$PWD`), a full URL, or `owner/repo#n`. URLs
resolve the local checkout themselves, so it works from anywhere — the GitHub
owner is matched against directory names under `~/workspace`. Fetches via
`refs/pull/N/head`, so fork PRs work without the branch existing on origin.

`wtpr-space` exists for programs that start their own agent in the worktree's space with `tab.new` and needs that space's id. Matching spaces by branch is unreliable (two repos can share a branch name, and the main checkout can be on it), so the id comes from the backend that selected or created the space. On failure no file is written, and wt-core's output is left in `<file>.log`.

`wti` primes a new space by typing `claude "Work issue #<n>"` into its terminal
with `hc send`. `wt-core` calls the backend in a subshell, so the new terminal's
address reaches the priming step through `$TMPDIR/wt-herdr.<pid>`.

## Popups

The picker wrappers (`wtpr-pick`, `wth-pick`, `wti-pick`) live in
`config.d/zsh/conf.d/herdr.zsh`. The `popup-pr` and `popup-worktree` mods in
`config.d/herdr-app/mods` run them in a dialog, bound to `alt-shift-p` and
`alt-w`. The dialog closes when the command returns, so the wrappers hold it
open on failure; otherwise errors flash past unseen.
