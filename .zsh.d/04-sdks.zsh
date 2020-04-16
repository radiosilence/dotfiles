# android sdk
export ANDROID_HOME=~/Library/Android/sdk

# sdkman
export SDKMAN_DIR=~/.sdkman
[[ -s ~/.sdkman/bin/sdkman-init.sh ]] && source ~/.sdkman/bin/sdkman-init.sh

# asdf
if [[ -d ~/.asdf ]]; then
  source ~/.asdf/asdf.sh
  fpath=(${ASDF_DIR}/completions $fpath)
fi

[[ -x /usr/libexec/java_home ]] && export JAVA_HOME=$(/usr/libexec/java_home)


if [[ -x $(which brew) ]]; then
  BREW_PREFIX=$(brew --prefix)
  ANDROID_SDK_ROOT="$BREW_PREFIX/share/android-sdk"
fi