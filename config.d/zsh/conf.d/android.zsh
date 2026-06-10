# Android development
# Use the JBR bundled with Android Studio instead of a separately managed JDK,
# so the CLI and the IDE always build with the same runtime.
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
