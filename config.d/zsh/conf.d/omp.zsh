command -v omp >/dev/null || return

# Profile selection is mise's job (PI_CONFIG_DIR in mise conf.d, unset in work roots).
alias o='omp --auto-approve '

# ojc — force the PERSONAL profile regardless of cwd. First run: `ojc` then `/login`.
ojc() {
  PI_CONFIG_DIR=".omp-personal" command omp --auto-approve "$@"
}
