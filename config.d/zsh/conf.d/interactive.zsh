# Interactive shell configuration
[[ $- == *i* ]] || return

# Word boundaries (exclude slash and other path separators for more precise word deletion)
export WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'

# Key bindings
bindkey '^[^?' backward-kill-word # Alt-Backspace (stops at / . - etc)
bindkey '^[[1;3D' backward-word   # Alt-Left (stops at / . - etc)
bindkey '^[[1;3C' forward-word    # Alt-Right (stops at / . - etc)
bindkey '^C' kill-whole-line      # Ctrl-C clears line

# herdr takes ctrl+a as its prefix, so beginning-of-line needs Home (fn+Left).
# Only ^[OH was bound; cover the other sequences terminals send.
bindkey '^[[H' beginning-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[4~' end-of-line

# Alt-<digit> defaults to digit-argument, an emacs repeat count: Alt-4 then a
# key repeats it 4x, and successive digits concatenate. Unwanted here, and only
# some Alt-digits reach zsh anyway (ghostty maps 0/2/3 to º/€/#).
for _k in 0 1 2 3 4 5 6 7 8 9; do bindkey -r "^[$_k"; done
unset _k

# Bang history expansion (!! and !$)
setopt BANG_HIST
