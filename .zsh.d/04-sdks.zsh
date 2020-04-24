# android sdk
export ANDROID_HOME=~/Library/Android/sdk

# sdkman
export SDKMAN_DIR=~/.sdkman
[[ -s ~/.sdkman/bin/sdkman-init.sh ]] && . ~/.sdkman/bin/sdkman-init.sh

# asdf
if [[ -s ~/.asdf/asdf.sh ]]; then
  . ~/.asdf/asdf.sh
  fpath=(${ASDF_DIR}/completions $fpath)
fi

if [[ -x $(which brew) ]]; then
  BREW_PREFIX=$(brew --prefix)
  ANDROID_SDK_ROOT="$BREW_PREFIX/share/android-sdk"
fi

export JAVA_14_HOME=/Library/Java/JavaVirtualMachines/adoptopenjdk-14.jdk/Contents/Home
export JAVA_8_HOME=/Library/Java/JavaVirtualMachines/adoptopenjdk-8.jdk/Contents/Home

[[ -d $JAVA_14_HOME ]] && JAVA_HOME=$JAVA_14_HOME
[[ -d $JAVA_8_HOME ]] && JAVA_HOME=$JAVA_8_HOME

export JAVA_HOME