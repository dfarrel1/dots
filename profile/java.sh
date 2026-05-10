#!/usr/bin/env bash
alias worldcom='mvn clean install'
alias sbr='mvn spring-boot:run'
alias cr='cargorun'
alias vcr='worldcom;jcr'

# Default JAVA_HOME: prefer JDK 17 (Android Gradle Plugin 8.x target +
# Gradle 8.x supported), falling back to 21, then any available LTS, then
# whatever java_home picks. Override per-shell with: JAVA_HOME=$(/usr/libexec/java_home -v 21)
export JAVA_HOME=$(/usr/libexec/java_home -v 17 2>/dev/null \
    || /usr/libexec/java_home -v 21 2>/dev/null \
    || /usr/libexec/java_home -v 11 2>/dev/null \
    || /usr/libexec/java_home)

# Android workflows: ./gradlew under AGP 8.x needs JDK 17. If 17 isn't the
# default JAVA_HOME above (e.g. user has multiple JDKs and prefers a newer
# one), the typical pattern is:
#   alias gradle17='JAVA_HOME=$(/usr/libexec/java_home -v 17) ./gradlew'

alias adb='~/Library/Android/sdk/platform-tools/adb'
alias avd='~/Library/Android/sdk/tools/emulator -avd'
alias avdlist='~/Library/Android/sdk/tools/emulator -list-avds'

# WARNING: loading jenv will clear JAVA_HOME
# eval "$(jenv init -)"

alias intellij='open -a "IntelliJ IDEA CE"'


help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi
