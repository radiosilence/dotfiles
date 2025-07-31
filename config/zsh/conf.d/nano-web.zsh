# Nano Web configuration
command -v nano-web >/dev/null || return

alias serve='nano-web serve --dev --port=3000'
