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
