set quiet
set unstable
set dotenv-load := false

export CLICOLOR_FORCE := "1"
export FORCE_COLOR := "1"

dotfiles := justfile_directory()

# Hard requirements
_mise := require("mise")

# Colors
green := '\033[32m'
yellow := '\033[33m'
magenta := '\033[35m'
cyan := '\033[36m'
red := '\033[31m'
bold := '\033[1m'
reset := '\033[0m'
ok := green + '󰄬' + reset
warn := yellow + '' + reset
fail := red + '󰅖' + reset
link_icon := green + '󰌷' + reset
working := magenta + '󱁤' + reset

# ===========================================================================
# System update pipeline
#
# DAG:
#   link-*, auth-*, claude, tmux-plugins    — parallel
#   brew-update → brew-bundle → brew-upgrade → brew-cleanup  — chained
#   mise → fonts                            — fonts needs yq
#   [brew-cleanup, mise] → zsh-completions  — last
# ===========================================================================

# Update the system
[parallel]
upd: \
    link-dotfiles link-config link-gitconfig link-ssh link-brewfile \
    link-launchd link-claude-hooks link-sheldon \
    upd-auth-gh upd-auth-op \
    upd-fonts upd-brew-cleanup upd-apt upd-dnf \
    upd-mise upd-claude upd-tmux-plugins upd-zsh-completions
    rm -f ~/.cache/zsh/eval/*.zsh ~/.cache/zsh/eval/*.zwc
    rm -f ~/.config/zsh/conf.d/*.zwc
    rm -f ~/.zcompdump
    printf "{{ ok }} {{ bold }}system update complete{{ reset }} (restart shell for changes)\n"

# Post-bootstrap setup (build bins, update system, switch to SSH)
setup: reinstall-bins upd use-ssh
    printf "\n  {{ ok }} {{ bold }}setup complete{{ reset }} (restart your terminal)\n\n"

# ---------------------------------------------------------------------------
# Link tasks
# ---------------------------------------------------------------------------

# Symlink dotfiles (.* → ~)
link-dotfiles:
    #!/usr/bin/env bash
    set -euo pipefail
    for f in "{{ dotfiles }}"/.* ; do
      name=$(basename "$f")
      case "$name" in
        .|..|.git|.gitignore|.github|.vscode|.sonarlint|\
        .editorconfig|.codeowners-lsp|.ruby-lsp|.crates.toml|.crates2.json)
          continue ;;
      esac
      target="$HOME/$name"
      [ -L "$target" ] && [ "$(readlink "$target")" = "$f" ] && continue
      rm -rf "$target"
      ln -s "$f" "$target"
      printf "  {{ link_icon }} %s\n" "$name"
    done

# Symlink config dirs (config.d/* → ~/.config/*)
link-config:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "$HOME/.config"
    [ -d "{{ dotfiles }}/config.d" ] || exit 0
    for f in "{{ dotfiles }}/config.d"/*; do
      [ -e "$f" ] || continue
      name=$(basename "$f")
      [ "$name" = "launchd" ] && continue
      target="$HOME/.config/$name"
      [ -L "$target" ] && [ "$(readlink "$target")" = "$f" ] && continue
      rm -rf "$target"
      ln -s "$f" "$target"
      printf "  {{ link_icon }} ~/.config/%s\n" "$name"
    done

# Ensure gitconfig includes dotfiles
link-gitconfig:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -f "$HOME/.gitconfig" ] || touch "$HOME/.gitconfig"
    grep -q '.dotfiles' "$HOME/.gitconfig" 2>/dev/null && exit 0
    printf '\n[include]\npath = ~/.dotfiles/git.d/core.conf\n' >> "$HOME/.gitconfig"
    printf "  {{ ok }} gitconfig include\n"

# Ensure SSH config includes dotfiles
link-ssh:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "$HOME/.ssh"
    if [ ! -f "$HOME/.ssh/config" ]; then
      touch "$HOME/.ssh/config"
      chmod 600 "$HOME/.ssh/config"
    fi
    grep -q '.dotfiles' "$HOME/.ssh/config" 2>/dev/null && exit 0
    printf '\nInclude ~/.dotfiles/ssh.d/*.conf\n' >> "$HOME/.ssh/config"
    printf "  {{ ok }} ssh config include\n"

# Symlink Brewfile
[macos]
link-brewfile:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -f "{{ dotfiles }}/Brewfile" ] || exit 0
    target="$HOME/Brewfile"
    [ -L "$target" ] && [ "$(readlink "$target")" = "{{ dotfiles }}/Brewfile" ] && exit 0
    ln -sf "{{ dotfiles }}/Brewfile" "$target"
    printf "  {{ ok }} Brewfile\n"

[linux, private]
link-brewfile:
    @true

# Install launchd agents
[macos]
link-launchd:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -d "{{ dotfiles }}/config.d/launchd" ] || exit 0
    agents="$HOME/Library/LaunchAgents"
    mkdir -p "$agents"
    for plist in "{{ dotfiles }}/config.d/launchd"/*.plist; do
      [ -f "$plist" ] || continue
      name=$(basename "$plist")
      dest="$agents/$name"
      [ -f "$dest" ] && cmp -s "$plist" "$dest" && continue
      cp "$plist" "$dest"
      launchctl unload "$dest" 2>/dev/null || true
      launchctl load "$dest" 2>/dev/null || true
      printf "  {{ ok }} launchd: %s\n" "$name"
    done

[linux, private]
link-launchd:
    @true

# Inject Claude Code hooks into settings.json
link-claude-hooks:
    #!/usr/bin/env bash
    set -euo pipefail
    claude_settings="$HOME/.claude/settings.json"
    command -v jq >/dev/null 2>&1 || exit 0
    [ -f "$claude_settings" ] || exit 0
    jq -e '.hooks.PostToolUse[]?.hooks[]? | select(.command | contains("gastown-file-changed"))' "$claude_settings" >/dev/null 2>&1 && exit 0
    jq '
      .hooks //= {} |
      .hooks.PostToolUse //= [] |
      .hooks.PostToolUse += [{"matcher": "Write|Edit", "hooks": [{"type": "command", "command": "~/.dotfiles/hooks/gastown-file-changed.sh"}]}]
    ' "$claude_settings" > "$claude_settings.tmp" && mv "$claude_settings.tmp" "$claude_settings"
    printf "  {{ ok }} claude hooks: gastown\n"

# Sheldon plugin manager
link-sheldon:
    #!/usr/bin/env bash
    command -v sheldon >/dev/null 2>&1 || exit 0
    sheldon source >/dev/null 2>&1 && printf "  {{ ok }} sheldon\n" || true

# ---------------------------------------------------------------------------
# Build / utility tasks
# ---------------------------------------------------------------------------

# Build and install rust binaries from crates/
reinstall-bins: upd-mise
    #!/usr/bin/env bash
    set -euo pipefail
    command -v cargo >/dev/null 2>&1 || { printf "  {{ fail }} cargo not found\n"; exit 1; }
    printf "  {{ working }} building rust binaries\n"
    cargo install --path {{ dotfiles }}/crates --bins --root {{ dotfiles }}
    printf "  {{ ok }} binaries installed\n"

# Switch dotfiles remote from HTTPS to SSH
use-ssh:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ dotfiles }}"
    current=$(git remote get-url origin)
    if echo "$current" | grep -q "^git@"; then
      printf "  {{ ok }} already using SSH\n"
      exit 0
    fi
    ssh_url=$(echo "$current" | sed -E 's|https://github.com/(.+)|git@github.com:\1|')
    git remote set-url origin "$ssh_url"
    printf "  {{ ok }} remote switched to %s\n" "$ssh_url"

# ---------------------------------------------------------------------------
# Update tasks
# ---------------------------------------------------------------------------

# Check GitHub CLI auth
[macos]
upd-auth-gh:
    #!/usr/bin/env bash
    command -v gh >/dev/null 2>&1 || exit 0
    if gh auth status >/dev/null 2>&1; then
      printf "  {{ ok }} gh: authenticated\n"
    else
      printf "  {{ warn }} gh: not authenticated (run gh auth login)\n"
    fi

[linux, private]
upd-auth-gh:
    @true

# Check 1Password CLI integration
[macos]
upd-auth-op:
    #!/usr/bin/env bash
    command -v op >/dev/null 2>&1 || exit 0
    if op account list >/dev/null 2>&1; then
      printf "  {{ ok }} op: integrated\n"
    else
      printf "  {{ warn }} op: not integrated (check 1Password CLI settings)\n"
    fi

[linux, private]
upd-auth-op:
    @true

# Install missing fonts using the Rust binary
[macos, parallel]
upd-fonts: upd-mise
    #!/usr/bin/env bash
    set -euo pipefail
    command -v yq >/dev/null 2>&1 || { echo "skipped (no yq)"; exit 0; }
    command -v install-font-macos >/dev/null 2>&1 || { echo "skipped (no install-font-macos)"; exit 0; }
    urls=$(yq -p toml -oy -r '.fonts[].url' "{{ dotfiles }}/dotfiles.toml")
    [ -n "$urls" ] || { echo "no fonts configured"; exit 0; }
    install-font-macos $urls

[linux, private]
upd-fonts:
    @true

# Update brew index
[macos]
upd-brew-update: link-brewfile
    #!/usr/bin/env bash
    set -euo pipefail
    command -v brew >/dev/null 2>&1 || exit 0
    brew update --quiet

# Install Brewfile packages
[macos]
upd-brew-bundle: upd-brew-update
    #!/usr/bin/env bash
    set -euo pipefail
    command -v brew >/dev/null 2>&1 || exit 0
    HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --quiet

# Upgrade brew packages
[macos]
upd-brew-upgrade: upd-brew-bundle
    #!/usr/bin/env bash
    set -euo pipefail
    command -v brew >/dev/null 2>&1 || exit 0
    HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade --greedy --quiet

# Cleanup brew
[macos]
upd-brew-cleanup: upd-brew-upgrade
    #!/usr/bin/env bash
    set -euo pipefail
    command -v brew >/dev/null 2>&1 || exit 0
    brew cleanup --quiet

[linux, private]
upd-brew-update:
    @true

[linux, private]
upd-brew-bundle:
    @true

[linux, private]
upd-brew-upgrade:
    @true

[linux, private]
upd-brew-cleanup:
    @true

# Update apt packages
[linux]
upd-apt:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v apt-get >/dev/null 2>&1 || exit 0
    sudo apt-get update
    sudo apt-get upgrade -y
    sudo apt-get autoremove -y

[macos, private]
upd-apt:
    @true

# Update dnf packages
[linux]
upd-dnf:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v dnf >/dev/null 2>&1 || exit 0
    sudo dnf update -y

[macos, private]
upd-dnf:
    @true

# Update mise tools
upd-mise:
    #!/usr/bin/env bash
    set -euo pipefail
    mise up
    mise reshim

# Update Claude Code
upd-claude:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v claude >/dev/null 2>&1 || exit 0
    claude --update

# Install/update tmux plugins
[parallel]
upd-tmux-plugins: upd-tmux-resurrect upd-tmux-fzf-url

[private]
upd-tmux-resurrect:
    #!/usr/bin/env bash
    set -euo pipefail
    dest="$HOME/.tmux/plugins/tmux-resurrect"
    mkdir -p "$(dirname "$dest")"
    if [ -d "$dest" ]; then
      git -C "$dest" pull --quiet
      printf "  {{ ok }} tmux-resurrect (updated)\n"
    else
      git clone --quiet https://github.com/tmux-plugins/tmux-resurrect.git "$dest"
      printf "  {{ ok }} tmux-resurrect (installed)\n"
    fi

[private]
upd-tmux-fzf-url:
    #!/usr/bin/env bash
    set -euo pipefail
    dest="$HOME/.tmux/plugins/tmux-fzf-url"
    mkdir -p "$(dirname "$dest")"
    if [ -d "$dest" ]; then
      git -C "$dest" pull --quiet
      printf "  {{ ok }} tmux-fzf-url (updated)\n"
    else
      git clone --quiet https://github.com/wfxr/tmux-fzf-url.git "$dest"
      printf "  {{ ok }} tmux-fzf-url (installed)\n"
    fi

# Regenerate zsh completions
[parallel]
upd-zsh-completions: upd-brew-cleanup upd-mise
    #!/usr/bin/env bash
    set -euo pipefail
    command -v regen-zsh-completions >/dev/null 2>&1 || { echo "regen-zsh-completions not found, skipping"; exit 0; }
    regen-zsh-completions
