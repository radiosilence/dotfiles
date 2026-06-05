# Lima payload-detonation sandbox ("jail").
# Template + full runbook/warnings: ~/.config/lima/isolated.yaml
# One fresh box per sample. Host fs is invisible to it except ~/lima-jail <-> /jail.

export JAIL_TEMPLATE="$HOME/.config/lima/isolated.yaml"
export JAIL_DROP="$HOME/lima-jail"

# Burn the old box and build a clean one (config changes only land on fresh boot).
jail-rebuild() {
  limactl delete -f jail 2>/dev/null
  mkdir -p "$JAIL_DROP"
  limactl start --name=jail "$JAIL_TEMPLATE" --tty=false
}

# Shell into the box.
alias jail-shell='limactl shell jail'

# Drop file(s) into the quarantine mount the guest can see.
jail-send() { cp -R "$@" "$JAIL_DROP"/; }

# Open the capture on the host (Wireshark), where it's outside the blast radius.
alias jail-pcap='open "$JAIL_DROP/capture.pcap"'

# Mint a throwaway OAuth token into $JAIL_TOKEN (interactive once per shell).
# setup-token emits a banner + the token; we grep out just the sk-ant-oat... bit.
# Runs on the HOST (needs a browser); only the clean token gets injected later.
jail-mint() {
  local tok
  echo "minting throwaway token on host (revoke it when done)…" >&2
  tok=$(claude setup-token | grep -oE 'sk-ant-oat[A-Za-z0-9_-]+' | tail -1)
  if [[ -z "$tok" ]]; then
    echo "no token captured — run 'claude setup-token' by hand, then: export JAIL_TOKEN=<token>" >&2
    return 1
  fi
  export JAIL_TOKEN="$tok"
  echo "minted ${tok:0:16}… (cached in \$JAIL_TOKEN for this shell)" >&2
}

# Run Claude IN the box as an agent. Auto-mints on first use (cached in
# $JAIL_TOKEN), then injects the token into claude's process env inside the
# guest -- never written to /jail, never in the committed YAML.
# Agent use is HEADLESS -- pass -p, or the TUI hits the interactive auth gate:
#   jail-claude --dangerously-skip-permissions -p "triage /jail/sample"
# Revoke the token in settings when the session's done.
jail-claude() {
  [[ -n "$JAIL_TOKEN" ]] || jail-mint || return 1
  limactl shell jail -- env CLAUDE_CODE_OAUTH_TOKEN="$JAIL_TOKEN" \
    bash -lc 'cd /jail && exec claude "$@"' _ "$@"
}

# Burn it down.
alias jail-nuke='limactl delete -f jail'
