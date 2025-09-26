# Zim framework initialization
# This file replaces the sheldon configuration

# Set zim configuration
zstyle ':zim:zmodule' use 'degit'

# Auto-install missing modules and update zimfw (zimfw installed via mise)
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZDOTDIR:-${HOME}}/.zimrc ]]; then
  zimfw init -q
fi

# Initialize modules
if [[ -s ${ZIM_HOME}/init.zsh ]]; then
  source ${ZIM_HOME}/init.zsh
fi
