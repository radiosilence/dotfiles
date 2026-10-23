command -v just >/dev/null || return

# just's generated completer offers every flag alongside the recipes, and the
# flags sort first. Ask it for the same candidates, but offer flags only once
# the word starts with "-", as git and most tools do.
_just_recipes_first() {
  local -a completions flags other dirs
  completions=("${(@f)$(
    _CLAP_IFS=$'\n' _CLAP_COMPLETE_INDEX=$((CURRENT - 1)) JUST_COMPLETE=zsh \
      just -- "${words[@]}" 2>/dev/null
  )}")

  local completion value
  for completion in $completions; do
    value=${completion%%:*}
    case $value in
      -*) flags+=("$completion") ;;
      */) dirs+=("${value%/}${completion#$value}") ;;
      ?*) other+=("$completion") ;;
    esac
  done

  if [[ $PREFIX == -* || ( -z $other && -z $dirs ) ]]; then
    _describe -t options 'flags' flags
  else
    (( $#dirs )) && _describe -t directories 'directories' dirs -S '/' -r '/'
    (( $#other )) && _describe -t recipes 'recipes' other
  fi
}
compdef _just_recipes_first just
