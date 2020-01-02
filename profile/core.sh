# Applications
#
# instructions to install cli for code: https://code.visualstudio.com/docs/setup/mac
alias code='/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code'
alias open_with_code='open -a "Visual Studio Code"'
alias c.='repo_info -s;open_with_code $git_local_path'
alias a.='repo_info -s;atom $git_local_path'
# after ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" /usr/local/bin/sublime
alias s.='repo_info -s;sublime $git_local_path'
alias i.='repo_info -s;intellij $git_local_path'
alias o.='open .'
alias chrome='open -a "Google Chrome"'
alias pn.='chrome http://127.0.0.1:8192/ && /Applications/polynote/polynote'
# stree alias comes from SourceTree, need to activate command line tools
alias chfox='open -a Charles;open -a Firefox'
alias excel='open -a "Microsoft Excel"'

alias ports='lsof -i | grep -E "(LISTEN|ESTABLISHED)"'
alias epc='open_with_code $PROFILE_DIR' # [E]dit [P]rofile (with) [C]ode
alias epa='atom $PROFILE_DIR'
alias ep='epc'

get_choice() {
  local count=`printf "$choice_set" | wc -l | awk '{print $1}'`
  [ ${#choice_set} -eq 0 ] || count=$((count+1))
  local re='^([0-9]+)$'
  if [ $count -eq 0 ]; then
    echo "No match found" && export choice_set=""
  elif [ $count -eq 1 ]; then
    export choice_set="$choice_set"
  else
    printf "$choice_set\n" | nl
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

help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi
