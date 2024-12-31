#/usr/bin/env fish

if command -v bat >/dev/null 2>&1
    alias bat="bat \
        --map-syntax='*.kubeconfig:YAML' \
        --map-syntax='config:YAML'"
    
    alias cat="bat"
    
    alias fzf="fzf \
        --preview 'bat --color=always --style=numbers --line-range=:500 {}'"
end