# Kubernetes configuration
command -v kubecolor >/dev/null || return

alias kubectl='kubecolor'

# Make kubectl completions work with kubecolor alias
compdef kubecolor=kubectl

alias kgp='kubecolor get pods --force-colors | rg '
alias kgpw='kubecolor get pods -w --force-colors | rg '
klg() {
  kubectl logs -f "$@"
}

# Custom completion for klg - shows pods with fzf-tab
_klg() {
  local -a pods
  pods=(${(f)"$(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)"})
  _describe 'pod' pods
}
compdef _klg klg

# fzf-tab preview for klg - show pod details with color
zstyle ':fzf-tab:complete:klg:*' fzf-preview 'kubecolor get pod $word -o wide --force-colors 2>/dev/null'

ksh() {
  kubectl exec -it $1 -- /bin/sh
}
