# History expansion inlay hints — shows dimmed preview of what !!, !$, ^foo^bar etc. expand to
# Chains into zle-line-pre-redraw via add-zle-hook-widget (won't clobber zsh-autosuggestions)
[[ $- == *i* ]] || return
autoload -Uz add-zle-hook-widget

# Allow disabling via: zstyle ':hist-preview' enabled no
_hist_expansion_preview() {
  # Recursion guard — expand-history triggers redraw
  (( _hist_preview_active )) && return
  typeset -gi _hist_preview_active=1

  # Strip any previous preview we appended (everything after our marker)
  if [[ -n "$_hist_preview_suffix" ]]; then
    POSTDISPLAY="${POSTDISPLAY%"$_hist_preview_suffix"}"
    _hist_preview_suffix=""
    # Clean up region_highlight entries we added
    if (( _hist_preview_hl_idx > 0 )); then
      region_highlight[$_hist_preview_hl_idx]=()
      _hist_preview_hl_idx=0
    fi
  fi

  # Bail fast — no expansion characters present
  if [[ "$BUFFER" != *'!'* && "$BUFFER" != '^'* ]]; then
    _hist_preview_active=0
    return
  fi

  # Still typing — single ! or bare ^ with nothing after it
  if [[ "$BUFFER" == '!' || "$BUFFER" == '^' ]]; then
    _hist_preview_active=0
    return
  fi

  # ^foo^bar must start at buffer position 0
  if [[ "$BUFFER" != *'!'* && "$BUFFER" == '^'* ]]; then
    # Only match ^foo^bar pattern (needs at least two ^)
    if [[ "$BUFFER" != *'^'*'^'* ]]; then
      _hist_preview_active=0
      return
    fi
  fi

  # Check zstyle kill switch
  local enabled
  zstyle -s ':hist-preview' enabled enabled
  if [[ "$enabled" == "no" ]]; then
    _hist_preview_active=0
    return
  fi

  # Save state
  local orig_buffer="$BUFFER"
  local orig_cursor=$CURSOR

  # Let zsh expand history in-place
  zle expand-history

  if [[ "$BUFFER" != "$orig_buffer" ]]; then
    local expanded="$BUFFER"
    # Restore original buffer
    BUFFER="$orig_buffer"
    CURSOR=$orig_cursor

    # Build our suffix and append to whatever POSTDISPLAY already has (autosuggestions etc.)
    _hist_preview_suffix=$'\n'"  \u2192 ${expanded}"
    POSTDISPLAY="${POSTDISPLAY}${_hist_preview_suffix}"

    # Dim our appended portion via region_highlight
    # POSTDISPLAY region starts at offset #BUFFER (end of editable buffer)
    # We need to highlight from where our suffix starts within POSTDISPLAY
    local total_len=$(( $#BUFFER + $#POSTDISPLAY ))
    local suffix_start=$(( total_len - $#_hist_preview_suffix ))
    region_highlight+=("P${suffix_start} P${total_len} fg=8")
    _hist_preview_hl_idx=$#region_highlight
  else
    # No expansion happened — restore cursor, leave POSTDISPLAY alone
    BUFFER="$orig_buffer"
    CURSOR=$orig_cursor
  fi

  _hist_preview_active=0
}

add-zle-hook-widget zle-line-pre-redraw _hist_expansion_preview
