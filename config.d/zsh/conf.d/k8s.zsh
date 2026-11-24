# Kubernetes configuration
command -v kubecolor >/dev/null || return
command -v kubectl >/dev/null || return

alias kubectl='kubecolor'
compdef kubecolor=kubectl 2>/dev/null

# Simple aliases - zsh inherits kubectl completions automatically
alias klg='kubectl logs -f'
alias kcme='kubectl edit configmap'
alias kd='kubectl describe'


# Completion helpers for functions
_k8s_pods() {
  local -a pods
  pods=(${(f)"$(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)"})
  _describe 'pod' pods
}

_k8s_secrets() {
  local -a secrets
  secrets=(${(f)"$(kubectl get secrets -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)"})
  _describe 'secret' secrets
}

# Functions that actually need logic

# ksh - needs -it and shell path
ksh() { kubectl exec -it "$1" -- /bin/sh }
compdef _k8s_pods ksh

# kgp/kgpw - pipe to rg, can't be simple alias
kgp() { kubecolor get pods --force-colors | rg "$@" }
kgpw() { kubecolor get pods -w --force-colors | rg "$@" }
compdef _k8s_pods kgp
compdef _k8s_pods kgpw

# ksv - decode secrets
ksv() {
  kubectl get secret "$1" -o json | jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"'
}
compdef _k8s_secrets ksv

# kkp - interactive pod killer
kkp() {
  local pods
  pods=$(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | \
    fzf --multi --preview 'kubecolor get pod {} -o wide --force-colors 2>/dev/null' \
        --header 'TAB to select multiple, ENTER to delete')
  [[ -n "$pods" ]] && echo "$pods" | xargs kubectl delete pod
}

alias kubectx='kubectl config use-context '
alias kubens='kubectl config set-context --namespace '
