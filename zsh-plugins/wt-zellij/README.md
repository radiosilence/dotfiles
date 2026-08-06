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
| `wttpr <n\|url\|owner/repo#n>` | PR **or** issue — a URL disambiguates, a bare number is probed |
| `wtti <n\|url\|owner/repo#n>` | worktree for an issue, named `<n>-<slug>`, claude primed on `/ticket <n>` |
| `wttpr-pick` | fzf over open PRs and issues, then as above |

Tabs are named after the branch and reused if one already exists.

## Picker

`alt+w` opens `bin/wt-picker` in a floating pane: enter opens or creates,
`^x` removes, `^r` pulls, and `^v`/`^y`/`^d`/`^l` are PR view / checks / diff /
create. It only picks — creating and removing shell out to `wtt` and `wtrm`,
since its own copy of the create path had already drifted from `wt-core`'s.

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
