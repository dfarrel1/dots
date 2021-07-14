#!/usr/bin/env bash
# needs bash >= 4
alias src="source ~/.bashrc"
alias snowsql='/Applications/SnowSQL.app/Contents/MacOS/snowsql'
alias whatami='ps -p $$'
alias syslog='tail -f /var/log/system.log'
alias ipecho='curl ipecho.net/plain ; echo'
alias myip="ipconfig getifaddr en1"
alias whereami='pwd ; ipecho'
alias speed='speedtest-cli'
alias awake='caffeinate &'
alias decaf='killall caffeinate'


HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# aws-vault (set on a per repo basis with ./.envrc)
[[ ! -f ~/.envrc ]] && touch ~/.envrc && ln -fs "${HERE}/.envrc" ~/.envrc

# copy last command
pb() {
    fc -lnr -1 | awk '{$1=$1};1' | tr -d '\n' | pbcopy 
}

# Tell ls to be colourful
export CLICOLOR=1
# shell colors for a black background 
# interactive generator https://geoff.greer.fm/lscolors/
 export LSCOLORS=GxBxhxDxfxhxhxhxhxcxcx # (dirs in cyan)
# export LSCOLORS=Exfxcxdxbxegedabagacad # (dirs in blue)

# Always enable colored `grep` output`
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Homebrew PATH
export PATH="/usr/local/sbin:$PATH"
alias fix_brew_perms='sudo chown -R $(whoami) $(brew --prefix)/*'
alias fix_all_perms='sudo chown -R "$USER":admin /usr/local && sudo chown -R "$USER":admin /Library/Caches/Homebrew'

#for bash error in vscode terminal
update_terminal_cwd() {
    # Identify the directory using a "file:" scheme URL,
    # including the host name to disambiguate local vs.
    # remote connections. Percent-escape spaces.
    local SEARCH=' '
    local REPLACE='%20'
    local PWD_URL="file://$HOSTNAME${PWD//$SEARCH/$REPLACE}"
    printf '\e]7;%s\a' "$PWD_URL"
}

# work out colors later [http://tldp.org/HOWTO/Bash-Prompt-HOWTO/x860.html]

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
    local long='\[\e[0;33m\]\u\[\e[0m\]@\[\e[0;32m\]\h\[\e[0m\]:\[\e[0;34m\]\w\[\e[0m\]\$ '
    local ARR=('dflt' 'flip' 'pus' 'wdir' 'ogre' 'chick' 'zoid' 'long')
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

#update vscode plugins list
alias code-plugs="""
echo '#!/bin/bash' > ${HERE}/../xtra/IDEs/install-vscode-exts.sh \
&& code --list-extensions | xargs -L 1 echo code --install-extension >> \
${HERE}/../xtra/IDEs/install-vscode-exts.sh \
&& chmod +x ${HERE}/../xtra/IDEs/install-vscode-exts.sh
"""

# https://github.com/dvorka/hstr
# managed by homebrew now
# source ${HERE}/.hstrrc

# to include in docs
alias hstr='hstr'

# Json tools (pipe unformatted here to test + prettify JSON)
alias json='python -m json.tool'

alias 1p="OP_CLOUD_ACCOUNT='dds' source ${HERE}/op_session.sh"

choose_aws_secret() {
    local ARR=("exit")     
    while read -r col1
    do         
        ARR+=("$col1")
    done <"${HERE}/picklists/dds-aws"
    [[ $# -lt 2 ]] && choice_set=`printf '%s\n' "${ARR[@]}"` && get_choice    
    local ON_FAILURE="echo \" \\\"${choice_set}\\\" not recognized. Exiting mfa.\";  return 1"
    { local SECRET_NAME=$choice_set; } || eval ${ON_FAILURE} 
    # choice globally stored as "$choice_set"
}

# this is redundant w/ aws-vault; will prob deprecate
awskeys() {      
    choose_aws_secret
    VAULT_NAME="dene"        
    OP_CLOUD_ACCOUNT='dds'
    SESSION_NAME="OP_SESSION_$OP_CLOUD_ACCOUNT"
    eval "export ${SESSION_NAME}=$(1p session)"     
    ITEM=`1p get item \"${choice_set}\" --vault=$VAULT_NAME`
    export AWS_ACCESS_KEY_ID=`echo $ITEM | jq -Mcr '.details.sections[] | select(.title=="ACCOUNT_INFO").fields[] | select(.t=="ACCESS_KEY_ID") | .v'`
    export AWS_ACCESS_KEY_SECRET=`echo $ITEM | jq -Mcr '.details.sections[] | select(.title=="ACCOUNT_INFO").fields[] | select(.t=="ACCESS_KEY_SECRET") | .v'`
}

mfa() {    
    if [ $# -eq 0 ]
        then
            local ARR=("exit")     
            while read -r col1
            do         
                ARR+=("$col1")
            done <"${HERE}/picklists/dds-all-mfa"
            [[ $# -lt 2 ]] && choice_set=`printf '%s\n' "${ARR[@]}"` && get_choice
            local ON_FAILURE="echo \"Provider \\\"${PROVIDER}\\\" not recognized. Exiting mfa.\";  return 1"
    else
        echo "received passed arg: $1"
        echo "using choice_set already in env: $choice_set"
    fi
    { local SECRET_NAME=$choice_set; } || eval ${ON_FAILURE} 
    echo ${SECRET_NAME}       
    OP_CLOUD_ACCOUNT='dds'
    SESSION_NAME="OP_SESSION_$OP_CLOUD_ACCOUNT"
    eval "export ${SESSION_NAME}=$(1p session)"
    1p get totp "'"${SECRET_NAME}"'" | tr -d '\n' | pbcopy && pbpaste && echo '' 
}



console() {
    choose_aws_secret
    VAULT_NAME="dene"        
    OP_CLOUD_ACCOUNT='dds'
    SESSION_NAME="OP_SESSION_$OP_CLOUD_ACCOUNT"
    eval "export ${SESSION_NAME}=$(1p session)"     
    ITEM=`1p get item \"${choice_set}\" --vault=$VAULT_NAME`
    export AWS_VAULT_PROFILE_NAME=`echo $ITEM | jq -Mcr '.details.sections[] | select(.title=="ACCOUNT_INFO").fields[] | select(.t=="AWS_VAULT_PROFILE_NAME") | .v'`
    echo "aws-vault profile: $AWS_VAULT_PROFILE_NAME"
    mfa dummy
    aws-vault login ${AWS_VAULT_PROFILE_NAME}
    # aws-vault login $AWS_VAULT_PROFILE_NAME --mfa-token $(mfa dummy | tr -d '\n')
    
}

help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi

