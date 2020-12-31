my_fun() {
  echo "poop"
}

is_cmd() {
  command -v $1 &>/dev/null
}

if is_cmd gpg; then
  echo "command -v my_fun exists!"
else
  echo "command -v my_fun DOES NOT exists!"
fi

if [[ -x "$(which my_fun)" ]]; then
  echo "which my_fun exists!"
else
  echo "which my_fun DOES NOT exists!"
fi

if is_cmd ls; then
  echo "command -v ls exists!"
else
  echo "command -v ls DOES NOT exists!"
fi

if [[ -x "$(which ls)" ]]; then
  echo "which ls exists!"
else
  echo "which ls DOES NOT exists!"
fi

if is_cmd ssh; then
  echo "command -v ssh exists!"
else
  echo "command -v ssh DOES NOT exists!"
fi

if [[ -x "$(which ssh)" ]]; then
  echo "which ssh exists!"
else
  echo "which ssh DOES NOT exists!"
fi

if is_cmd asdkjhaslkdjhsakjdhasd; then
  echo "command -v asdkjhaslkdjhsakjdhasd exists!"
else
  echo "command -v ssh DOES NOT exists!"
fi

if [[ -x "$(which asdkjhaslkdjhsakjdhasd)" ]]; then
  echo "which asdkjhaslkdjhsakjdhasd exists!"
else
  echo "which asdkjhaslkdjhsakjdhasd DOES NOT exists!"
fi
