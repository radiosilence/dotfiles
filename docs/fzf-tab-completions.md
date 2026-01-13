# fzf-tab Zsh Completions Setup

Replaces zsh's default completion menu with fzf - fuzzy search through completions with previews.

## Prerequisites

- `fzf` installed via mise: `"github:junegunn/fzf" = "latest"`
- `sheldon` plugin manager: `"github:rossmacarthur/sheldon" = "latest"`
- `bat` and `lsd` for previews

## Installation

### 1. Add fzf-tab to sheldon plugins

In `~/.config/sheldon/plugins.toml`:

```toml
[plugins.fzf-tab]
github = "Aloxaf/fzf-tab"
```

### 2. Enable fzf shell integration

In `~/.config/zsh/conf.d/fzf.zsh`:

```zsh
command -v fzf >/dev/null || return
eval "$(fzf --zsh)"
```

### 3. Configure fzf-tab styling and previews

In `~/.config/zsh/conf.d/shell.zsh` (or wherever you do zstyles):

```zsh
# fzf-tab config
zstyle ':fzf-tab:*' fzf-flags --height=50% --layout=reverse --border=rounded --info=inline
zstyle ':fzf-tab:*' switch-group '<' '>'

# Directory preview with lsd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'lsd -1 --color=always $realpath 2>/dev/null || ls -1 --color=always $realpath'

# Generic file preview with bat, fallback to cat, then lsd for dirs
zstyle ':fzf-tab:complete:*:*' fzf-preview 'bat --style=numbers --color=always --line-range=:100 $realpath 2>/dev/null || cat $realpath 2>/dev/null || lsd -1 --color=always $realpath 2>/dev/null || echo $desc'

# Process preview for kill command
zstyle ':fzf-tab:complete:kill:*' fzf-preview 'ps -p $word -o pid,user,%cpu,%mem,command --no-headers 2>/dev/null'

# Systemctl preview (linux)
zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word 2>/dev/null'
```

### 4. Load sheldon in zsh

In `~/.config/zsh/conf.d/sheldon.zsh`:

```zsh
command -v sheldon >/dev/null || return
eval "$(sheldon source)"
```

## Usage

Just press `<Tab>` as normal - fzf takes over:

- Type to fuzzy filter completions
- `<Tab>` to select multiple items
- `<` and `>` to switch between completion groups
- Preview pane shows file contents / directory listings / process info

## Troubleshooting

If completions aren't working:

```bash
# Rebuild sheldon cache
sheldon lock --update

# Clear zsh completion cache
rm -rf ~/.cache/zsh/completions
```
