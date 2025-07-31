# Interactive shell configuration
[[ $- == *i* ]] || return

# Word boundaries (exclude slash and other path separators for more precise word deletion)
export WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'

# Key bindings
bindkey '^[^?' backward-kill-word # Alt-Backspace (stops at / . - etc)
bindkey '^[[1;3D' backward-word   # Alt-Left (stops at / . - etc)
bindkey '^[[1;3C' forward-word    # Alt-Right (stops at / . - etc)
bindkey '^C' kill-whole-line      # Ctrl-C clears line

# Bang history expansion (!! and !$)
setopt BANG_HIST
