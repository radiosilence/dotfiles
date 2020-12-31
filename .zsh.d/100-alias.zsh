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
