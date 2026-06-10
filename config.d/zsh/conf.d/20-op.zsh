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