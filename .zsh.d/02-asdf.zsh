# asdf
if [ -f ~/.asdf/asdf.sh ]; then
  . ~/.asdf/asdf.sh
  fpath=(${ASDF_DIR}/completions $fpath)
fi
