# asdf
if [ -f ~/.asdf/asdf.sh ]; then
  . ~/.asdf/asdf.sh
  fpath=(${ASDF_DIR}/completions $fpath)
fi

if [ -f /opt/homebrew/opt/asdf/asdf.sh ]; then
  . /opt/homebrew/opt/asdf/asdf.sh
  fpath=(${ASDF_DIR}/completions $fpath)
fi
