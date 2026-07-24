command -v omp >/dev/null || return

alias omp='omp --auto-approve'

# ojc — run omp (Oh My Pi) as the PERSONAL account.
#
# PI_CONFIG_DIR is a dirname under $HOME (omp's equivalent of CLAUDE_CONFIG_DIR).
# It gives the personal profile its own OAuth login, settings, sessions and MCP
# servers, fully isolated from the default work profile in ~/.omp. It's a real
# browser /login, so subscription-only routing (Claude Pro/Max OAuth) works.
# First run: `ojc` then `/login` with the personal account.
export OMP_PERSONAL_DIR="${OMP_PERSONAL_DIR:-.omp-personal}"

ojc() {
  PI_CONFIG_DIR="$OMP_PERSONAL_DIR" command omp --auto-approve "$@"
}
