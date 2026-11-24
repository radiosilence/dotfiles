# Zsh configuration

# lig runs the interactive shell inside its pty to draw a completion popup.
# This has to come first: it re-execs the shell, so anything above runs twice.
# The `latest` path works before mise activates and survives upgrades; the
# LIG_TTY check skips the fork in the inner shell, where pre is a no-op.
# >>> lig pre >>>
if [[ $LIG_TTY != $TTY && -x ~/.local/share/mise/installs/lig/latest/lig ]]; then
  eval "$(~/.local/share/mise/installs/lig/latest/lig init zsh pre)"
fi
# <<< lig pre <<<
# Files in conf.d are loaded in alphabetical order (use numeric prefixes for ordering)

for config in ~/.config/zsh/conf.d/*.zsh; do
  [[ -r "$config" ]] && source "$config"
done

# Zed MCP secrets
[[ -f ~/.config/zed/.secrets ]] && source ~/.config/zed/.secrets

# After plugins and prompt, so lig's widgets wrap the final ZLE setup. The
# cache is named after the resolved version: mise keeps the release's mtime, so
# an mtime check would not notice an upgrade.
# >>> lig post >>>
_lig=~/.local/share/mise/installs/lig/latest/lig
if [[ -n $LIG_TTY && $LIG_TTY == $TTY && -x $_lig ]]; then
  _cached_eval "lig-${_lig:A:h:t}" "$_lig init zsh post"
fi
unset _lig
# <<< lig post <<<
