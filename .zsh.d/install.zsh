link_dotfile() {
  [ -e ~/$1 ] && return
  [[ $1 == *.git || $1 == .gitignore || $1 = "." || $1 = ".." || $1 = ".vscode" || $1 == ".sonarlint" ]] && return

  echo $PWD/$1

  if [ -v SSH_TTY ] && [ $1 = ".tmux.conf" ]; then
    echo "skipping .tmux.conf because on ssh"
    return
  fi

  echo "linking $PWD/$1 -> ~/$1"
  ln -s $PWD/$1 ~/$1
}

install_dotfiles() {
  . ~/.dotfiles-dir
  [ ! -d "$DOTFILES" ] && return
  echo "installing from $DOTFILES..."
  (
    cd $DOTFILES
    for file in .*; do
      link_dotfile $file
    done

    antibody bundle <~/.zsh-plugins >~/.zsh-plugins.sh
  )
}
