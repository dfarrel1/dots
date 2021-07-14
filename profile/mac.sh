#!/usr/bin/env bash
# needs bash >= 4
alias src="source ~/.bashrc"
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
    local koala='\[\e[1;32m\][\W] \[\e[1;37m\] @( * O * )@ \[\e[0m\] $ ' 
    local dance='\[\e[1;32m\][\W] \[\e[1;33m\] ‎(/.__.)/   \(.__.\) \[\e[0m\] $ '
    local long='\[\e[0;33m\]\u\[\e[0m\]@\[\e[0;32m\]\h\[\e[0m\]:\[\e[0;34m\]\w\[\e[0m\]\$ '
    local sers='\[\e[1;33m\](ಠ_ಠ) \[\e[0m\] '
    local ARR=('dflt' 'flip' 'pus' 'wdir' 'ogre' 'chick' 'zoid' 'long' 'koala' 'dance', 'sers')
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
    for i in {1..16}
    do
       EAGLE_NUM=$(printf "%02d" $i)
       EAGLE="ASCII_EAGLE_${EAGLE_NUM}"
       FILE="${HERE}/ascii_art/eagle_${EAGLE_NUM}"
       eval "export ${EAGLE}=\`cat ${FILE}\`"
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

get_list_of_aws_secrets() {
    VAULT_NAME="dene"        
    OP_CLOUD_ACCOUNT='dds'
    SESSION_NAME="OP_SESSION_$OP_CLOUD_ACCOUNT"
    eval "export ${SESSION_NAME}=$(1p session)"     
    1p list items --vault=$VAULT_NAME --tags aws --categories login | jq -Mcr '.[].overview.title'
}

choose_aws_secret() {
    local ARR=("exit")         
    while read -r line; do                 
        ARR+=( "$line" )        
    done <<< $(get_list_of_aws_secrets)        
    # to point to a file:
    # done <"${HERE}/picklists/dds-aws"           
    [[ $# -lt 2 ]] && choice_set=`printf '%s\n' "${ARR[@]}"` && get_choice    
    local ON_FAILURE="echo \" \\\"${choice_set}\\\" not recognized. Exiting mfa.\";  return 1"
    { local SECRET_NAME=$choice_set; } || eval ${ON_FAILURE} 
    # choice globally stored as "$choice_set"
}

get_aws_acct_info() {
    choose_aws_secret
    VAULT_NAME="dene"        
    OP_CLOUD_ACCOUNT='dds'
    SESSION_NAME="OP_SESSION_$OP_CLOUD_ACCOUNT"
    eval "export ${SESSION_NAME}=$(1p session)"     
    export TMP_GLOBAL_ACCOUNT_INFO=`1p get item \"${choice_set}\" --vault=$VAULT_NAME | jq -Mcr '.details.sections[] | select(.title=="ACCOUNT_INFO").fields'`    
}

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

newawslogin() {
    OP_CLOUD_ACCOUNT='dds'
    SESSION_NAME="OP_SESSION_$OP_CLOUD_ACCOUNT"
    eval "export ${SESSION_NAME}=$(1p session)"    
    1p create item login "$(op encode < ${HERE}/aws.template.json)" \
        --vault dene \
        --title "AWS-Template" \
        --generate-password \
        --tags "aws" \
        --url https://signin.amazonaws-us-gov.com/console
    
}

newawsprofile() {
    get_aws_acct_info
    ACCOUNT_ID=`echo $TMP_GLOBAL_ACCOUNT_INFO | jq -Mcr '.[] | select(.t=="ACCOUNT_ID") | .v'`
    ACCOUNT_TYPE=`echo $TMP_GLOBAL_ACCOUNT_INFO | jq -Mcr '.[] | select(.t=="ACCOUNT_TYPE") | .v'`
    AWS_PROFILE_NAME=`echo $TMP_GLOBAL_ACCOUNT_INFO | jq -Mcr '.[] | select(.t=="AWS_PROFILE_NAME") | .v'`
    USER_NAME=`echo $TMP_GLOBAL_ACCOUNT_INFO | jq -Mcr '.[] | select(.t=="USER_NAME") | .v'`

    SEARCH_STR="[profile ${AWS_PROFILE_NAME}]"
    if grep -Fxq "${SEARCH_STR}" ~/.aws/config
    then
        echo "Profile already exists."
        grep -Fn -A 4 "${SEARCH_STR}" ~/.aws/config
    else
        echo "Profile does not exist; creating now."
        echo """
        [profile ${AWS_PROFILE_NAME}]
        region=us-gov-west-1
        output=json
        mfa_serial=arn:aws-us-gov:iam::${ACCOUNT_ID}:mfa/${USER_NAME}
        """ | awk '{$1=$1};1' >> ~/.aws/config
    fi

}

awslogin() {
    choose_aws_secret
    VAULT_NAME="dene"        
    OP_CLOUD_ACCOUNT='dds'
    SESSION_NAME="OP_SESSION_$OP_CLOUD_ACCOUNT"
    eval "export ${SESSION_NAME}=$(1p session)"     
    ITEM=`1p get item \"${choice_set}\" --vault=$VAULT_NAME`
    export AWS_VAULT_PROFILE_NAME=`echo $ITEM | jq -Mcr '.details.sections[] | select(.title=="ACCOUNT_INFO").fields[] | select(.t=="AWS_VAULT_PROFILE_NAME") | .v'`
    echo "aws-vault profile: $AWS_VAULT_PROFILE_NAME"
    read -n 1 -p "Normal or Incognito? (N/i) " ans;

    case $ans in
        i|I)
            export extra_chrome_opts=" --args --incognito ";;
        *)
            export extra_chrome_opts=" ";;
    esac
    # dummy arg tells it to use the choice_set already provided in env
    mfa dummy
    aws-vault --debug login ${AWS_VAULT_PROFILE_NAME} --stdout \
    | xargs -t /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome ${extra_chrome_opts} --new-window
    
    # TODO - why does the following line fail to access $choice_set
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

