#!/usr/bin/env bash
# Docker cleanup
alias clearcont='docker rm $(docker ps -a -q)'
alias clearimages='docker rmi $(docker images -q)'
alias cld='clearcont;clearimages;docker system prune'
# Docker build / run
alias dc='docker-compose'
alias dcd='docker-compose down --remove-orphans'
alias dcd1='docker-compose rm -fsv'
alias dcbuild='docker-compose build --no-cache'
alias dcup='docker-compose up'
alias buildup='dcbuild;dcup'
alias dcrun='docker-compose run --rm'
alias burn='buildup;dcrun'
alias drun='docker run -it'
alias drunproxy='docker run -e http_proxy=$"$http_proxy" -it'
alias dbuild='docker build --build-arg HTTP_PROXY=$http_proxy --build-arg HTTPS_PROXY=$http_proxy --build-arg http_proxy=$http_proxy --build-arg https_proxy=$http_proxy --build-arg proxy=$http_proxy'
# Docker other
alias dinfo='docker history'
alias dhist='docker history --no-trunc'

dbash() {
  export choice_set=`echo "$(docker ps)\n" | awk '!/CONTAINER ID/' | grep ".*$1.*"`
  get_choice
  p="p"
  [ "$choice_set" != "" ] && local c_id="`printf \"$choice_set\" | cut -d" " -f1 | sed -n $s$p 2>/dev/null`" && echo "Entering container $c_id" && docker exec -it $c_id bash
}

dsh() {
  export choice_set=`echo "$(docker ps)\n" | awk '!/CONTAINER ID/' | grep ".*$1.*"`
  get_choice
  p="p"
  [ "$choice_set" != "" ] && local c_id="`printf \"$choice_set\" | cut -d" " -f1 | sed -n $s$p 2>/dev/null`" && echo "Entering container $c_id" && docker exec -it $c_id sh
}

dlogs() {
  export choice_set=`echo "$(docker ps -a)\n" | awk '!/CONTAINER ID/' | grep ".*$1.*"`
  get_choice
  p="p"
  [ "$choice_set" != "" ] && local c_id="`printf \"$choice_set\" | cut -d" " -f1 | sed -n $s$p 2>/dev/null`" && echo "Entering container $c_id" && docker logs $c_id
}

dock-run() { sudo docker run -i -t --privileged $@ ;}
dock-exec() { sudo docker exec -i -t $@ /bin/bash ;}
dock-log() { sudo docker logs --tail=all -f $@ ;}
dock-port() { sudo docker port $@ ;}
dock-vol() { sudo docker inspect --format '{{ .Volumes }}' $@ ;}
dock-ip() { sudo docker inspect --format '{{ .NetworkSettings.IPAddress }}' $@ ;}
dock-rmc() { sudo docker rm sudo docker ps -qa --filter 'status=exited' ;}
dock-rmi() { sudo docker rmi -f sudo docker images | grep '^<none>' | awk '{print $3}' ;}
dock-stop() { sudo docker stop $(docker ps -a -q); }
dock-rm() { sudo docker rm $(docker ps -a -q); }
dock-do() { 
  if [ "$#" -ne 1 ]; 
    then echo "Usage: $0 start|stop|pause|unpause|" 
  fi
  for c in $(sudo docker ps -a | awk '{print $1}' | sed "1 d") 
  do 
    sudo docker $1 $c 
  done 
}

alias k="kubectl"
alias ka="kubectl apply -f"
alias kpa="kubectl patch -f"
alias ked="kubectl edit"
alias ksc="kubectl scale"
alias kex="kubectl exec -i -t"
alias kg="kubectl get"
alias kga="kubectl get all"
alias kgall="kubectl get all --all-namespaces"
alias kinfo="kubectl cluster-info"
alias kdesc="kubectl describe"
alias ktp="kubectl top"
alias klo="kubectl logs -f"
alias kn="kubectl get nodes"
alias kpv="kubectl get pv"
alias kpvc="kubectl get pvc"

restartdocker() {
  # Stop all Docker containers without confirmation
  # [ Assumes all running Docker containers are in a quiesced state ]
  echo "stopping all containers" && docker ps -q | xargs -L1 docker stop
  # Stop Docker for Mac gracefully
  echo "stopping docker gracefully" && test -z "$(docker ps -q 2>/dev/null)" && osascript -e 'quit app "Docker"'
  # Stop Docker brutaly
  docker info > /dev/null 2>&1  && echo "brutally killing docker" && killall Docker
  # Start Docker gracefully
  echo "starting docker" && open --background -a Docker
}

help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi
