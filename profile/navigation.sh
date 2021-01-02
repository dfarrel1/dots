#!/usr/bin/env bash
alias cd='pushd . >> /dev/null;cd'
alias back='popd >> /dev/null'
alias ld='dirs -p | nl -v 0'
alias rv='revisit'
alias cls='newtab;exit'
# cd variants
alias home='cd ~'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias .3='cd ../../../'
alias .4='cd ../../../../'
alias .5='cd ../../../../..'

alias ll='ls -la'
alias xx='chmod +x'
alias g2='goto'
alias gd='go_deep'
alias gf='go_find'

#history
alias hg='history | grepe '
alias h="history"
alias h1="history 10"
alias h2="history 20"
alias h3="history 30"

# Pretty print the path
alias path='echo $PATH | tr -s ":" "\n"'

function grepe {
    grep $1 | grep --color -E "$1|$" $2
}

# Create a new directory and enter it
function mkd() {
	mkdir -p "$@" && cd "$_";
}

# Change working directory to the top-most Finder window location
function cdf() { # short for `cdfinder`
	cd "$(osascript -e 'tell app "Finder" to POSIX path of (insertion location as alias)')";
}


newtab() {
  osascript -e 'tell application "Terminal" to activate' -e 'tell application "System Events" to tell process "Terminal" to keystroke "t" using command down'
  if [ $# -gt 0 ]; then
    cmd="tell application \"Terminal\" to do script \"$@\" in front window"
    osascript \
      -e "tell application \"Terminal\" to activate" \
      -e "$cmd" &> /dev/null
  fi
}

# mkdir and go to it or go to it if already existing
mkd() {
  if [ ! -d "$1" ];
  then
    mkdir "$@"
  fi
  cd "$@"
}

# go back in navigation history
b() {
  [ -z "$1" ] && local c=1 || local c=$1
  for ((i=1; i<=$c; i++))
  do
    back
  done
}

revisit() {
  export choice_set=`dirs -p | grep -i ".*$1.*"`
  get_choice
  [ "$choice_set" != "" ] && eval "cd $choice_set"
}

# go to directory that matches search
goto() {
  export choice_set=`ls -AF1 | grep "/" | grep -i ".*$1.*"` #ls -ad *$1*/ 2>/dev/null
  get_choice
  [ "$choice_set" != "" ] && cd "$choice_set"
}

go_deep() {
  export choice_set=`find . -type d | grep -i ".*$1.*"`
  get_choice $@
  [ "$choice_set" != "" ] && cd "$choice_set"
}

go_find() {
  export choice_set=`find . | grep -i ".*$1.*"`
  get_choice $1
  [ "$choice_set" != "" ] && ([ ! -z $2 ] && cd $(dirname "$choice_set") || eval "$2$choice_set$3")
}

help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi
