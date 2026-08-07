# zarg

Declarative argument parsing for zsh scripts. Declare the interface once and
get parsing, error messages, `--help`, `--version` and completions for zsh,
fish and bash out of it.

The completions are why this exists. A script needs a parser and a compdef, and
hand-written pairs drift apart the moment you add a flag — the parser accepts
something the completion never offers, or worse, the reverse. Deriving both
from one declaration makes that failure mode unrepresentable.

## A whole script

```zsh
#!/usr/bin/env zsh
# Back up a directory somewhere, with the usual knobs.
set -o pipefail

autoload -Uz zarg

zarg backup 'Back up a directory'
zarg_flag -n --dry-run  'show what would be copied, copy nothing'
zarg_flag -v --verbose  'list every file'
zarg_opt  -c --compress 'compression to use'   default=zstd values='none gzip zstd'
zarg_opt  -k --keep     'how many to retain'   default=7 env=BACKUP_KEEP metavar=N
zarg_arg  source  'directory to back up'       required
zarg_arg  targets 'where to put it'            variadic default=/backup
zarg_go "$@"

print -r -- "source=$source  targets=(${(j:, :)targets})"
print -r -- "compress=$compress  keep=$keep"
(( dry_run )) && print -r -- "(dry run — nothing copied)"
```

That is the entire interface. Running it:

```console
$ backup ~/Documents
source=/Users/you/Documents  targets=(/backup)
compress=zstd  keep=7

$ backup -n ~/Documents /nas/a --compress=gzip /nas/b -vk 30
source=/Users/you/Documents  targets=(/nas/a, /nas/b)
compress=gzip  keep=30
(dry run — nothing copied)

$ BACKUP_KEEP=90 backup ~/Documents
compress=zstd  keep=90

$ backup -c lzma ~/Documents
backup: --compress: 'lzma' is not one of: none gzip zstd
  try 'backup --help'

$ backup
backup: missing argument: source
  try 'backup --help'
```

Note the second one: flags, an `=` option, a clustered `-vk` whose `k` takes a
value, and two positionals, all interleaved. Order never matters — options and
positionals may appear in any arrangement, and everything after `--` is
positional no matter what it looks like.

And the `--help` nobody wrote:

```
  Back up a directory

  usage: backup [options] <source> [targets]...

  arguments:
    source                   directory to back up
    targets                  where to put it

  options:
    -n, --dry-run            show what would be copied, copy nothing
    -v, --verbose            list every file
    -c, --compress COMPRESS  compression to use (default: zstd)
    -k, --keep N             how many to retain (default: 7) ($BACKUP_KEEP)
    -h, --help               show this help
    --version                show version
    --completions SHELL      emit completions (zsh, fish, bash)
```

## Where the values land

Each declaration binds a plain variable in the calling script, named after the
long form with dashes turned to underscores:

| Declared | Variable | Value |
| --- | --- | --- |
| `zarg_flag -n --dry-run` | `$dry_run` | `0` or `1` |
| `zarg_opt -k --keep` | `$keep` | the string |
| `zarg_arg source` | `$source` | the string |
| `zarg_arg targets … variadic` | `$targets` | an array |

Plain variables rather than an associative array (`$zarg[keep]`) is a
deliberate trade: `(( dry_run ))` and `$keep` read better in the body than the
subscripted form, and the body is what you spend your time in. The cost is that
zarg writes into your namespace, so a spec is refused if it would bind a name
zsh reserves:

```console
$ zarg_opt -p --path 'where'
zarg: cannot bind 'path' — zsh reserves it for shell state
```

`$path` is the one that matters — zsh ties it to `$PATH`, so binding it would
empty `PATH` mid-parse and every command afterwards would vanish. That bug
happened here once already, in a loop variable, before this check existed.

## Precedence

Declared default, then environment, then the command line — each overriding the
last:

```zsh
zarg_opt -k --keep 'how many to retain' default=7 env=BACKUP_KEEP
```

```console
$ backup ~/D                        # keep=7    (default)
$ BACKUP_KEEP=90 backup ~/D         # keep=90   (environment)
$ BACKUP_KEEP=90 backup -k 30 ~/D   # keep=30   (command line wins)
```

## Spec API

| Builder | Purpose |
| --- | --- |
| `zarg <name> <description>` | start a spec |
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

Parsing covers `--long value`, `--long=value`, `-s value`, attached shorts
(`-b192`), clustered flags (`-nk`), and `--` to stop option processing. Unknown
flags get a did-you-mean:

```console
$ backup --dry-ru ~/D
backup: unknown option: --dry-ru
  did you mean '--dry-run'?
  try 'backup --help'
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

## Layout

```
zarg.plugin.zsh    loader: fpath + autoload, nothing else
functions/         one function per file, autoloaded on first call
test.zsh           zarg against a fixture
check-completions.zsh   zarg against every real consumer
```

`zarg.plugin.zsh` follows the usual plugin convention — it locates itself with
`${0:A:h}`, adds its own `functions/` to `fpath`, and autoloads by globbing, so
adding a function needs no edit to the loader. Sourcing zarg therefore costs a
handful of lines instead of the whole library, and a script that never asks for
fish completions never loads the fish emitter.

This is a structural win, not a speed one — measured across 30 runs the split
made no observable difference, since autoload trades file parsing for a stat
per function.

## Install

Sheldon (or any manager) sources the plugin, which puts its `functions/` on
`fpath`:

```toml
[plugins.zarg]
local = "~/.dotfiles/zsh-plugins/zarg"
```

Then one `export FPATH` after the plugins have loaded — `conf.d/zzzz-fpath.zsh`
here. That is the whole mechanism:

```zsh
export FPATH
```

`FPATH` is a real environment variable tied to `$fpath`, exactly as `PATH` is
to `$path`. A script runs in its own zsh and inherits no *functions*, but it
does inherit the environment — so exporting `FPATH` hands it the same libraries
the interactive shell loaded. Consumers then need no path to anything:

```zsh
#!/usr/bin/env zsh
autoload -Uz zarg
```

Each function declares its own private helpers, so autoloading the public names
is enough.

Two consequences worth knowing. A script run with no zsh ancestor — cron, a
systemd unit, CI — has no `FPATH` and must set one; `check-completions.zsh`
does exactly that from its own location. And the libraries a script gets are
whichever ones the *shell* loaded, so a worktree's scripts use `~/.dotfiles`'
copy unless you prepend the worktree's own `functions/` to `FPATH` in that
shell.

## Tests

```sh
zsh zsh-plugins/zarg/test.zsh                # 35 tests, zarg against a fixture
zsh zsh-plugins/zarg/check-completions.zsh   # every real consumer
```

`test.zsh` covers parsing, precedence, reserved names, errors, help and the
shape of all three emitters. `check-completions.zsh` sweeps `scripts/` and every
plugin `bin/`, piping each script's emitted completion into the shell it targets
— so a spec that parses but renders a broken compdef fails there rather than the
next time you press tab. Both run on pre-push and in CI, where fish is installed
so its output is parsed rather than merely generated.
