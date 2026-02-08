#!/usr/bin/env bash
# Docker cleanup
alias clearcont='docker rm $(docker ps -a -q)'
alias clearimages='docker rmi $(docker images -q)'
alias cld='clearcont;clearimages;docker system prune' # @desc Full Docker cleanup (containers + images + prune)
# Docker build / run
alias dc='docker-compose' # @desc docker-compose shorthand
alias dcd='docker-compose down --remove-orphans' # @desc docker-compose down with orphan removal
alias dcd1='docker-compose rm -fsv' # @desc docker-compose remove single service
alias dcbuild='docker-compose build --no-cache'
alias dcup='docker-compose up'
alias buildup='dcbuild;dcup'
alias dcrun='docker-compose run --rm'
alias burn='buildup;dcrun' # @desc Build, start, and run
alias drun='docker run -it'
alias drunproxy='docker run -e http_proxy=$"$http_proxy" -it' # @desc docker run with proxy env vars
alias dbuild='docker build --build-arg HTTP_PROXY=$http_proxy --build-arg HTTPS_PROXY=$http_proxy --build-arg http_proxy=$http_proxy --build-arg https_proxy=$http_proxy --build-arg proxy=$http_proxy' # @desc docker build with proxy args
# Docker other
alias dinfo='docker history' # @desc docker history
alias dhist='docker history --no-trunc' # @desc docker history (no truncation)

# @desc Interactive bash shell into a running container (fuzzy select)
# @usage dbash [filter]
dbash() {
  export choice_set=`echo "$(docker ps)\n" | awk '!/CONTAINER ID/' | grep ".*$1.*"`
  get_choice
  p="p"
  [ "$choice_set" != "" ] && local c_id="`printf \"$choice_set\" | cut -d" " -f1 | sed -n $s$p 2>/dev/null`" && echo "Entering container $c_id" && docker exec -it $c_id bash
}

# @desc Interactive sh shell into a running container (fuzzy select)
# @usage dsh [filter]
dsh() {
  export choice_set=`echo "$(docker ps)\n" | awk '!/CONTAINER ID/' | grep ".*$1.*"`
  get_choice
  p="p"
  [ "$choice_set" != "" ] && local c_id="`printf \"$choice_set\" | cut -d" " -f1 | sed -n $s$p 2>/dev/null`" && echo "Entering container $c_id" && docker exec -it $c_id sh
}

# @desc View logs of a container (fuzzy select)
# @usage dlogs [filter]
dlogs() {
  export choice_set=`echo "$(docker ps -a)\n" | awk '!/CONTAINER ID/' | grep ".*$1.*"`
  get_choice
  p="p"
  [ "$choice_set" != "" ] && local c_id="`printf \"$choice_set\" | cut -d" " -f1 | sed -n $s$p 2>/dev/null`" && echo "Entering container $c_id" && docker logs $c_id
}

# @desc Run a container interactively with privileged mode
# @usage dock-run <image> [args...]
dock-run() { sudo docker run -i -t --privileged $@ ;}
# @desc Exec into a container with bash
# @usage dock-exec <container>
dock-exec() { sudo docker exec -i -t $@ /bin/bash ;}
# @desc Follow all logs of a container
# @usage dock-log <container>
dock-log() { sudo docker logs --tail=all -f $@ ;}
# @desc Show port mappings for a container
# @usage dock-port <container>
dock-port() { sudo docker port $@ ;}
# @desc Show volumes for a container
# @usage dock-vol <container>
dock-vol() { sudo docker inspect --format '{{ .Volumes }}' $@ ;}
# @desc Show IP address of a container
# @usage dock-ip <container>
dock-ip() { sudo docker inspect --format '{{ .NetworkSettings.IPAddress }}' $@ ;}
# @desc Remove exited containers
# @usage dock-rmc
dock-rmc() { sudo docker rm sudo docker ps -qa --filter 'status=exited' ;}
# @desc Remove dangling images
# @usage dock-rmi
dock-rmi() { sudo docker rmi -f sudo docker images | grep '^<none>' | awk '{print $3}' ;}
# @desc Stop all running containers
# @usage dock-stop
dock-stop() { sudo docker stop $(docker ps -a -q); }
# @desc Remove all containers
# @usage dock-rm
dock-rm() { sudo docker rm $(docker ps -a -q); }
# @desc Run a docker command on all containers
# @usage dock-do <start|stop|pause|unpause>
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

# @desc Full Docker restart cycle (stop containers, quit app, relaunch)
# @usage restartdocker
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
