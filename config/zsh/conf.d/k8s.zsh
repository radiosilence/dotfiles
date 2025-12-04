# Kubernetes configuration
command -v kubecolor >/dev/null || return

alias kubectl='kubecolor'

# Make kubectl completions work with kubecolor alias
compdef kubecolor=kubectl

alias kgp='kubecolor get pods --force-colors | rg '
alias kgpw='kubecolor get pods -w --force-colors | rg '
alias klg='kubectl logs -f '

ksh() {
  kubectl exec -it $1 -- /bin/sh
}
