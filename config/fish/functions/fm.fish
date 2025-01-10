function fm
    git merge (git --no-pager branch --all --sort=-committerdate | fzf | tr -d '[:space:]')
end
