command -v claude >/dev/null || return

alias claude='claude --dangerously-skip-permissions'
alias c='claude --dangerously-skip-permissions'

# ctoken [--personal|--work] | off
#
# Mint a Claude OAuth token and export CLAUDE_CODE_OAUTH_TOKEN into THIS shell,
# so `claude` here runs as that account instead of the default work login —
# personal sessions without burning work tokens. Starship flags it in the prompt
# (see [env_var.CLAUDE_CODE_OAUTH_TOKEN] in the starship config).
#
# `claude setup-token` is an interactive TUI that renders the token on screen —
# it can't be piped (Ink won't draw into a pipe, so capturing stdout just hangs).
# So we run it attached to the terminal and pick the token up afterwards from the
# clipboard, falling back to a paste.
#
# The login must happen in the browser where you're signed into the right
# Anthropic account. BrowserSchedule is the default browser and routes by URL, so
# we force it: --personal opens Helium, --work opens Firefox (whatever the
# [browsers] block in browser-schedule's config maps them to). Defaults to
# --personal since that's the whole point. `ctoken off` clears the token.
ctoken() {
  if [[ "$1" == "off" ]]; then
    unset CLAUDE_CODE_OAUTH_TOKEN
    echo "personal token cleared, choom"
    return
  fi

  local key="${1:---personal}"; key="${key#--}"
  case "$key" in
    personal|work) ;;
    *) echo "usage: ctoken [--personal|--work] | off"; return 1 ;;
  esac

  # Browser app name from browser-schedule's [browsers] block, so it stays in
  # sync with wherever BrowserSchedule routes personal/work.
  local cfg="$HOME/.dotfiles/config.d/browser-schedule/config.toml"
  local app
  app=$(awk -v k="$key" '
    /^\[/{ inb = ($0 == "[browsers]") }
    inb && $1 == k { gsub(/"/, "", $3); print $3; exit }
  ' "$cfg")
  if [[ -z "$app" ]]; then
    echo "couldn't find [$key] browser in $cfg"; return 1
  fi

  echo "logging in via $app — copy the token it shows before you exit the flow"
  # Clear the clipboard first: setup-token only ever renders the token in its TUI
  # (no stdout, no auto-copy), and shows it once. Clearing means we can only pick
  # up a token you copied THIS run — never silently reuse a stale one.
  printf '' | pbcopy 2>/dev/null

  # command = bypass the `claude` alias; BROWSER wrapper forces the OAuth flow
  # into $app. Attached to the terminal so the TUI works and the browser opens.
  OPEN_URL_APP="$app" BROWSER="$HOME/.dotfiles/scripts/open-url-in" \
    command claude setup-token

  # Prefer the clipboard (your Cmd-C on the displayed token), else paste.
  local tok="$(pbpaste 2>/dev/null)"
  if [[ "$tok" != sk-ant-oat01-* ]]; then
    printf 'paste token: '
    read -rs tok; echo
  fi
  if [[ "$tok" != sk-ant-oat01-* ]]; then
    echo "no valid oat token — bailed"; return 1
  fi
  export CLAUDE_CODE_OAUTH_TOKEN="$tok"
  echo "$key token loaded"
}

npm-add-safe() {
  claude --allow-dangerously-skip-permissions -p "please checkout the git repo for npm package $1, audit the code and it's dependencies, and if it seems reasonable, run npm add $1. You are NOT being run interactively, if the package seems safe, add it, do not ask questions."
}
