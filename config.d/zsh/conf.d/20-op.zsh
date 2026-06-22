[[ -f ~/.config/op/plugins.sh ]] && source ~/.config/op/plugins.sh

# NPM_AUTH_TOKEN / BUF_TOKEN are low-risk (read-only / BSR-scoped) standing env
# vars, parked in the gitignored ~/.config/mise/conf.d/secrets.toml and exported
# by mise. The previous op-run-per-invocation wrappers re-prompted Touch ID on
# every call (op uses system-auth with no session caching), which was unusable
# for commands you run constantly. Parking a scoped token beats that friction.