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
| `wtrm [name]` | remove the worktree you're in (or a named one), branch included |
| `wtclean [-n]` | garbage-collect worktrees and branches against GitHub |

`-b` branches from `HEAD` instead of the remote default. `-n` is a dry run.

## wtclean

Everything gets squash-merged, so a merged branch still looks unmerged to
`git branch --merged` and nothing is ever reclaimed. GitHub's PR state is the
only reliable signal, so `wtclean` asks `gh`: a worktree whose PR is **merged or
closed** goes, branch included, along with orphaned branches whose worktree is
already gone. Without `gh` it falls back to a deleted upstream, which means the
same thing in practice.

Uncommitted changes always win — a dirty worktree is never touched, nor is the
one you're standing in. Agent worktrees under `.claude/worktrees` are session
detritus and always go.

One `gh pr list` up front rather than a query per branch, which is the
difference between a second and a minute. Safe to run from cron.

## Extending

A backend is one function taking `(name, path)`, passed to `_wt_core`:

```zsh
_wt_mine() { cd "$2" && my-multiplexer open "$2"; }
wtm() { _wt_core _wt_mine "$@"; }
```

`_wt_core` handles the picker, upsert and creation; the backend only opens.

The GitHub entry points take that same function plus a `prime_fn`, which is
handed the issue number after the worktree opens (for sending a command into
the new pane — pass `:` to skip):

```zsh
wtmpr()      { _wt_pr      _wt_mine _wt_mine_prime "$@"; }  # PR or issue
wtmi()       { _wt_issue   _wt_mine _wt_mine_prime "$@"; }  # issue -> <n>-<slug>
```

Ref parsing, the PR/issue probe, fork fetching and slugging all live here, so a
backend is only ever the two functions above.

## Bin

Everything here is zsh — these are zsh plugins, zsh is guaranteed present, and
macOS still ships bash 3.2.

Each script answers `--help` and `--completions zsh`, matching the convention
the Rust binaries follow. `task generate:completions` picks them up by path
rather than `command -v`, since plugin internals aren't on `PATH`. The ones
taking a branch emit a completion that calls the script back by absolute path,
so the porcelain parsing stays in one place.

`wt-list` prints `branch<TAB>path` per worktree, or the path of a named branch.
Parsing `worktree list --porcelain` lived in four places and drifted; this is
the one copy. `wt-preview` renders the fzf preview: PR details if there's a PR,
otherwise log plus tree.

`wtclean` is a script rather than a function, and `wtclean()` in the plugin is
a one-line shim onto it. A function is only worth defining when it has to
mutate the shell — `wt` and `wtrm` cd, so they qualify; a GC pass doesn't. The
difference matters: a shell started before an update will happily run a stale
function against changed helpers and half-succeed, which is exactly how a run
once reported `removed 0, kept 0` while still deleting seven branches.

## Exports

`WT_CORE_BIN` — this plugin's `bin/`, for sibling plugins and previews.
