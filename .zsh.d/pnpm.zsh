alias p='pnpm '
alias pi='pnpm install'
alias pa='pnpm add '
alias paW='pnpm add -W '
alias paD='pnpm add -D '
alias paDW='pnpm add -DW '

if is_macos; then
  export PNPM_HOME="$HOME/Library/pnpm"
  case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
  esac
fi
