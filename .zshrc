#!/usr/bin/env zsh

for config (~/.zsh.d/*.zsh) source $config


#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="/Users/jc/.sdkman"
[[ -s "/Users/jc/.sdkman/bin/sdkman-init.sh" ]] && source "/Users/jc/.sdkman/bin/sdkman-init.sh"
