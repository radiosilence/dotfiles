# History expansion inlay hints — dimmed inline preview of what !!, !$, ^foo^bar etc. expand to
# Wraps editing widgets (runs after autosuggestions) for reliable per-keystroke display
[[ $- == *i* ]] || return

typeset -gi _hist_preview_active=0
typeset -g _hist_preview_hl=""

_hist_expansion_preview() {
  (( _hist_preview_active )) && return
  _hist_preview_active=1

  # Clean up our previous highlight entry
  if [[ -n "$_hist_preview_hl" ]]; then
    region_highlight=("${(@)region_highlight:#${_hist_preview_hl}}")
    _hist_preview_hl=""
  fi

  # Bail fast — no expansion chars
  if [[ "$BUFFER" != *'!'* && "$BUFFER" != '^'* ]]; then
    _hist_preview_active=0
    return
  fi

  # Still typing — lone ! or ^
  if [[ "$BUFFER" == '!' || "$BUFFER" == '^' ]]; then
    _hist_preview_active=0
    return
  fi

  # ^foo^bar needs to start at pos 0 with two ^
  if [[ "$BUFFER" != *'!'* && "$BUFFER" == '^'* ]]; then
    [[ "$BUFFER" != *'^'*'^'* ]] && { _hist_preview_active=0; return }
  fi

  # Kill switch: zstyle ':hist-preview' enabled no
  local enabled
  zstyle -s ':hist-preview' enabled enabled
  [[ "$enabled" == "no" ]] && { _hist_preview_active=0; return }

  # Get last command and split into words
  local last_cmd="${history[$((HISTCMD-1))]}"
  [[ -z "$last_cmd" ]] && { _hist_preview_active=0; return }
  local -a w=( ${(z)last_cmd} )

  local expanded="$BUFFER"
  local -i changed=0

  if [[ "$expanded" == '^'*'^'* ]]; then
    # ^old^new — quick substitution
    local tmp="${expanded#^}"
    local old="${tmp%%^*}"
    local new="${tmp#*^}" && new="${new%%^*}"
    [[ -n "$old" ]] && expanded="${last_cmd/$old/$new}" && changed=1
  else
    # Word designators — specific before general
    [[ "$expanded" == *'!!:'[*]* ]]   && expanded="${expanded//!!:[*]/${(j: :)w[2,-1]}}" && changed=1
    [[ "$expanded" == *'!!:$'* ]]     && expanded="${expanded//!!:\$/${w[-1]}}" && changed=1
    [[ "$expanded" == *'!!:^'* ]]     && expanded="${expanded//!!:\^/${w[2]}}" && changed=1
    local -i i; for i in {0..9}; do
      [[ "$expanded" == *"!!:${i}"* ]] && expanded="${expanded//!!:${i}/${w[$((i+1))]}}" && changed=1
    done
    # !! → full last command (AFTER word designators to avoid partial match)
    [[ "$expanded" == *'!!'* ]] && expanded="${expanded//!!/${last_cmd}}" && changed=1
    # Shorthands
    [[ "$expanded" == *'!$'* ]] && expanded="${expanded//!\$/${w[-1]}}" && changed=1
    [[ "$expanded" == *'!^'* ]] && expanded="${expanded//!\^/${w[2]}}" && changed=1
  fi

  if (( changed )); then
    POSTDISPLAY=$'    \u2192  '"${expanded}"
    local hl_start=${#BUFFER}
    local hl_end=$(( ${#BUFFER} + ${#POSTDISPLAY} ))
    _hist_preview_hl="${hl_start} ${hl_end} fg=8"
    region_highlight+=("$_hist_preview_hl")
  fi
  # If no expansion matched, don't touch POSTDISPLAY — autosuggestions keeps its value

  _hist_preview_active=0
}

# Wrap editing widgets to trigger preview after each keystroke
# Chains after autosuggestions' wrappers (which already ran), giving us final say on POSTDISPLAY
_hist_preview_wrap() {
  local widget=$1
  # Save current definition (may be autosuggestions' wrapper or builtin)
  zle -A "$widget" "_hist_preview_orig_$widget" 2>/dev/null || return
  eval "_hist_preview_w_${widget}() { zle _hist_preview_orig_${widget} -- \"\$@\"; _hist_expansion_preview; }"
  zle -N "$widget" "_hist_preview_w_${widget}"
}

local _hp_w
for _hp_w in self-insert backward-delete-char delete-char accept-line \
             backward-kill-word kill-word kill-line yank; do
  _hist_preview_wrap "$_hp_w"
done
unset _hp_w
