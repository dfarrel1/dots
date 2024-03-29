#!/usr/bin/env bash

easy_eyes(){
  awk ' {print;} NR % 5 == 0 { print ""; }'
}

get_choice() {
  local count=`printf "$choice_set" | wc -l | awk '{print $1}'`
  [ ${#choice_set} -eq 0 ] || count=$((count+1))
  local re='^([0-9]+)$'
  if [ $count -eq 0 ]; then
    echo "No match found" && export choice_set=""
  elif [ $count -eq 1 ]; then
    export choice_set="$choice_set"
  else    
    printf "$choice_set\n" | easy_eyes | nl
    local s=0
    local p="p"
    while [ "$s" != "q" ] && ( ! [[ $s =~ $re ]] || ! [ $s -le $count -a $s -gt 0 ] ) && ! [ -z "$s" ]
    do
      if [[ "$s" =~ [a-zA-Z] ]]; then
        local filtered_choice_set=`printf "$choice_set" | grep -i ".*$s.*"`
        local filtered_count=`printf "$filtered_choice_set" | wc -l | awk '{print $1}'`
        [ ${#filtered_choice_set} -eq 0 ] || filtered_count=$((filtered_count+1))
        [ $filtered_count -gt 1 ] && choice_set="$filtered_choice_set" && count=$filtered_count && printf "$choice_set\n" | nl
        [ $filtered_count -eq 1 ] && choice_set="$filtered_choice_set" && return 0
      fi
      read s
      if [ -z "$s" ]; then s=1; fi;
    done
    [ "$s" != "q" ] && export choice_set="`printf \"$choice_set\" | sed -n $s$p 2>/dev/null`" || export choice_set=""
  fi
}

ckh() {
  if [ $# -eq 0 ]
  then
    printf "Enter value to search for and remove from known_hosts: "
    read search
  else
    search=$1
  fi
  sed -i '' "/$search/d" ~/.ssh/known_hosts
}

source_env() {
  set -a && source $1 && set +a
  #source <(sed -E -n 's/[^#]+/export &/ p' "$1")
}

close() {
  export choice_set=`ports | grep -i ".*$1.*"`
  get_choice
  [ "$choice_set" != "" ] && kill -9 `echo $choice_set | sed -E -e "s/[[:blank:]]+/ /g" | cut -d" " -f2`
}

#direnv
eval "$(direnv hook bash)"

#TERRAFORM
tf() {
  [[ "$#" -eq 0 ]] && terraform
  [[ "$#" -gt 0 ]] && aws-vault exec ${AWS_PROFILE} -- terraform "$@"
}

help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi
