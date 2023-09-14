# aliases
alias youtube-'dl=noglob youtube-dl '
alias curl='noglob curl '
alias http='noglob http '
alias ip='ip -c -br '
alias szrc='. ~/.zshrc'
alias k='k --no-vcs -A -h '
alias html2pdf='docker run --rm -v $(pwd):/converted/ arachnysdocker/athenapdf athenapdf '

if is_macos; then
  alias pg_start="launchctl load ~/Library/LaunchAgents/homebrew.mxcl.postgresql.plist"
  alias pg_stop="launchctl unload ~/Library/LaunchAgents/homebrew.mxcl.postgresql.plist"
fi

if is_cmd lsd; then
  alias ls='lsd '
  alias ll='lsd -l '
  alias tree='lsd --tree'
elif is_cmd exa; then
  alias ls='exa '
  alias ll='exa -l '
  alias tree='exa --tree'
fi

if is_cmd rg; then
  alias grep='rg '
fi

if is_cmd tidy-viewer; then
  alias tv='tidy-viewer'
fi
