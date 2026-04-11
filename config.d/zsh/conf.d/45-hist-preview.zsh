# History expansion inlay hints — dimmed inline preview of what !!, !$, ^foo^bar etc. expand to
# Uses manual expansion (no zle expand-history) to avoid triggering autosuggestions overwrites
[[ $- == *i* ]] || return
autoload -Uz add-zle-hook-widget

_hist_expansion_preview() {
  (( _hist_preview_active )) && return
  typeset -gi _hist_preview_active=1

  # Clean up previous highlight
  if [[ -n "$_hist_preview_hl" ]]; then
    region_highlight=("${(@)region_highlight:#${_hist_preview_hl}}")
    _hist_preview_hl=""
  fi

  # Bail fast — no expansion characters present
  if [[ "$BUFFER" != *'!'* && "$BUFFER" != '^'* ]]; then
    POSTDISPLAY=""
    _hist_preview_active=0
    return
  fi

  # Still typing — single char
  if [[ "$BUFFER" == '!' || "$BUFFER" == '^' ]]; then
    _hist_preview_active=0
    return
  fi

  # ^foo^bar must start at position 0 and have two ^
  if [[ "$BUFFER" != *'!'* && "$BUFFER" == '^'* ]]; then
    [[ "$BUFFER" != *'^'*'^'* ]] && { _hist_preview_active=0; return }
  fi

  # zstyle ':hist-preview' enabled no — kill switch
  local enabled
  zstyle -s ':hist-preview' enabled enabled
  [[ "$enabled" == "no" ]] && { _hist_preview_active=0; return }

  # Grab last command and split into words
  local last_cmd="${history[$((HISTCMD-1))]}"
  [[ -z "$last_cmd" ]] && { _hist_preview_active=0; return }
  local -a w=( ${(z)last_cmd} )

  local expanded="$BUFFER"
  local -i changed=0

  if [[ "$expanded" == '^'*'^'* ]]; then
    # ^old^new — quick substitution on last command
    local tmp="${expanded#^}"
    local old="${tmp%%^*}"
    local new="${tmp#*^}" && new="${new%%^*}"
    [[ -n "$old" ]] && expanded="${last_cmd/$old/$new}" && changed=1
  else
    # Word designators — specific before general to avoid partial matches
    # !!:* → all arguments
    [[ "$expanded" == *'!!:'[*]* ]] && expanded="${expanded//!![:][\*]/${(j: :)w[2,-1]}}" && changed=1
    # !!:$ → last argument
    [[ "$expanded" == *'!!:$'* ]] && expanded="${expanded//!!:\$/${w[-1]}}" && changed=1
    # !!:^ → first argument
    [[ "$expanded" == *'!!:^'* ]] && expanded="${expanded//!!:\^/${w[2]}}" && changed=1
    # !!:n → nth word (0=cmd, 1=first arg, ...)
    local -i i
    for i in {0..9}; do
      [[ "$expanded" == *"!!:${i}"* ]] && expanded="${expanded//!!:${i}/${w[$((i+1))]}}" && changed=1
    done
    # !! → entire last command (AFTER word designators)
    [[ "$expanded" == *'!!'* ]] && expanded="${expanded//!!/${last_cmd}}" && changed=1
    # !$ → last arg shorthand
    [[ "$expanded" == *'!$'* ]] && expanded="${expanded//!\$/${w[-1]}}" && changed=1
    # !^ → first arg shorthand
    [[ "$expanded" == *'!^'* ]] && expanded="${expanded//!\^/${w[2]}}" && changed=1
  fi

  if (( changed )); then
    POSTDISPLAY=$'    \u2192  '"${expanded}"
    local hl_start=${#BUFFER}
    local hl_end=$(( ${#BUFFER} + ${#POSTDISPLAY} ))
    _hist_preview_hl="${hl_start} ${hl_end} fg=8"
    region_highlight+=("$_hist_preview_hl")
  else
    POSTDISPLAY=""
  fi

  _hist_preview_active=0
}

add-zle-hook-widget zle-line-pre-redraw _hist_expansion_preview
