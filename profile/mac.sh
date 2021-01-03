#!/usr/bin/env bash
# needs bash >= 4
alias src="source ~/.bashrc"
alias snowsql='/Applications/SnowSQL.app/Contents/MacOS/snowsql'
alias whatami='ps -p $$'
alias syslog='tail -f /var/log/system.log'
alias ipecho='curl ipecho.net/plain ; echo'
alias myip="ifconfig en0 | grep inet | grep -v inet6 | cut -d ' ' -f2"
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

# this is redundant w/ aws-vault; will prob deprecate
awskeys() {        
    VAULT_NAME="dene"
    ITEM_NAME="'rogue-ci AWS key'"
    OP_CLOUD_ACCOUNT='dds'
    SESSION_NAME="OP_SESSION_$OP_CLOUD_ACCOUNT"
    eval "export ${SESSION_NAME}=$(1p session)" 
    ITEM=`1p get item "${ITEM_NAME}" --vault=$VAULT_NAME`
    export AWS_ACCESS_KEY_ID=`echo $ITEM | jq -Mcr '.details.fields[] | select(.name=="username") | .value'`
    export AWS_SECRET_ACCESS_KEY=`echo $ITEM | jq -Mcr '.details.fields[] | select(.name=="password") | .value'`
}

awskeys_selfcontained() {
    # independent of '1p'           
    if [ ! $OP_SESSION_dds ]; then
        eval $(op signin dds);
    else
        op list users > /dev/null 2>&1 
        test $? -eq 0 || eval $(op signin dds);
    fi;
    VAULT_NAME="dene"
    ITEM_NAME="rogue-ci AWS key"
    ITEM=`op get item "$ITEM_NAME" --vault=$VAULT_NAME`    
    export AWS_ACCESS_KEY_ID=`echo $ITEM | jq -Mcr '.details.fields[] | select(.name=="username") | .value'`
    export AWS_SECRET_ACCESS_KEY=`echo $ITEM | jq -Mcr '.details.fields[] | select(.name=="password") | .value'`
 }


bash3_dict_lookup() {
    # takes an array of colon separated strings and looks up 
    # right side (val) given left side (key)
    [ $# -lt 2 ] && { echo "Usage: bash3_dict_lookup <KEY> <A[@]>"; return 1; }
    local SEARCH_KEY="$1"   # Save first argument in a variable
    shift                   # Shift all arguments to the left (original $1 gets lost)
    local ARRAY=("$@")      # Rebuild the array with rest of arguments    
    local KEY_IS_IN_DICT=false    
    for pairing in "${ARRAY[@]}" ; do
        KEY="${pairing%%:*}"; VALUE="${pairing##*:}"
        if [ "$KEY" = "$SEARCH_KEY" ]; then
            KEY_IS_IN_DICT=true
            FOUND_VALUE=$VALUE
        fi
    done
    if $KEY_IS_IN_DICT ; then
        echo "${FOUND_VALUE}"
    else
        echo "KEY "${SEARCH_KEY}" not found."
        return 1
    fi
}

mfa_bash3() {
    # leverages op_session.sh script to get OTP; bash 3 compliant
    [ $# -eq 0 ] && { echo "Usage: mfa_bash3 <provider>"; return 1; }
    local PROVIDER=$1; unset SECRET_NAME;
    local SECRETS_ARRAY=( \
        "aws:AWS rogue-ci Login"
        "github:DDS Github" 
        "gitlab:Gitlab Rogue Squadron" 
        "rogue-master:AWS rogue-master Login" )
    local ON_FAILURE="echo \"Provider \\\"${PROVIDER}\\\" not recognized. Exiting mfa.\";  return 1"  
    local SECRET_NAME 
    # local is a command itself and its exit-code will overwrite that of the assigned function   
    SECRET_NAME=$(bash3_dict_lookup  "${PROVIDER}" "${SECRETS_ARRAY[@]}" )
    [ $? = 0 ] || eval ${ON_FAILURE}
    OP_CLOUD_ACCOUNT='dds'
    SESSION_NAME="OP_SESSION_$OP_CLOUD_ACCOUNT"
    eval "export ${SESSION_NAME}=$(1p session)"      
    1p get totp "'"${SECRET_NAME}"'" | tr -d '\n' | pbcopy && pbpaste && echo ''
}

# TODO -- choose pure 'op' or op_session.sh implementation
mfa_bash3_selfcontained() {
    # leverages 1password cli 'op' to get OTP; bash 3 compliant
    [ $# -eq 0 ] && { echo "Usage: mfa_bash3 <provider>"; return 1; }
    local PROVIDER=$1; unset SECRET_NAME;    
    local SECRETS_ARRAY=( \
        "aws:AWS rogue-ci Login"
        "github:DDS Github" 
        "gitlab:Gitlab Rogue Squadron" 
        "rogue-master:AWS rogue-master Login" )
    local ON_FAILURE="echo \"Provider \\\"${PROVIDER}\\\" not recognized. Exiting mfa.\";  return 1"  
    local SECRET_NAME 
    # local is a command itself and its exit-code will overwrite that of the assigned function   
    SECRET_NAME=$(bash3_dict_lookup  "${PROVIDER}" "${SECRETS_ARRAY[@]}" )
    [ $? = 0 ] || eval ${ON_FAILURE}   
    ONEPASS_ALIAS="dds"
    if [ ! $OP_SESSION_${ONEPASS_ALIAS} ]; then
        eval $(op signin $ONEPASS_ALIAS);
    else
        op list users > /dev/null 2>&1 
        test $? -eq 0 || eval $(op signin $ONEPASS_ALIAS);
    fi;    
    op get totp "${SECRET_NAME}" | tr -d '\n' | pbcopy && pbpaste && echo ''
}

mfa() {
    # requires bash >= 4
    # # leverages op_session.sh script to get OTP
    [ $# -eq 0 ] && { echo "Usage: mfa <provider>"; return 1; }
    local PROVIDER=$1; unset SECRET_NAME;        
    declare -A SECRETS_ARRAY
    local SECRETS_ARRAY=( \
              ["aws"]="AWS rogue-ci Login" \
              ["github"]="DDS Github" \
              ["gitlab"]="Gitlab Rogue Squadron" \
              ["rogue-master"]="AWS rogue-master Login" )
    local ON_FAILURE="echo \"Provider \\\"${PROVIDER}\\\" not recognized. Exiting mfa.\";  return 1"
    { [ ${SECRETS_ARRAY[$PROVIDER]+exists} ] && local SECRET_NAME="${SECRETS_ARRAY[$PROVIDER]}"; } || eval ${ON_FAILURE}        
    OP_CLOUD_ACCOUNT='dds'
    SESSION_NAME="OP_SESSION_$OP_CLOUD_ACCOUNT"
    eval "export ${SESSION_NAME}=$(1p session)"
    1p get totp "'"${SECRET_NAME}"'" | tr -d '\n' | pbcopy && pbpaste && echo ''    
    
}

# TODO -- choose pure 'op' or op_session.sh implementation
mfa_selfcontained() {
    # requires bash >= 4
    # leverages 1password cli 'op' to get OTP
    [ $# -eq 0 ] && { echo "Usage: mfa <provider>"; return 1; }
    local PROVIDER=$1; unset SECRET_NAME;        
    declare -A SECRETS_ARRAY
    local SECRETS_ARRAY=( \
              ["aws"]="AWS rogue-ci Login" \
              ["github"]="DDS Github" \
              ["gitlab"]="Gitlab Rogue Squadron" \
              ["rogue-master"]="AWS rogue-master Login" )
    local ON_FAILURE="echo \"Provider \\\"${PROVIDER}\\\" not recognized. Exiting mfa.\";  return 1"
    { [ ${SECRETS_ARRAY[$PROVIDER]+exists} ] && local SECRET_NAME="${SECRETS_ARRAY[$PROVIDER]}"; } || eval ${ON_FAILURE}        
    ONEPASS_ALIAS="dds"
    if [ ! $OP_SESSION_${ONEPASS_ALIAS} ]; then
        eval $(op signin $ONEPASS_ALIAS);
    else
        op list users > /dev/null 2>&1 
        test $? -eq 0 || eval $(op signin $ONEPASS_ALIAS);
    fi;    
    op get totp "${SECRET_NAME}" | tr -d '\n' | pbcopy && pbpaste && echo ''    
}

console() {
    aws-vault login rogue-ci-admin --mfa-token $(mfa aws | tr -d '\n')
}

help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi

