command -v omp >/dev/null || return

# omp / o — auto-pick the profile for $PWD from ~/.config/ai-profiles/omp.yaml.
# ~/.omp is omp's native dir; only override PI_CONFIG_DIR (resolved under $HOME) for a
# real isolated profile (e.g. ~/.omp-personal). No config / no matching root -> native.
omp() {
  local dir args
  IFS=$'\t' read -r dir args < <(_ai_profile ~/.config/ai-profiles/omp.yaml)
  if [[ -n $dir && $dir != $HOME/.omp ]]; then
    PI_CONFIG_DIR="${dir#$HOME/}" command omp --auto-approve ${=args} "$@"
  else
    command omp --auto-approve ${=args} "$@"
  fi
}
alias o=omp

# ojc — force the PERSONAL profile regardless of cwd. First run: `ojc` then `/login`.
ojc() {
  PI_CONFIG_DIR=".omp-personal" command omp --auto-approve "$@"
}
