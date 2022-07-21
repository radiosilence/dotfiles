if is_cmd pyenv; then
  export PYENV_VIRTUALENV_DISABLE_PROMPT=1
  eval "$(pyenv init -)"
  eval "$(pyenv init --path)"
fi
