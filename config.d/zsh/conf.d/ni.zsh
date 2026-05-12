# Dynamic `na` completion: detect the project's package manager from its
# lockfile at cd-time, then bind _na to that pm's completer. Cheap because
# the lockfile walk is pure zsh stat() calls — no subprocesses, no `ni --agent`
# (which would shell out to node on every tab press).

command -v ni >/dev/null || return

_na_agent_for_cwd() {
  local dir=$PWD
  while [[ $dir != / && -n $dir ]]; do
    [[ -e $dir/pnpm-lock.yaml ]]                 && { print pnpm; return }
    [[ -e $dir/bun.lockb || -e $dir/bun.lock ]]  && { print bun;  return }
    [[ -e $dir/yarn.lock ]]                      && { print yarn; return }
    [[ -e $dir/package-lock.json ]]              && { print npm;  return }
    [[ -e $dir/deno.lock || -e $dir/deno.json ]] && { print deno; return }
    dir=${dir:h}
  done
  print pnpm  # default when no lockfile found
}

typeset -g _na_agent=pnpm  # updated at chpwd; consulted by _na

_na() {
  # Swap "na" → actual agent in words[] so completers that branch on the
  # command name (e.g. pnpm-completion-server) see what they expect.
  words[1]=$_na_agent
  _$_na_agent
}

_na_refresh_completion() {
  _na_agent=$(_na_agent_for_cwd)
  (( $+functions[_$_na_agent] )) || _na_agent=pnpm
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _na_refresh_completion
_na_refresh_completion  # initial detection
compdef _na na
