[[ -f ~/.config/op/plugins.sh ]] && source ~/.config/op/plugins.sh

# buf: BUF_TOKEN injected per-invocation via op run (inline ref, nothing on
# disk). Only BSR-authed subcommands (push, remote generate) actually use it.
if command -v buf >/dev/null && command -v op >/dev/null; then
  buf() {
    op run --no-masking \
      --env-file=<(print 'BUF_TOKEN=op://Personal/buf.build/token') \
      -- command buf "$@"
  }
fi

# npm registry auth — JIT-inject the npmjs.org token into the package-manager
# process so it expands ${NPM_AUTH_TOKEN} in .npmrc. Token lives only in that
# subprocess env: nothing on disk, nothing parked in the parent shell. op's
# session cache keeps it warm (Touch ID only on first use / after timeout).
# Only registry-touching verbs are wrapped — script-runners (nr/nd/aubr) and
# uninstall (nun) stay bare to skip the op lookup. Caveat: auth only flows
# through these wrappers; raw pnpm/npm won't inherit the token.
if command -v op >/dev/null; then
  _npm_op() {
    op run --no-masking \
      --env-file=<(print 'NPM_AUTH_TOKEN=op://Personal/npm/token') \
      -- command "$@"
  }
  for _verb in ni nci nup nlx na aube aubx; do
    functions[$_verb]="_npm_op $_verb \"\$@\""
  done
  unset _verb
fi