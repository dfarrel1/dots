#!/usr/bin/env bash

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# custom prompts
export PS1='\[\e[1;32m\][\W] \[\e[1;31m\] (V) (°,,,°) (V) \[\e[0m\] $ ' 

chp() {    
    local dflt='\h:\W \u\$'
    local flip='\[\e[1;33m\](/•-•)/ \[\e[1;32m\]>\[\e[0m\] '
    local pus='[\W] 🐙  ' 
    local wdir='\[\e[1;33m\][ \W ]\[\e[0m\] $ '
    local ogre='\[\e[0;33m\]\u\[\e[0m\]@\[\e[1;32m\][\W]\[\e[0m\]👹 ' 
    local chick='\[\e[0;33m\]\u\[\e[0m\]@\[\e[1;32m\][\W]\[\e[0m\]🐣 ' 
    local zoid='\[\e[1;32m\][\W] \[\e[1;31m\] (V) (°,,,°) (V) \[\e[0m\] $ ' 
    local koala='\[\e[1;32m\][\W] \[\e[1;37m\] @( * O * )@ \[\e[0m\] $ ' 
    local dance='\[\e[1;32m\][\W] \[\e[1;33m\] ‎(/.__.)/   \(.__.\) \[\e[0m\] $ '
    local long='\[\e[0;33m\]\u\[\e[0m\]@\[\e[0;32m\]\h\[\e[0m\]:\[\e[0;34m\]\w\[\e[0m\]\$ '
    local sers='\[\e[1;33m\](ಠ_ಠ) \[\e[0m\] '
    local ARR=('dflt' 'flip' 'pus' 'wdir' 'ogre' 'chick' 'zoid' 'long' 'koala' 'dance' 'sers')
    [[ $# -eq 0 ]] && choice_set=`printf '%s\n' "${ARR[@]}"` && get_choice
    [[ $# -eq 1 ]] && choice_set=$1

    IFS=@
    case "@${ARR[*]}@" in
        (*"@$choice_set@"*)
            eval "PS1=\$$choice_set";;
        (*)
            echo "${choice_set} is not a valid choice."
            IFS='|'; echo "[${ARR[*]}]";;
    esac
    unset IFS 
}


load_ascii_art() {    
    FILES="${HERE}/ascii_art/ASCII_EAGLE_*"
    for f in $FILES
    do
      name="$(basename ${f})"
      eval "export ${name}=\`cat ${f}\`"
    done
}

unset_ascii_art() {
    FILES="${HERE}/ascii_art/ASCII_EAGLE_*"
    for f in $FILES
    do
      name="$(basename ${f})"
      eval "unset ${name}"
    done
}


splasher() {
    # needs [bash >= 5.1] for SRANDOM
    load_ascii_art    
    EAGLE_NUM=$(printf "%02d" $((1 + SRANDOM % 12)))
    RAND_EAGLE="ASCII_EAGLE_${EAGLE_NUM}"
    cyn="\e[1;36m"
    white_back="\\x1B[47m"
    end=$'\e[0m'
    eval "printf \"${cyn}\n\n%s\n\n${end}\\x1B[49m\n\" \"\${$RAND_EAGLE}\""
    unset_ascii_art
}

idler() {
    osascript -e """
        tell application \"Terminal\" 
            activate
            set currentTab to do script (\"echo \\\"opening window 1\\\"\")     
        end tell
        tell application \"System Events\"
            keystroke \"f\" using {command down, control down}
        end tell
        tell application \"Terminal\"
            do script (\"asciiquarium\")  in currentTab
        end tell
        """
}

help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi
