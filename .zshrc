#!/usr/bin/env zsh

for config (~/.zsh.d/*.zsh) source $config

for config (~/.zsh.d.local/*.zsh) source $config

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="/Users/james.cleveland/.sdkman"
[[ -s "/Users/james.cleveland/.sdkman/bin/sdkman-init.sh" ]] && source "/Users/james.cleveland/.sdkman/bin/sdkman-init.sh"
