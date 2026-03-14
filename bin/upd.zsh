#!/usr/bin/env zsh
# upd — system update orchestrator
#
# Replaces the Rust upd binary + shell wrapper with a single zsh script.
# Trades parallelism for simplicity. Uses python3 tomllib for config parsing.

setopt LOCAL_OPTIONS PIPE_FAIL
# No ERR_RETURN — we handle errors per-task so one failure doesn't abort everything

readonly DOTFILES="$HOME/.dotfiles"
readonly COMPLETIONS_DIR="$HOME/.config/zsh/completions"
typeset -gi ANY_FAILED=0 VERBOSE=0 GH_OK=0 OP_OK=0

# ─── Parse args ──────────────────────────────────────────────────────────────

for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=1 ;;
    --rebuild)
      if [[ -d "$DOTFILES/.git" ]]; then
        printf '\033[36m→ pulling ~/.dotfiles...\033[0m\n'
        git -C "$DOTFILES" pull || { printf '\033[31m✗ git pull failed\033[0m\n'; exit 1 }
      fi
      ;;
    -h|--help)
      echo "Usage: upd [--rebuild] [-v|--verbose]"
      echo "  --rebuild  Pull dotfiles before updating"
      echo "  -v         Verbose output"
      exit 0
      ;;
    *) echo "Unknown arg: $arg"; exit 1 ;;
  esac
done

# ─── Output helpers ──────────────────────────────────────────────────────────

_hdr()  { echo; printf '\033[1m/// .%s\033[0m\n' "$1"; echo }
_ok()   { printf '  \033[32m✓\033[0m %s\n' "$*" }
_warn() { printf '  \033[33m!\033[0m %s\n' "$*" }
_fail() { printf '  \033[31m✗\033[0m %s\n' "$*"; ANY_FAILED=1 }
_step() { printf '  \033[35m→\033[0m %s\n' "$*" }
_has()  { command -v "$1" &>/dev/null }

# Run a labeled command, suppressing output unless verbose or failed.
_run() {
  local label="$1"; shift
  if (( VERBOSE )); then
    if "$@"; then _ok "$label"; else _fail "$label"; fi
  else
    local out
    if out=$("$@" 2>&1); then
      _ok "$label"
    else
      _fail "$label"
      [[ -n "$out" ]] && printf '    %s\n' "${out[(f)1]}"
    fi
  fi
  return 0 # never abort — just mark failed
}

# ─── Config (TOML → JSON via Python) ────────────────────────────────────────
# Parses dotfiles.toml + dotfiles.local.toml with array merging.
# Returns JSON on stdout. Called once, result cached for fonts + completions.

_config_json() {
  python3 << 'PYEOF'
import json, sys
from pathlib import Path

try:
    import tomllib
except ImportError:
    print("{}", end="")  # empty config if no tomllib (Python < 3.11)
    sys.exit(0)

dotfiles = Path.home() / ".dotfiles"
base_path = dotfiles / "dotfiles.toml"
if not base_path.exists():
    print("{}", end="")
    sys.exit(0)

base = tomllib.loads(base_path.read_text())
local_path = dotfiles / "dotfiles.local.toml"
if local_path.exists():
    local = tomllib.loads(local_path.read_text())
    for k, v in local.items():
        if k in base and isinstance(base[k], dict) and isinstance(v, dict):
            for k2, v2 in v.items():
                if isinstance(base[k].get(k2), list) and isinstance(v2, list):
                    base[k][k2].extend(v2)
                else:
                    base[k][k2] = v2
        elif k in base and isinstance(base[k], list) and isinstance(v, list):
            base[k].extend(v)
        else:
            base[k] = v

json.dump(base, sys.stdout)
PYEOF
}

# ─── Link dotfiles ───────────────────────────────────────────────────────────

_link() {
  if ! mise run link -C "$DOTFILES"; then
    _fail "mise run link"
    return 1
  fi
}

# ─── Auth status (macOS only) ────────────────────────────────────────────────

_check_auth() {
  [[ "$OSTYPE" == darwin* ]] || return 0
  _hdr "AUTH STATUS"

  if _has gh; then
    if gh auth status &>/dev/null; then
      _ok "gh"; GH_OK=1
    else
      _warn "gh not authenticated"
      printf '     run: \033[36mgh auth login\033[0m\n'
    fi
  fi

  if _has op; then
    if op account list &>/dev/null; then
      _ok "1password cli"; OP_OK=1
    else
      _warn "1password cli not integrated"
      echo "     1. open 1Password -> Settings -> Developer -> CLI Integration"
      printf '     2. run: \033[36mop plugin init\033[0m\n'
    fi
  fi
}

# ─── Fonts (macOS only) ─────────────────────────────────────────────────────

_install_fonts() {
  [[ "$OSTYPE" == darwin* ]] || return 0
  local config_json="$1"
  local fonts_dir="$HOME/Library/Fonts"
  mkdir -p "$fonts_dir"

  # Extract font entries: name<TAB>url<TAB>marker_file
  local entries
  entries=$(echo "$config_json" | python3 -c "
import json, sys
for f in json.load(sys.stdin).get('fonts', []):
    print(f['name'], f['url'], f['marker_file'], sep='\t')
" 2>/dev/null) || return 0

  [[ -z "$entries" ]] && return 0

  echo "$entries" | while IFS=$'\t' read -r name url marker; do
    [[ -f "$fonts_dir/$marker" ]] && continue

    _step "installing $name..."
    local tmpdir
    tmpdir=$(mktemp -d)
    if curl -fsSL "$url" -o "$tmpdir/font.zip" && \
       unzip -qjo "$tmpdir/font.zip" '*.otf' '*.ttf' -d "$fonts_dir" 2>/dev/null; then
      _ok "$name"
    else
      _warn "$name (download/extract failed)"
    fi
    rm -rf "$tmpdir"
  done
}

# ─── Sudo setup/teardown ────────────────────────────────────────────────────

_sudo_setup() {
  local needs_sudo=0
  { _has apt-get || _has dnf } && needs_sudo=1
  (( needs_sudo )) || return 0

  if ! sudo -v 2>/dev/null; then
    if _has apt-get || _has dnf; then
      echo "Failed to get sudo authentication"; exit 1
    fi
    _warn "sudo auth failed, some operations may be skipped"
    return 1
  fi

  # Keepalive in background
  while true; do sudo -v; sleep 60; done &
  typeset -g SUDO_PID=$!
}

_sudo_teardown() {
  (( ${SUDO_PID:-0} )) && kill "$SUDO_PID" 2>/dev/null && wait "$SUDO_PID" 2>/dev/null
}

# ─── Update tasks ────────────────────────────────────────────────────────────

_update_apt() {
  _has apt-get || return 0
  _run "apt:update"     sudo apt-get update -qq
  _run "apt:upgrade"    sudo apt-get upgrade -y -qq
  _run "apt:autoremove" sudo apt-get autoremove -y -qq
}

_update_dnf() {
  _has dnf || return 0
  _run "dnf:update" sudo dnf update -y -q
}

_update_brew() {
  _has brew || return 0

  # Bundle runs interactively (may need sudo for casks)
  printf '\n\033[34m/// .BREW BUNDLE (may prompt for sudo)\033[0m\n'
  if brew bundle --quiet 2>&1; then
    _ok "brew bundle"
  else
    _fail "brew bundle"
  fi
  echo

  _run "brew:update"  brew update --quiet
  _run "brew:upgrade" brew upgrade --greedy --quiet
  _run "brew:cleanup" brew cleanup --quiet
}

_update_mise() {
  _has mise || return 0
  _run "mise:up"     mise up
  _run "mise:reshim" mise reshim
}

_update_claude() {
  _has claude || return 0
  _run "claude:update" claude --update
}

# ─── Tmux plugins ────────────────────────────────────────────────────────────

_sync_tmux_plugins() {
  local plugins_dir="$HOME/.tmux/plugins"
  mkdir -p "$plugins_dir"

  local -A plugins=(
    [tmux-resurrect]="https://github.com/tmux-plugins/tmux-resurrect.git"
    [tmux-fzf-url]="https://github.com/wfxr/tmux-fzf-url.git"
  )

  local name url
  for name url in "${(@kv)plugins}"; do
    local dest="$plugins_dir/$name"
    if [[ -d "$dest" ]]; then
      _run "tmux:$name:pull" git -C "$dest" pull --quiet
    else
      _run "tmux:$name:clone" git clone --quiet "$url" "$dest"
    fi
  done
}

# ─── ZSH completions ────────────────────────────────────────────────────────

_regen_completions() {
  local config_json="$1"

  echo "Generating completions for zsh... to $COMPLETIONS_DIR"
  rm -f "$HOME/.zcompdump"

  # Handle dangling symlink
  [[ -L "$COMPLETIONS_DIR" && ! -e "$COMPLETIONS_DIR" ]] && rm -f "$COMPLETIONS_DIR"

  if [[ -d "$COMPLETIONS_DIR" ]]; then
    rm -f "$COMPLETIONS_DIR"/*(N)
  else
    mkdir -p "$COMPLETIONS_DIR" || { _fail "cannot create $COMPLETIONS_DIR"; return 0 }
  fi

  # Extract tool entries: name<TAB>type<TAB>cmd_joined<TAB>source<TAB>output
  # Commands joined with | since they're simple tool invocations
  local entries
  entries=$(echo "$config_json" | python3 -c "
import json, sys
config = json.load(sys.stdin)
for t in config.get('completions', {}).get('tools', []):
    print(t['name'],
          t.get('type', 'default'),
          '|'.join(t.get('command', [])),
          t.get('source', ''),
          t.get('output', ''),
          sep='\t')
" 2>/dev/null) || return 0

  [[ -z "$entries" ]] && return 0

  echo "$entries" | while IFS=$'\t' read -r name tool_type cmd_str source output; do
    _has "$name" || continue

    case "$tool_type" in
      prebuilt)
        local bin_path
        bin_path="$(command -v "$name")"
        local src="${bin_path:h}/$source"
        if [[ -f "$src" ]]; then
          cp "$src" "$COMPLETIONS_DIR/_$name" && _ok "$name (pre-built)" || _fail "$name: copy failed"
        fi
        ;;
      sourced)
        local -a cmd=("${(@s:|:)cmd_str}")
        local output_path="$DOTFILES/$output"
        mkdir -p "${output_path:h}"
        local result
        if result=$("${cmd[@]}" 2>&1) && [[ -n "$result" ]]; then
          printf '%s' "$result" > "$output_path" && _ok "$name (sourced)" || _fail "$name: write failed"
        else
          _fail "$name: ${result[(f)1]:-empty output}"
        fi
        ;;
      *)
        local -a cmd
        if [[ -n "$cmd_str" ]]; then
          cmd=("${(@s:|:)cmd_str}")
        else
          cmd=("$name" "completion" "zsh")
        fi
        local result
        if result=$("${cmd[@]}" 2>&1) && [[ -n "$result" ]]; then
          printf '%s' "$result" > "$COMPLETIONS_DIR/_$name" && _ok "$name" || _fail "$name: write failed"
        else
          _fail "$name: ${result[(f)1]:-empty output}"
        fi
        ;;
    esac
  done
}

# ─── Cache cleanup ───────────────────────────────────────────────────────────

_clear_caches() {
  _step "clearing zsh caches..."
  rm -f ~/.cache/zsh/eval/*.zsh(N) ~/.cache/zsh/eval/*.zwc(N)
  rm -f ~/.config/zsh/conf.d/*.zwc(N)
  rm -f ~/.zcompdump
  _ok "zsh caches cleared (next shell will rebuild)"
}

# ─── Main ────────────────────────────────────────────────────────────────────

_hdr "SYSTEM UPDATE"

_link

# Parse config once, reuse for fonts + completions
local config_json
config_json=$(_config_json)

_check_auth
_install_fonts "$config_json"

_sudo_setup || true

_update_apt
_update_dnf
_update_brew
_update_mise
_update_claude
_sync_tmux_plugins

_sudo_teardown

_hdr "REGENERATING ZSH COMPLETIONS"
_regen_completions "$config_json"

_clear_caches

# ─── Summary ─────────────────────────────────────────────────────────────────

_hdr "STATUS"

local -a manual_steps=()
_has gh && (( ! GH_OK )) && manual_steps+=("gh auth login")
_has op && (( ! OP_OK )) && manual_steps+=("1Password: Settings → Developer → CLI Integration, then 'op plugin init'")

if (( ${#manual_steps} == 0 )); then
  _ok "all good"
else
  _warn "remaining manual steps:"
  for step in "${manual_steps[@]}"; do
    printf '    \033[90m·\033[0m %s\n' "$step"
  done
fi

echo
if (( ANY_FAILED )); then
  printf '\033[1;33m/// .SYSTEM UPDATE COMPLETE (with errors)\033[0m\n'
else
  printf '\033[1m/// .SYSTEM UPDATE COMPLETE\033[0m\n'
fi
echo
