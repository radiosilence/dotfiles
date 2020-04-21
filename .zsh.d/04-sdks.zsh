# android sdk
export ANDROID_HOME=~/Library/Android/sdk

# sdkman
export SDKMAN_DIR=~/.sdkman
[[ -s ~/.sdkman/bin/sdkman-init.sh ]] && . ~/.sdkman/bin/sdkman-init.sh

# asdf
if [[ -d ~/.asdf ]]; then
  . ~/.asdf/asdf.sh
  fpath=(${ASDF_DIR}/completions $fpath)
fi


if [[ -x $(which brew) ]]; then
  BREW_PREFIX=$(brew --prefix)
  ANDROID_SDK_ROOT="$BREW_PREFIX/share/android-sdk"
fi