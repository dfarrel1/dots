alias worldcom='mvn clean install'
alias sbr='mvn spring-boot:run'
alias cr='cargorun'
alias vcr='worldcom;jcr'

export JAVA_HOME=$(/usr/libexec/java_home -v 12.0.2)

eval "$(jenv init -)"

alias intellij='open -a "IntelliJ IDEA CE"'


help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi
