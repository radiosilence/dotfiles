# antibody
update_plugins() {
  echo "updating plugins..."

  rm ~/.zsh-plugins.sh || echo "no plugins found"
  antibody bundle <~/.zsh-plugins >~/.zsh-plugins.sh
  . ~/.zsh-plugins.sh
}

# compatibility
unalias k 2>/dev/null

. ~/.zsh-plugins.sh
