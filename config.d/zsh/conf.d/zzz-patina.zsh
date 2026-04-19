# zsh-patina — Rust-backed syntax highlighter (mise-managed).
# Loaded last so it wraps every ZLE widget the earlier plugins
# installed.
#
# Upstream documents "Do not cache or source this file manually" —
# the activate output hard-codes the binary path and needs to
# re-generate whenever mise switches versions.  So no _cached_eval.
command -v zsh-patina >/dev/null || return

eval "$(zsh-patina activate)"
