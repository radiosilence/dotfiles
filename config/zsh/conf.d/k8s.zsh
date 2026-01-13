# Kubernetes configuration
command -v kubecolor >/dev/null || return

alias kubectl='kubecolor'

# Make kubectl completions work with kubecolor alias
compdef kubecolor=kubectl

# Pod completion helper
_k8s_pods() {
  local -a pods
  pods=(${(f)"$(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)"})
  _describe 'pod' pods
}

# fzf-tab pod preview (reused across commands)
zstyle ':fzf-tab:complete:klg:*' fzf-preview 'kubecolor get pod $word -o wide --force-colors 2>/dev/null'
zstyle ':fzf-tab:complete:ksh:*' fzf-preview 'kubecolor get pod $word -o wide --force-colors 2>/dev/null'
zstyle ':fzf-tab:complete:kgp:*' fzf-preview 'kubecolor get pod $word -o wide --force-colors 2>/dev/null'
zstyle ':fzf-tab:complete:kgpw:*' fzf-preview 'kubecolor get pod $word -o wide --force-colors 2>/dev/null'

# klg - kubectl logs -f
klg() { kubectl logs -f "$@" }
compdef _k8s_pods klg

# ksh - kubectl exec shell
ksh() { kubectl exec -it "$1" -- /bin/sh }
compdef _k8s_pods ksh

# kgp - get pods with grep
kgp() { kubecolor get pods --force-colors | rg "$@" }
compdef _k8s_pods kgp

# kgpw - get pods watch with grep
kgpw() { kubecolor get pods -w --force-colors | rg "$@" }
compdef _k8s_pods kgpw

# ConfigMap completion helper
_k8s_configmaps() {
  local -a cms
  cms=(${(f)"$(kubectl get configmaps -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)"})
  _describe 'configmap' cms
}

# Secret completion helper
_k8s_secrets() {
  local -a secrets
  secrets=(${(f)"$(kubectl get secrets -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)"})
  _describe 'secret' secrets
}

# fzf-tab previews for configmaps and secrets
zstyle ':fzf-tab:complete:kcme:*' fzf-preview 'kubecolor get configmap $word -o yaml --force-colors 2>/dev/null | head -50'
zstyle ':fzf-tab:complete:ksv:*' fzf-preview 'kubectl get secret $word -o jsonpath="{.data}" 2>/dev/null | tr "," "\n" | cut -d: -f1'

# kcme - edit configmap
kcme() { kubectl edit configmap "$@" }
compdef _k8s_configmaps kcme

# ksv - view secret (decoded)
ksv() {
  kubectl get secret "$1" -o json | jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"'
}
compdef _k8s_secrets ksv

# kkp - kill pod(s) with fzf multi-select
kkp() {
  local pods
  pods=$(kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | \
    fzf --multi --preview 'kubecolor get pod {} -o wide --force-colors 2>/dev/null' \
        --header 'TAB to select multiple, ENTER to delete')
  [[ -n "$pods" ]] && echo "$pods" | xargs kubectl delete pod
}
