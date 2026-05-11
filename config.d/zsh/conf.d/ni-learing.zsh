# @antfu/ni — package-manager-agnostic shortcuts.
# Built-ins: ni / nr / nlx / nun / nup / nci / na / nd
# Config at ~/.config/ni/nirc (NI_CONFIG_FILE) enables useSfw=true.

command -v ni >/dev/null || return

# Install flag shortcuts (ni handles -D / -w / -g across all backends)
alias niD='ni -D'        # devDependency
alias niW='ni -w'        # write to workspace root package.json
alias niDW='ni -wD'      # workspace root + dev
alias niG='ni -g'        # global
alias niP='ni -P'        # production install (no devDeps)
alias nif='ni --frozen'  # frozen lockfile (use nci for the canonical form)

# nr script shortcuts. Avoid clobbering ni's `nd` (dedupe), so use nr-prefixed.
alias nrd='nr dev'
alias nrb='nr build'
alias nrt='nr test'
alias nrs='nr start'
alias nrl='nr lint'

# Teaching aliases — old pnpm/bun muscle memory just prints the ni equivalent.
# Doesn't run anything: forces you to retype with the right command, which is
# the fastest way to actually retrain. Delete this block once muscle memory wins.
_ni_hint() { print -P "%F{yellow}→ use:%f %B$1%b" }

# bun
alias b='_ni_hint na'
alias bi='_ni_hint ni'
alias bt='_ni_hint nrt'
alias btu='_ni_hint "nr test -u"'
alias ba='_ni_hint "ni <pkg>"'
alias baW='_ni_hint "niW <pkg>"'
alias baD='_ni_hint "niD <pkg>"'
alias baDW='_ni_hint "niDW <pkg>"'
alias bs='_ni_hint "ni && nrs"'

# pnpm
alias p='_ni_hint na'
alias pi='_ni_hint ni'
alias pt='_ni_hint nrt'
alias ptu='_ni_hint "nr test -u"'
alias pa='_ni_hint "ni <pkg>"'
alias paW='_ni_hint "niW <pkg>"'
alias paD='_ni_hint "niD <pkg>"'
alias paDW='_ni_hint "niDW <pkg>"'
alias pn='_ni_hint na'
alias pni='_ni_hint ni'
alias pnr='_ni_hint nr'
alias pnd='_ni_hint nrd'
