---
name: zellij-here
description: Open a new zellij pane in the project/worktree Claude is contextually working on -- inferred automatically, no questions asked. Use when the user says "open here", "new pane here", "/here", "open this in zellij". The whole point is the user doesn't have to tell Claude where it's working -- Claude figures it out from session context.
argument-hint: "[optional path -- overrides inference]"
allowed-tools: Bash
---

# zellij-here

Spawn a new zellij pane in the directory Claude has been **contextually working on**, titled with the worktree basename. **Do not ask the user where to open it** -- the entire reason this skill exists is so the user doesn't have to say.

## How to pick the directory (in order)

Walk this list top-to-bottom and **stop at the first hit**. Don't ask, don't second-guess, just go. If it's wrong the user will say so.

1. **`$ARGUMENTS` is an existing path.** Use it. Done.
2. **A worktree this session spawned.** If Claude has run `git worktree add` or invoked an async-ticket / feature-workflow / batch skill that created a worktree in this session, that worktree is the target. The most recently-created one wins.
3. **A subagent's working directory.** If background/foreground Agents are running in a specific worktree (look at recent Agent tool calls with `isolation: "worktree"` or explicit `cwd`), use that worktree. Most-recently-spawned wins.
4. **The current task's repo.** Recent Edit/Write/Read tool calls cluster under some path -- take the deepest common ancestor that is a git toplevel. Run `git -C <path> rev-parse --show-toplevel` to canonicalize.
5. **An explicitly-named project from the conversation.** If the user said "the foo repo" or "the bar worktree" earlier and there's a matching dir under `~/workspace/` or `~/.dotfiles` etc., use it.
6. **`$PWD`.** Last resort, only if all of the above came up empty.

Never prompt the user. Pick the best signal available and announce what you picked.

## Resolving the title

Title = basename of the target's git toplevel (so worktree dirs stay distinct from their bare repos):

```bash
TITLE="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null | xargs -I{} basename {})"
[ -z "$TITLE" ] && TITLE="$(basename "$TARGET")"
```

## Launch

**Important:** zellij's `--cwd` flag is unreliable when no command is given -- the spawned default shell often inherits the focused pane's cwd anyway. So we explicitly spawn the user's `$SHELL` with an explicit `cd` before exec'ing the login shell. Belt-and-braces: still pass `--cwd` as a hint.

Never use `zsh -i` (zle errors in non-TTY). Use `-l` for a login shell.

```bash
# TARGET = absolute path picked by the inference rules above.
TARGET="<resolved absolute path>"
TITLE="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null | xargs -I{} basename {})"
[ -z "$TITLE" ] && TITLE="$(basename "$TARGET")"

timeout 5 zellij action new-pane --cwd "$TARGET" --name "$TITLE" \
  -- "$SHELL" -lc "cd \"$TARGET\" && exec \"$SHELL\" -l" || {
  _rc=$?
  if [ -z "$ZELLIJ" ]; then echo "Not in a zellij session"
  elif [ $_rc -eq 124 ]; then echo "Timed out -- zellij may be hanging"
  else echo "zellij action new-pane failed (exit $_rc)"
  fi
  exit $_rc
}
```

After it lands, output ONE short line: `Opened pane at <TARGET> (<TITLE>)`. That's the user's chance to spot a bad inference and correct -- but you've already opened it, you didn't block on a question.

## Rules

- **Never ask the user where to open.** Pick and go. Wrong picks are cheap; questions are not.
- **`$PWD` is last-resort, not default.** Claude's launch cwd is usually the wrong answer when worktrees are in play.
- Always pass `--cwd "$TARGET"` -- absolute path.
- Title = git toplevel basename of `$TARGET`.
- Pane only. Tab requests -> `zellij-workflow:zellij-tab-pane`.
- Refuse cleanly outside a zellij session (`$ZELLIJ` unset).
- One-line confirmation after launch, naming the dir. No paragraphs.
