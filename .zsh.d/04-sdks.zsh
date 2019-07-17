#!/usr/local/bin zsh

# android sdk
export ANDROID_HOME=~/Library/Android/sdk

# sdkman
export SDKMAN_DIR=~/.sdkman
[[ -s ~/.sdkman/bin/sdkman-init.sh ]] && source ~/.sdkman/bin/sdkman-init.sh

# asdf
source ~/.asdf/asdf.sh
source ~/.asdf/completions/asdf.bash

[[ -x /usr/libexec/java_home ]] && export JAVA_HOME=$(/usr/libexec/java_home)