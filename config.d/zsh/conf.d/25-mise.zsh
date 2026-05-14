# Mise (runtime version manager)
command -v mise >/dev/null || return

# mise's hook_env hits GitHub for "latest" version metadata on shell startup.
# Without GITHUB_TOKEN it rate-limits hard during bootstrap — every new shell
# hammers the API and fails. Go offline if we have no token yet (typically
# pre-`gh auth login`). MISE_OFFLINE keeps installed tools working; only
# blocks network fetches. 20-github.zsh sets $GITHUB_TOKEN earlier if gh
# is authed, so this guard only trips during the half-bootstrapped window.
[[ -z $GITHUB_TOKEN ]] && export MISE_OFFLINE=1

_cached_eval "mise" "mise activate zsh" "$(command -v mise)"

alias m='mise'
alias mi='mise i'
