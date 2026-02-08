#!/usr/bin/env bash
alias cd='pushd . >> /dev/null;cd' # @desc pushd wrapper that saves directory history
alias back='popd >> /dev/null'
alias ld='dirs -p | nl -v 0' # @desc List directory stack with indices
alias rv='revisit' # @desc Shorthand for revisit
alias cls='newtab;exit' # @desc Open new tab and close current
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
alias xx='chmod +x' # @desc Make file executable
alias g2='goto' # @desc Shorthand for goto
alias gd='go_deep' # @desc Shorthand for go_deep
alias gf='go_find' # @desc Shorthand for go_find

#history
alias hg='history | grepe ' # @desc History grep with highlighting
alias h="history"
alias h1="history 10"
alias h2="history 20"
alias h3="history 30"

# Pretty print the path
alias path='echo $PATH | tr -s ":" "\n"'

# @desc Grep with highlighted matches
# @usage command | grepe <pattern>
function grepe {
    grep $1 | grep --color -E "$1|$" $2
}

# Create a new directory and enter it
# @desc Create directory and cd into it
# @usage mkd <dir_name>
function mkd() {
	mkdir -p "$@" && cd "$_";
}

# Change working directory to the top-most Finder window location
# @desc cd to the frontmost Finder window location
# @usage cdf
function cdf() { # short for `cdfinder`
	cd "$(osascript -e 'tell app "Finder" to POSIX path of (insertion location as alias)')";
}


# @desc Open a new Terminal tab, optionally running a command in it
# @usage newtab [command]
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
# @desc Create directory if not exists, then cd into it
# @usage mkd <dir_name>
mkd() {
  if [ ! -d "$1" ];
  then
    mkdir "$@"
  fi
  cd "$@"
}

# go back in navigation history
# @desc Go back N entries in the directory stack (default: 1)
# @usage b [N]
b() {
  [ -z "$1" ] && local c=1 || local c=$1
  for ((i=1; i<=$c; i++))
  do
    back
  done
}

# @desc Fuzzy search the directory stack and cd to a match
# @usage revisit [search_term]
revisit() {
  export choice_set=`dirs -p | grep -i ".*$1.*"`
  get_choice
  [ "$choice_set" != "" ] && eval "cd $choice_set"
}

# go to directory that matches search
# @desc Fuzzy search current directory's subdirectories and cd to match
# @usage goto [search_term]
goto() {
  export choice_set=`ls -AF1 | grep "/" | grep -i ".*$1.*"` #ls -ad *$1*/ 2>/dev/null
  get_choice
  [ "$choice_set" != "" ] && cd "$choice_set"
}

# @desc Recursive fuzzy directory search from current location
# @usage go_deep [search_term]
go_deep() {
  export choice_set=`find . -type d | grep -i ".*$1.*"`
  get_choice $@
  [ "$choice_set" != "" ] && cd "$choice_set"
}

# @desc Recursive fuzzy file search from current location
# @usage go_find [search_term]
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
