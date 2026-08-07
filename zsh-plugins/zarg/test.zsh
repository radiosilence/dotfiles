#!/usr/bin/env zsh
# zarg's test suite. Run: zsh zsh-plugins/zarg/test.zsh
#
# Each case runs a fixture script in a subshell, because zarg_go exits the
# process for --help, errors and the like — which is exactly the behaviour
# under test.

local here=${0:A:h}
local fixture=$(mktemp -d)/spec
trap 'rm -rf ${fixture:h}' EXIT

cat > "$fixture" <<EOF
#!/usr/bin/env zsh
source "$here/zarg.plugin.zsh"
zarg spec 'a test spec'
zarg_flag -n --dry-run 'do nothing'
zarg_flag -k --keep    'keep things'
zarg_opt  -s --signal  'a signal' default=TERM values='TERM KILL INT'
zarg_opt  -b --bitrate 'a bitrate' default=160 env=BITRATE
zarg_arg  port  'a port' required
zarg_arg  paths 'some paths' variadic default=.
zarg_go "\$@"
print -r -- "dry_run=\$dry_run keep=\$keep signal=\$signal bitrate=\$bitrate port=\$port paths=\${(j:,:)paths}"
EOF
chmod +x "$fixture"

local -i pass=0 fail=0

# ok <name> <expected-substring> <args...>
ok() {
  local name=$1 want=$2; shift 2
  local got; got=$("$fixture" "$@" 2>&1)
  if [[ $got == *"$want"* ]]; then (( pass++ ))
  else (( fail++ )); print -ru2 -- "FAIL $name
  want: *$want*
  got:  $got"
  fi
}

# fails <name> <expected-substring> <args...> — must also exit non-zero
fails() {
  local name=$1 want=$2; shift 2
  local got; got=$("$fixture" "$@" 2>&1); local rc=$?
  if (( rc != 0 )) && [[ $got == *"$want"* ]]; then (( pass++ ))
  else (( fail++ )); print -ru2 -- "FAIL $name (rc=$rc)
  want: *$want*
  got:  $got"
  fi
}

# ── Parsing ──────────────────────────────────────────────────────────
ok   'defaults'            'dry_run=0 keep=0 signal=TERM bitrate=160 port=3000 paths=.'      3000
ok   'long flag'           'dry_run=1'                                          --dry-run 3000
ok   'long opt spaced'     'signal=KILL'                            --signal KILL 3000
ok   'long opt equals'     'signal=INT'                             --signal=INT 3000
ok   'short opt spaced'    'signal=KILL'                            -s KILL 3000
ok   'short opt attached'  'bitrate=192'                            -b192 3000
ok   'clustered flags'     'dry_run=1 keep=1'                       -nk 3000
ok   'variadic collects'   'paths=a,b,c'                            3000 a b c
ok   'double dash'         'paths=--not-an-option'                  3000 -- --not-an-option

# ── Precedence: default < env < command line ─────────────────────────
ok   'default when unset'       'bitrate=160'  3000
BITRATE=999 ok 'env beats default' 'bitrate=999'  3000
BITRATE=999 ok 'flag beats env'    'bitrate=111'  -b 111 3000

# ── Errors ───────────────────────────────────────────────────────────
fails 'missing required'    'missing argument: port'
fails 'unknown option'      'unknown option: --nope'                 --nope 3000
fails 'suggests near miss'  "did you mean '--dry-run'"               --dry-ru 3000
fails 'bad enum value'      "is not one of: TERM KILL INT"           -s BOGUS 3000
fails 'flag given value'    'takes no value'                         --dry-run=yes 3000
fails 'opt missing value'   'needs a value'                          3000 -s
fails 'unknown shell'       'unknown shell'                          --completions tcsh

# ── Built-ins ────────────────────────────────────────────────────────
ok   'help usage line'     'usage: spec [options] <port> [paths]...'  --help
ok   'help shows default'  '(default: TERM)'                          --help
ok   'help shows env'      '($BITRATE)'                               --help
ok   'version'             'spec '                                    --version

# ── Completions ──────────────────────────────────────────────────────
ok   'zsh compdef header'  '#compdef spec'                            --completions zsh
ok   'zsh enum values'     ':SIGNAL:(TERM KILL INT)'                  --completions zsh
ok   'zsh variadic'        "'*:paths:"                                --completions zsh
ok   'fish flag'           'complete -c spec -s n -l dry-run'         --completions fish
ok   'fish enum values'    "-a 'TERM KILL INT'"                       --completions fish
ok   'bash function'       'complete -F _spec spec'                   --completions bash
ok   'bash enum values'    'compgen -W "TERM KILL INT"'               --completions bash

# Emitted completions must be valid in their target shell.
local sh
for sh in zsh bash; do
  if "$fixture" --completions $sh | $sh -n /dev/stdin 2>/dev/null; then (( pass++ ))
  else (( fail++ )); print -ru2 -- "FAIL $sh completion does not parse"; fi
done
if command -v fish >/dev/null 2>&1; then
  if "$fixture" --completions fish | fish -n /dev/stdin 2>/dev/null; then (( pass++ ))
  else (( fail++ )); print -ru2 -- "FAIL fish completion does not parse"; fi
fi

# ── Reserved names ───────────────────────────────────────────────────
# Binding $path would empty $PATH mid-parse, so the spec must be refused.
reserved() {
  local name=$1 decl=$2
  local got; got=$(zsh -c "source '$here/zarg.plugin.zsh'
    zarg t 'x'
    $decl
    print -r -- \"PATH_OK=\$(( \${#path} > 0 ))\"" 2>&1)
  if [[ $got == *"cannot bind '$name'"* && $got == *PATH_OK=1* ]]; then (( pass++ ))
  else (( fail++ )); print -ru2 -- "FAIL reserved:$name
  got: $got"
  fi
}
reserved path  'zarg_opt -p --path "boom"'
reserved fpath 'zarg_arg fpath "boom"'
reserved PATH  'zarg_flag -P --PATH "boom"'

print -r -- "zarg: $pass passed, $fail failed"
(( fail == 0 ))
