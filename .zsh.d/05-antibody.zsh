#!/usr/local/bin zsh

# antibody
update_plugins() {
  rm ~/.zsh-plugins.sh || echo "no plugins found"
  antibody bundle < ~/.zsh-plugins > ~/.zsh-plugins.sh
  source ~/.zsh-plugins.sh
}

# compatibility
unalias k 2>/dev/null

source ~/.zsh-plugins.sh
