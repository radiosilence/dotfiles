# android sdk
if is_macos; then
  export ANDROID_HOME=~/Library/Android/sdk
fi

# sdkman
export SDKMAN_DIR=~/.sdkman
[[ -s ~/.sdkman/bin/sdkman-init.sh ]] && . ~/.sdkman/bin/sdkman-init.sh

try_java() {
  _JAVA_HOME="/Library/Java/JavaVirtualMachines/adoptopenjdk-$1.jdk/Contents/Home"
  [[ -d $_JAVA_HOME ]] && export JAVA_HOME=$_JAVA_HOME
}
try_azul() {
  _JAVA_HOME="/Library/Java/JavaVirtualMachines/zulu-$1.jdk/Contents/Home"
  [[ -d $_JAVA_HOME ]] && export JAVA_HOME=$_JAVA_HOME
}

export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools

try_java 8
try_java 14
try_azul 11
