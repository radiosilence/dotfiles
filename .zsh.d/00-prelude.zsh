# opts
setopt no_share_history
setopt interactivecomments

# autoloads
autoload -Uz compinit
autoload -U add-zsh-hook

# config
ZSH_AUTOSUGGEST_USE_ASYNC=false
#
PURE_PROMPT_SYMBOL='→'

# binds
bindkey -e
bindkey "\e[3~" delete-char

bindkey '^\e[\e[1;3C' emacs-forward-word
bindkey '^\e[\e[1;3D' emacs-backward-word
bindkey "^[b" emacs-forward-word
bindkey '^[f' emacs-backward-word

# prezto modules config
zstyle ':prezto:module:gnu-utility' prefix 'g'
zstyle ':prezto:module:ssh:load' identities 'id_ed25519' 'id_rsa' 'id_github'

# editor
if is_cmd code-insiders; then
  export EDITOR="code-insiders --wait"
elif is_cmd code; then
  export EDITOR="code --wait"
else
  export EDITOR=vim
fi

# it is colourful damnit
export CLICOLOR=1