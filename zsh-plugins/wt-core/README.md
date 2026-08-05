# wt-core

Git worktree management for zsh. Backend-agnostic — pair it with `wt-zellij` or
`wt-herdr` to open worktrees in a multiplexer.

Worktrees are created at `<repo-parent>/worktrees/<repo>/<name>`, derived from
the repo's own location. That matters if you scope environment per directory
(mise, direnv): a worktree stays inside the same tree as its repo, so anything
scoped there still applies. Tools that use a single global worktree root cannot
express this.

## Install (sheldon)

```toml
[plugins.wt-core]
local = "~/.dotfiles/zsh-plugins/wt-core"
```

## Commands

| Command | Does |
| --- | --- |
| `wt [-b] <name> [base]` | upsert worktree, `cd` into it. No args: fzf picker |
| `wtd <name>` | remove worktree and its branch |
| `wtrm [name]` | remove the worktree you're in (or a named one) |
| `wtclean` | remove clean worktrees, force-remove agent ones, keep dirty |
| `wtpb` | prune branches whose worktree is gone |
| `wtp` | `git worktree prune -v` |

`-b` branches from `HEAD` instead of the remote default.

## Extending

A backend is one function taking `(name, path)`, passed to `_wt_core`:

```zsh
_wt_mine() { cd "$2" && my-multiplexer open "$2"; }
wtm() { _wt_core _wt_mine "$@"; }
```

`_wt_core` handles the picker, upsert and creation; the backend only opens.

## Exports

`WT_CORE_BIN` — this plugin's `bin/`, for sibling plugins and previews.
