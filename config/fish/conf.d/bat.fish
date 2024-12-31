#/usr/bin/env fish

if type -q bat
    alias bat="bat \
        --map-syntax='*.kubeconfig:YAML' \
        --map-syntax='config:YAML'"

    alias cat="bat"

    alias fzf="fzf \
        --preview 'bat --color=always --style=numbers --line-range=:500 {}'"
end
