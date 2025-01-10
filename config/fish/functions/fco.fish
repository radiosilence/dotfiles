# gch() {
#  git checkout “$(git branch — all | fzf| tr -d ‘[:space:]’)”
# }

function fco
    git checkout (git branch --all | fzf | tr -d '[:space:]')
end
