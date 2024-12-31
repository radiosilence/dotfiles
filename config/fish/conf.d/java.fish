function try_java
    set -l _JAVA_HOME "/Library/Java/JavaVirtualMachines/$argv[1]-$argv[2].jdk/Contents/Home"
    if test -d $_JAVA_HOME
        set -gx JAVA_HOME $_JAVA_HOME
    end
end

try_java adoptopenjdk 8
try_java adoptopenjdk 14
try_java zulu 11
try_java zulu 17
try_java zulu 21
