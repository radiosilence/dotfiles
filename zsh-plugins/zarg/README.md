# zarg

Declarative argument parsing for zsh scripts. Declare the interface once and
get parsing, error messages, `--help`, `--version` and completions for zsh,
fish and bash out of it.

The completions are why this exists. A script needs a parser and a compdef, and
hand-written pairs drift apart the moment you add a flag — the parser accepts
something the completion never offers, or worse, the reverse. Deriving both
from one declaration makes that failure mode unrepresentable.

## Install (sheldon)

```toml
[plugins.zarg]
local = "~/.dotfiles/zsh-plugins/zarg"
```

Scripts source it directly rather than relying on the interactive shell, so
they behave the same under `env -i`:

```zsh
source "${0:A:h:h}/zsh-plugins/zarg/zarg.plugin.zsh"
```

## Use

```zsh
zarg_init kill-port 'Kill process listening on specified port'
zarg_flag -n --dry-run 'show what would be killed without doing it'
zarg_opt  -s --signal  'signal to send' default=TERM metavar=SIGNAL \
          values='TERM KILL INT HUP QUIT USR1 USR2'
zarg_arg  port 'port number' required
zarg_go "$@"

(( dry_run )) && ...
kill -$signal $pid
```

Each declaration binds a variable named after its long form, dashes turned to
underscores: `--dry-run` sets `$dry_run` (`0` or `1`), `--signal` sets
`$signal`, the `port` positional sets `$port`. A `variadic` positional sets an
array.

| Builder | Purpose |
| --- | --- |
| `zarg_init <name> <description>` | start a spec |
| `zarg_flag <short> <long> <help>` | boolean, `0` or `1` |
| `zarg_opt <short> <long> <help> [extras]` | takes a value |
| `zarg_arg <name> <help> [extras]` | positional |
| `zarg_go "$@"` | handle built-ins, parse, exit on error |

Extras are `key=value` pairs, or bare words for the boolean ones:

| Extra | On | Meaning |
| --- | --- | --- |
| `default=V` | opt, arg | value when not given |
| `env=VAR` | opt | environment fallback, overridden by the command line |
| `values='a b c'` | opt, arg | allowed set — validated, and offered by every shell |
| `complete=_fn` | opt, arg | zsh completion function |
| `metavar=NAME` | opt | placeholder shown in help |
| `required` | arg | error if absent |
| `variadic` | arg | collect the rest into an array; declare it last |

`zarg_go` exits the script itself for `--help`, `--version` and
`--completions`, and on a parse error. Once it returns, the parse succeeded —
scripts do not check its result.

## Using it from another plugin

Any **script** can, wherever it lives. `wt-core`'s `wtclean` does:

```zsh
source "${0:A:h:h:h}/zarg/zarg.plugin.zsh"

zarg_init wtclean 'Remove worktrees whose PR is merged or closed, keeping anything dirty'
zarg_flag -n --dry-run 'show what would be removed without touching anything'
zarg_go "$@"

local -a args; (( dry_run )) && args=(-n)
_wt_clean $args
```

A plugin script that isn't on `$PATH` needs the `generate:completions:plugin` task rather than the usual one, because `command -v` can't see a command reached through a shell function.

**Not for shell functions.** `zarg_go` calls `exit` for `--help`, `--version` and parse errors — in an interactive function that kills the user's shell rather than the command. It also assigns with `typeset -g`, so parsed values and the `ZARG_*` spec arrays would leak into the session and any two functions using it would clobber each other. This is why `wt` and `wtrm` still parse by hand and register their completions with `compdef` at load time: they must mutate the calling shell, so they cannot be scripts, so zarg is the wrong tool. `wtclean` only garbage-collects, which is why it *is* a script and can use this.

## What you get

Parsing covers `--long value`, `--long=value`, `-s value`, attached shorts
(`-b192`), clustered flags (`-nk`), and `--` to stop option processing.

Bad input is rejected before the script runs, with the closest match offered:

```
$ kill-port --dry-ru 3000
kill-port: unknown option: --dry-ru
  did you mean '--dry-run'?
  try 'kill-port --help'
```

`--version` reports the dotfiles checkout these scripts ship with, since that
is the only version they meaningfully have. Set `ZARG_VERSION` to override.

## Completions

`--completions zsh|fish|bash` writes to stdout. `task generate:completions`
collects the zsh ones into `~/.config/zsh/completions/`.

Fidelity differs by shell, and that is the shells' doing rather than a gap
here: `complete=` names a zsh completion function, so only zsh can honour it —
fish and bash fall back to file completion at that position. Declared value
sets (`values=`) work everywhere.

The emitters live in `completions.zsh` and are sourced only when asked for.
Scripts load zarg on every invocation and generate completions roughly once per
converge, so keeping them out of the hot path is worth the extra file.
