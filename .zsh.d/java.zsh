try_java() {
  _JAVA_HOME="/Library/Java/JavaVirtualMachines/$1-$2.jdk/Contents/Home"
  [[ -d $_JAVA_HOME ]] && export JAVA_HOME=$_JAVA_HOME
}

try_java adoptopenjdk 8
try_java adoptopenjdk 14
try_java zulu 11
try_java zulu 17
try_java zulu 21
