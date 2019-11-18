alias worldcom='mvn clean install'
alias sbr='mvn spring-boot:run'
alias cr='cargorun'
alias vcr='worldcom;jcr'

export JAVA_HOME=$(/usr/libexec/java_home -v 12.0.2)

eval "$(jenv init -)"

alias intellij='open -a "IntelliJ IDEA CE"'

alias kafkaup='zookeeper-server-start /usr/local/etc/kafka/zookeeper.properties & kafka-server-start /usr/local/etc/kafka/server.properties &'
alias kafkadown='zookeeper-server-stop'

kafkacomm() {
  echo "zookeeper-server-start zookeeper.properties &"
  echo "kafka-server-start server.properties &"
  echo "kafka-topics --list --zookeeper localhost:2181"
  echo "kafka-topics --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic test &"
  echo "kafka-console-producer --broker-list localhost:9092 --topic test"
  echo "kafka-console-consumer --bootstrap-server localhost:9092 --topic test --from-beginning"
}

mcr() {
  mvn clean install
  if [ $? -eq 0 ]
  then
    echo ' !  Now running via cargo:run  ! '
    cd $(basename "$PWD")-web
    cr devint-test
    cd ..
  fi
}

jcr() {
  g2 web
  cr devint-test
  ..
}

wcr() {
  g2 war
  mvn package -P devint-test cargo:run
  ..
}

cargorun () {
  [ -z "$1" ] && local p="devint-test" || local p=$1
  mvn package -P $p cargo:run
}

help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi
