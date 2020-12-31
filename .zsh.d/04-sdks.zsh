# android sdk
if is_macos; then
  export ANDROID_HOME=~/Library/Android/sdk
fi

# sdkman
export SDKMAN_DIR=~/.sdkman
[[ -s ~/.sdkman/bin/sdkman-init.sh ]] && . ~/.sdkman/bin/sdkman-init.sh

if is_cmd brew; then
  export BREW_PREFIX=$(brew --prefix)
fi

try_java() {
  _JAVA_HOME="/Library/Java/JavaVirtualMachines/adoptopenjdk-$1.jdk/Contents/Home"
  [[ -d $_JAVA_HOME ]] && export JAVA_HOME=$_JAVA_HOME
}

try_java 14
try_java 8
