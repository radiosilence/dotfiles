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

try_java() {
  _JAVA_HOME="/Library/Java/JavaVirtualMachines/adoptopenjdk-$1.jdk/Contents/Home"
  [[ -d $_JAVA_HOME ]] && export JAVA_HOME=$_JAVA_HOME
}

try_java 14
try_java 8