# tmux Cheatsheet

Quick reference for the tmux setup. Prefix is `C-a` (ctrl+a).

## Basics

| Key | Action |
|-----|--------|
| `C-a` | Prefix (replaces default C-b) |
| `C-a r` | Reload config |
| `C-a d` | Detach session |
| `C-a ?` | List all keybindings |

## Windows

| Key | Action |
|-----|--------|
| `C-a c` | New window (inherits current path) |
| `C-a &` | Kill window (with confirm) |
| `C-a X` | Kill window (no confirm) |
| `C-a ,` | Rename window |
| `C-a n` / `C-a p` | Next / previous window |
| `C-a 1-9` | Switch to window N |
| `C-a <` / `C-a >` | Move window left / right (repeatable) |
| `C-a w` | Window picker (tree view) |

## Panes

| Key | Action |
|-----|--------|
| `C-a [` | Split horizontal (left/right) |
| `C-a ]` | Split vertical (top/bottom) |
| `C-a h/j/k/l` | Navigate panes (vim-style) |
| `C-a H/J/K/L` | Resize pane (repeatable, 5 cells) |
| `C-a x` | Kill pane (no confirm) |
| `C-a z` | Toggle pane zoom (fullscreen) |
| `C-a q` | Show pane numbers |
| `C-a {` / `C-a }` | Swap pane left / right |
| `C-a space` | Cycle pane layouts |

## Sessions

| Key | Action |
|-----|--------|
| `C-a s` | Session picker (sesh + fzf popup with preview) |
| `C-a $` | Rename session |
| `C-a (` / `C-a )` | Previous / next session |

## Copy Mode (vi)

Enter copy mode with `C-a v` (or mouse scroll up), then:

| Key | Action |
|-----|--------|
| `v` | Begin selection |
| `C-v` | Toggle rectangle selection |
| `y` | Yank (copy) and exit |
| `/` / `?` | Search forward / backward |
| `n` / `N` | Next / previous match |
| `q` | Exit copy mode |

Yanked text goes to system clipboard via OSC 52.

## Other

| Key | Action |
|-----|--------|
| `C-k` | Clear screen + scrollback (no prefix) |
| `C-a :` | Command prompt |
| `C-a C` | Customize mode (browse/edit options) |
| `C-a t` | Show clock |

## Session Persistence (resurrect)

| Key | Action |
|-----|--------|
| `C-a C-s` | Save session (windows, panes, layout) |
| `C-a C-r` | Restore saved session |

Sessions are saved to `~/.tmux/resurrect/` and survive reboots.

## Status Bar

- **Left**: green session pill with name
- **Center**: window list (`index name`), current window highlighted yellow
- **Right**: git branch/status (gitmux) + hostname + time

## Window Names

Windows auto-rename based on context:
- **Shell prompt** (zsh) → directory basename
- **Running a program** (vim, node, cargo) → command name
- **Program sets title** via escape sequence → that title shown
- **Manual rename** (`C-a ,`) → your name sticks

## CLI

```sh
tmux                    # start new session
tmux new -s name        # start named session
tmux ls                 # list sessions
tmux a -t name          # attach to session
tmux kill-session -t x  # kill session
```
