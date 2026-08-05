# 1Password's SSH agent is wired up via IdentityAgent in ~/.ssh/config, which
# openssh reads and libgit2 does not. Anything embedding libgit2 (sheldon, and
# git clients that aren't the git binary) therefore falls back to $SSH_AUTH_SOCK
# — on macOS that is launchd's agent, which holds no identities. Combined with
# the url.insteadOf rewrite in ~/.gitconfig, every HTTPS clone becomes SSH and
# then fails to authenticate.
_op_ssh_sock="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
[[ -S $_op_ssh_sock ]] && export SSH_AUTH_SOCK="$_op_ssh_sock"
unset _op_ssh_sock

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