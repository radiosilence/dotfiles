# Return if requirements are not found.
if [[ "$TERM" == 'dumb' ]]; then
  return 1
fi

# Add zsh-completions to $fpath.
# fpath=("${0:h}/external/src" $fpath)

#
# Options
#

setopt COMPLETE_IN_WORD # Complete from both ends of a word.
setopt ALWAYS_TO_END    # Move cursor to the end of a completed word.
setopt PATH_DIRS        # Perform path search even on command names with slashes.
setopt AUTO_MENU        # Show completion menu on a successive tab press.
setopt AUTO_LIST        # Automatically list choices on ambiguous completion.
setopt AUTO_PARAM_SLASH # If completed parameter is a directory, add a trailing slash.
setopt EXTENDED_GLOB    # Needed for file modification glob modifiers with compinit
unsetopt MENU_COMPLETE  # Do not autoselect the first completion entry.
unsetopt FLOW_CONTROL   # Disable start/stop characters in shell editor.
