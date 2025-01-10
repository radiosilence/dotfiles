function fm
    git rebase (git --no-pager branch --all --sort=-committerdate | fzf | tr -d '[:space:]')
end
