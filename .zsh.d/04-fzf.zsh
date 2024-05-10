## handy stuff
eval "$(fzf --zsh)"

# bindkey "ç" fzf-cd-widget

export FZF_DEFAULT_OPTS="--layout=reverse --inline-info --height 40% --preview 'cat {}'"

FZF_CMD="fzf"
FZF_ARGS=""

# fco - checkout git branch (including remote branches), sorted by most recent commit, limit 30 last branches
fco() {
  local branches branch
  branches=$(git for-each-ref --count=30 --sort=-committerdate refs/heads/ --format="%(refname:short)") &&
    branch=$(echo "$branches" |
      $FZF_CMD $FZF_ARGS -d $((2 + $(wc -l <<<"$branches"))) +m) &&
    git checkout $(echo "$branch" | sed "s/.* //" | sed "s#remotes/[^/]*/##")
}

# fco - merge git branch (including remote branches), sorted by most recent commit, limit 30 last branches
fm() {
  local branches branch
  branches=$(git for-each-ref --count=30 --sort=-committerdate refs/heads/ --format="%(refname:short)") &&
    branch=$(echo "$branches" |
      $FZF_CMD $FZF_ARGS -d $((2 + $(wc -l <<<"$branches"))) +m) &&
    git merge $(echo "$branch" | sed "s/.* //" | sed "s#remotes/[^/]*/##")
}

# fco_preview - checkout git branch/tag, with a preview showing the commits between the tag/branch and HEAD
fcop() {
  local tags branches target
  branches=$(
    git --no-pager branch --all --sort=-committerdate \
      --format="%(if)%(HEAD)%(then)%(else)%(if:equals=HEAD)%(refname:strip=3)%(then)%(else)%1B[0;34;1mbranch%09%1B[m%(refname:short)%(end)%(end)" |
      sed '/^$/d'
  ) || return
  tags=$(
    git --no-pager tag | awk '{print "\x1b[35;1mtag\x1b[m\t" $1}'
  ) || return
  target=$(
    (
      echo "$branches"
      echo "$tags"
    ) |
      fzf --no-hscroll --no-multi -n 2 \
        --ansi --preview="git --no-pager log -150 --pretty=format:%s '..{2}'"
  ) || return
  git checkout $(awk '{print $2}' <<<"$target")
}

# fcoc - checkout git commit
fcoc() {
  local commits commit
  commits=$(git log --pretty=oneline --abbrev-commit --reverse) &&
    commit=$(echo "$commits" | fzf --tac +s +m -e) &&
    git checkout $(echo "$commit" | sed "s/ .*//")
}

## ASDF

## BREW

# Install (one or multiple) selected application(s)
# using "brew search" as source input
# mnemonic [B]rew [I]nstall [P]lugin
bip() {
  local inst=$(brew search | fzf -m)

  if [[ $inst ]]; then
    for prog in $(echo $inst); do
      brew install $prog
    done
  fi
}
# Update (one or multiple) selected application(s)
# mnemonic [B]rew [U]pdate [P]lugin
bup() {
  local upd=$(brew leaves | fzf -m)

  if [[ $upd ]]; then
    for prog in $(echo $upd); do
      brew upgrade $prog
    done
  fi
}
# Delete (one or multiple) selected application(s)
# mnemonic [B]rew [R]lean [P]lugin (e.g. uninstall)
brp() {
  local uninst=$(brew leaves | fzf -m)

  if [[ $uninst ]]; then
    for prog in $(echo $uninst); do
      brew uninstall $prog
    done
  fi
}
# Install or open the webpage for the selected application
# using brew cask search as input source
# and display a info quickview window for the currently marked application
bcip() {
  local token
  token=$(brew cask search | $FZF_CMD $FZF_ARGS --query="$1" +m --preview 'brew cask info {}')

  if [ "x$token" != "x" ]; then
    echo "(I)nstall or open the (h)omepage of $token"
    read input
    if [ $input = "i" ] || [ $input = "I" ]; then
      brew cask install $token
    fi
    if [ $input = "h" ] || [ $input = "H" ]; then
      brew cask home $token
    fi
  fi
}
# Uninstall or open the webpage for the selected application
# using brew list as input source (all brew cask installed applications)
# and display a info quickview window for the currently marked application
bcrp() {
  local token
  token=$(brew cask list | $FZF_CMD $FZF_ARGS --query="$1" +m --preview 'brew cask info {}')

  if [ "x$token" != "x" ]; then
    echo "(U)ninstall or open the (h)omepage of $token"
    read input
    if [ $input = "u" ] || [ $input = "U" ]; then
      brew cask uninstall $token
    fi
    if [ $input = "h" ] || [ $token = "h" ]; then
      brew cask home $token
    fi
  fi
}

# GIT heart FZF
# -------------

is_in_git_repo() {
  git rev-parse HEAD >/dev/null 2>&1
}

fzf-down() {
  fzf --height 50% "$@" --border
}
