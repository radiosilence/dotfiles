install_dotfiles() {
  if [ -d "$DOTFILES" ]; then
    (
      cd $1 &&
        for file in .*; do
          [ -f $file ] && continue
          [[ $file == *.git* || $file = "." || $file = ".." || $file = ".vscode" || $file == ".sonarlint" ]] && continue
          [[ -f ~/$file ]] && unlink ~/$file
          if [ -v SSH_TTY ] && [ $file = ".tmux.conf" ]; then
            echo "skipping .tmux.conf because on ssh"
            continue
          fi
          echo "linking $file -> ~/$file"
          [[ ! -d ~/$file ]] && ln -s "$PWD/$file" ~/"$file"
        done

      antibody bundle <~/.zsh-plugins >~/.zsh-plugins.sh
    )
  fi
}
