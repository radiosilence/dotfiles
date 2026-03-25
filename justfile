set quiet
set dotenv-load := false

export CLICOLOR_FORCE := "1"
export FORCE_COLOR := "1"

dotfiles := justfile_directory()

# ===========================================================================
# System update pipeline
#
# DAG:
#   link, auth, claude, tmux-plugins              — parallel
#   brew-update → brew-bundle → brew-upgrade → brew-cleanup  — chained
#   mise → fonts                                  — fonts needs yq
#   [brew-cleanup, mise] → zsh-completions        — last
# ===========================================================================

# Update the system
[parallel]
upd: link upd-auth upd-fonts upd-brew-cleanup upd-apt upd-dnf upd-mise upd-claude upd-tmux-plugins upd-zsh-completions
    rm -f ~/.cache/zsh/eval/*.zsh ~/.cache/zsh/eval/*.zwc
    rm -f ~/.config/zsh/conf.d/*.zwc
    rm -f ~/.zcompdump
    printf "󰄬\033[0m \033[1msystem update complete\033[0m (restart shell for changes)"

# Post-bootstrap setup (build bins, update system, switch to SSH)
setup: reinstall-bins upd use-ssh
    printf "\n  \033[32m󰄬\033[0m \033[1msetup complete\033[0m (restart your terminal)\n\n"

# Symlink dotfiles and configs
link:
    #!/usr/bin/env bash
    set -euo pipefail
    DOTFILES="{{ dotfiles }}"

    # Dotfiles (.* → ~)
    for f in "$DOTFILES"/.*; do
      name=$(basename "$f")
      case "$name" in
        .|..|.git|.gitignore|.github|.vscode|.sonarlint|\
        .editorconfig|.codeowners-lsp|.ruby-lsp|.crates.toml|.crates2.json)
          continue ;;
      esac
      target="$HOME/$name"
      if [ -L "$target" ] && [ "$(readlink "$target")" = "$f" ]; then
        continue
      fi
      rm -rf "$target"
      ln -s "$f" "$target"
      printf "  \033[32m󰌷\033[0m %s\n" "$name"
    done

    # Config dirs (config.d/* → ~/.config/*)
    mkdir -p "$HOME/.config"
    if [ -d "$DOTFILES/config.d" ]; then
      for f in "$DOTFILES/config.d"/*; do
        [ -e "$f" ] || continue
        name=$(basename "$f")
        [ "$name" = "launchd" ] && continue
        target="$HOME/.config/$name"
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$f" ]; then
          continue
        fi
        rm -rf "$target"
        ln -s "$f" "$target"
        printf "  \033[32m󰌷\033[0m ~/.config/%s\n" "$name"
      done
    fi

    # Gitconfig include
    [ -f "$HOME/.gitconfig" ] || touch "$HOME/.gitconfig"
    if ! grep -q '.dotfiles' "$HOME/.gitconfig" 2>/dev/null; then
      printf '\n[include]\npath = ~/.dotfiles/git.d/core.conf\n' >> "$HOME/.gitconfig"
      printf "  \033[32m󰄬\033[0m gitconfig include\n"
    fi

    # SSH config include
    mkdir -p "$HOME/.ssh"
    if [ ! -f "$HOME/.ssh/config" ]; then
      touch "$HOME/.ssh/config"
      chmod 600 "$HOME/.ssh/config"
    fi
    if ! grep -q '.dotfiles' "$HOME/.ssh/config" 2>/dev/null; then
      printf '\nInclude ~/.dotfiles/ssh.d/*.conf\n' >> "$HOME/.ssh/config"
      printf "  \033[32m󰄬\033[0m ssh config include\n"
    fi

    # Brewfile symlink (macOS)
    if [ "$(uname)" = "Darwin" ] && [ -f "$DOTFILES/Brewfile" ]; then
      target="$HOME/Brewfile"
      if ! [ -L "$target" ] || [ "$(readlink "$target")" != "$DOTFILES/Brewfile" ]; then
        ln -sf "$DOTFILES/Brewfile" "$target"
        printf "  \033[32m󰄬\033[0m Brewfile\n"
      fi
    fi

    # Launchd agents (macOS)
    if [ "$(uname)" = "Darwin" ] && [ -d "$DOTFILES/config.d/launchd" ]; then
      agents="$HOME/Library/LaunchAgents"
      mkdir -p "$agents"
      for plist in "$DOTFILES/config.d/launchd"/*.plist; do
        [ -f "$plist" ] || continue
        name=$(basename "$plist")
        dest="$agents/$name"
        if [ -f "$dest" ] && cmp -s "$plist" "$dest"; then
          continue
        fi
        cp "$plist" "$dest"
        launchctl unload "$dest" 2>/dev/null || true
        launchctl load "$dest" 2>/dev/null || true
        printf "  \033[32m󰄬\033[0m launchd: %s\n" "$name"
      done
    fi

    # Claude Code hooks
    claude_settings="$HOME/.claude/settings.json"
    if command -v jq >/dev/null 2>&1 && [ -f "$claude_settings" ]; then
      if ! jq -e '.hooks.PostToolUse[]?.hooks[]? | select(.command | contains("gastown-file-changed"))' "$claude_settings" >/dev/null 2>&1; then
        jq '
          .hooks //= {} |
          .hooks.PostToolUse //= [] |
          .hooks.PostToolUse += [{"matcher": "Write|Edit", "hooks": [{"type": "command", "command": "~/.dotfiles/hooks/gastown-file-changed.sh"}]}]
        ' "$claude_settings" > "$claude_settings.tmp" && mv "$claude_settings.tmp" "$claude_settings"
        printf "  \033[32m󰄬\033[0m claude hooks: gastown\n"
      fi
    fi

    # Sheldon plugins
    if command -v sheldon >/dev/null 2>&1; then
      sheldon source >/dev/null 2>&1 && printf "  \033[32m󰄬\033[0m sheldon\n" || true
    fi

    printf "  \033[32m󰄬\033[0m link complete\n"

# Build and install rust binaries from crates/
reinstall-bins: upd-mise
    #!/usr/bin/env bash
    set -euo pipefail
    command -v cargo >/dev/null 2>&1 || { printf "  \033[31m󰅖\033[0m cargo not found\n"; exit 1; }
    printf "  \033[35m󱁤\033[0m building rust binaries\n"
    cargo install --path {{ dotfiles }}/crates --bins --root {{ dotfiles }}
    printf "  \033[32m󰄬\033[0m binaries installed\n"

# Switch dotfiles remote from HTTPS to SSH
use-ssh:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ dotfiles }}"
    current=$(git remote get-url origin)
    if echo "$current" | grep -q "^git@"; then
      printf "  \033[32m󰄬\033[0m already using SSH\n"
      exit 0
    fi
    ssh_url=$(echo "$current" | sed -E 's|https://github.com/(.+)|git@github.com:\1|')
    git remote set-url origin "$ssh_url"
    printf "  \033[32m󰄬\033[0m remote switched to %s\n" "$ssh_url"

# Check gh/op authentication
[macos]
upd-auth:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v gh >/dev/null 2>&1; then
      if gh auth status >/dev/null 2>&1; then
        printf "  \033[32m󰄬\033[0m gh: authenticated\n"
      else
        printf "  \033[33m\033[0m gh: not authenticated (run gh auth login)\n"
      fi
    fi
    if command -v op >/dev/null 2>&1; then
      if op account list >/dev/null 2>&1; then
        printf "  \033[32m󰄬\033[0m op: integrated\n"
      else
        printf "  \033[33m\033[0m op: not integrated (check 1Password CLI settings)\n"
      fi
    fi

[linux]
upd-auth:
    @true

# Install missing fonts
[macos, parallel]
upd-fonts: upd-mise
    #!/usr/bin/env bash
    set -euo pipefail
    command -v yq >/dev/null 2>&1 || { echo "skipped (no yq)"; exit 0; }

    FONTS_DIR="$HOME/Library/Fonts"
    mkdir -p "$FONTS_DIR"

    count=$(yq -p toml -oy '.fonts | length' "{{ dotfiles }}/dotfiles.toml")
    [[ "$count" -gt 0 ]] || { echo "no fonts configured"; exit 0; }

    for i in $(seq 0 $((count - 1))); do
      name=$(yq -p toml -oy -r ".fonts[$i].name" "{{ dotfiles }}/dotfiles.toml")
      url=$(yq -p toml -oy -r ".fonts[$i].url" "{{ dotfiles }}/dotfiles.toml")
      marker=$(yq -p toml -oy -r ".fonts[$i].marker_file" "{{ dotfiles }}/dotfiles.toml")

      if [ -f "$FONTS_DIR/$marker" ]; then
        printf "  \033[32m󰄬\033[0m %s (installed)\n" "$name"
        continue
      fi

      printf "  \033[35m󱁤\033[0m %s (downloading)\n" "$name"
      tmpdir=$(mktemp -d)
      trap "rm -rf '$tmpdir'" EXIT
      curl -fsSL "$url" -o "$tmpdir/font.zip"
      unzip -qo "$tmpdir/font.zip" -d "$tmpdir/extracted"
      find "$tmpdir/extracted" \( -iname '*.otf' -o -iname '*.ttf' \) -exec cp {} "$FONTS_DIR/" \;
      rm -rf "$tmpdir"
      printf "  \033[32m󰄬\033[0m %s (installed)\n" "$name"
    done

[linux]
upd-fonts:
    @true

# Update brew index
[macos]
upd-brew-update: link
    #!/usr/bin/env bash
    set -euo pipefail
    command -v brew >/dev/null 2>&1 || { echo "skipped (no brew)"; exit 0; }
    brew update --quiet

# Install Brewfile packages
[macos]
upd-brew-bundle: upd-brew-update
    #!/usr/bin/env bash
    set -euo pipefail
    command -v brew >/dev/null 2>&1 || { echo "skipped (no brew)"; exit 0; }
    HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --quiet

# Upgrade brew packages
[macos]
upd-brew-upgrade: upd-brew-bundle
    #!/usr/bin/env bash
    set -euo pipefail
    command -v brew >/dev/null 2>&1 || { echo "skipped (no brew)"; exit 0; }
    HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade --greedy --quiet

# Cleanup brew
[macos]
upd-brew-cleanup: upd-brew-upgrade
    #!/usr/bin/env bash
    set -euo pipefail
    command -v brew >/dev/null 2>&1 || { echo "skipped (no brew)"; exit 0; }
    brew cleanup --quiet

[linux]
upd-brew-update:
    @true

[linux]
upd-brew-bundle:
    @true

[linux]
upd-brew-upgrade:
    @true

[linux]
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

[macos]
upd-apt:
    @true

# Update dnf packages
[linux]
upd-dnf:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v dnf >/dev/null 2>&1 || exit 0
    sudo dnf update -y

[macos]
upd-dnf:
    @true

# Update mise tools
upd-mise:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v mise >/dev/null 2>&1 || { echo "skipped (no mise)"; exit 0; }
    mise up
    mise reshim

# Update Claude Code
upd-claude:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v claude >/dev/null 2>&1 || { echo "skipped (no claude)"; exit 0; }
    claude --update

# Install/update tmux plugins
upd-tmux-plugins:
    #!/usr/bin/env bash
    set -euo pipefail
    PLUGINS_DIR="$HOME/.tmux/plugins"
    mkdir -p "$PLUGINS_DIR"

    install_plugin() {
      local name="$1" url="$2"
      local dest="$PLUGINS_DIR/$name"
      if [ -d "$dest" ]; then
        git -C "$dest" pull --quiet
        printf "  \033[32m󰄬\033[0m %s (updated)\n" "$name"
      else
        git clone --quiet "$url" "$dest"
        printf "  \033[32m󰄬\033[0m %s (installed)\n" "$name"
      fi
    }

    install_plugin tmux-resurrect https://github.com/tmux-plugins/tmux-resurrect.git
    install_plugin tmux-fzf-url   https://github.com/wfxr/tmux-fzf-url.git

# Regenerate zsh completions
[parallel]
upd-zsh-completions: upd-brew-cleanup upd-mise
    #!/usr/bin/env bash
    set -euo pipefail
    command -v regen-zsh-completions >/dev/null 2>&1 || { echo "regen-zsh-completions not found, skipping"; exit 0; }
    regen-zsh-completions
