function fm
    git merge (git for-each-ref --sort=-committerdate refs/heads/ --format='%(committerdate:iso8601) %(refname:short)' | fzf | awk '{ print $NF }')
end
