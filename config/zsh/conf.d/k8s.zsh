# Kubernetes configuration
command -v kubecolor >/dev/null || return

alias kubectl='kubecolor'

# Make kubectl completions work with kubecolor alias
compdef kubecolor=kubectl

alias kgp='kubectl get pods | grep '
alias kgpw='kubectl get pods -w | grep '
alias klg='kubectl logs -f '

ksh() {
  kubectl exec -it $1 -- /bin/sh
}
