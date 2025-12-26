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



splasher() {
    # 1. Set the type you want (SWORD, DRAGON, etc.)
    local art_type="SWORD"
    
    # 2. Find all matching files into an array
    # Pattern matches: .../ascii_art/ASCII_SWORD_01, ASCII_SWORD_02, etc.
    local files=("${HERE}/ascii_art/${art_type}/ASCII_${art_type}_"*)

    # 3. Check if we actually found files
    if [[ ! -e "${files[0]}" ]]; then
        echo "No ASCII art found for type: ${art_type}"
        return
    fi

    # 4. Pick a random index based on the number of files found
    # bash 5.1+ can use SRANDOM, otherwise RANDOM is fine
    local rand_idx=$(( RANDOM % ${#files[@]} ))
    local selected_file="${files[$rand_idx]}"

    # 5. Print with formatting
    local cyn="\e[1;36m"
    local end="\e[0m"

    # We use 'cat' directly on the file, simpler and safer than 'eval'
    printf "${cyn}\n\n"
    cat "$selected_file"
    printf "\n\n${end}"
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

tart() 
# run a random tarts screensaver
{
    "${HERE}/ascii_art/tarts/run_random_tarts.sh"
}

help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi
