# wt-zellij

[zellij](https://zellij.dev) backend for `wt-core`. Opens each worktree in a
named tab.

## Install (sheldon)

Requires `wt-core`.

```toml
[plugins.wt-core]
local = "~/.dotfiles/zsh-plugins/wt-core"

[plugins.wt-zellij]
local = "~/.dotfiles/zsh-plugins/wt-zellij"
```

## Commands

| Command | Does |
| --- | --- |
| `wtt [-b] <name> [base]` | upsert worktree, open in a zellij tab. No args: fzf picker |

Tabs are named after the branch and reused if one already exists.

## Cleanup on exit

Tabs run through `bin/wt-shell`, which on exit removes the worktree if it's
clean and prompts if there are uncommitted changes or unpushed commits. It
compares the worktree against `--git-common-dir` first, so it never touches a
main checkout.

This only covers worktrees opened *through* `wtt`. Anything created another way
— agent worktrees especially — is never wrapped, so `wtclean` from `wt-core` is
still worth running.

## Exports

`WT_ZELLIJ_BIN` — this plugin's `bin/`.
