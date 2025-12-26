#!/usr/bin/env bash

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# op_session.sh needs gnu-sed
export PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"

# aws-vault (set on a per repo basis with ./.envrc)
[[ ! -f ~/.envrc ]] && touch ~/.envrc && ln -fs "${HERE}/.envrc" ~/.envrc

# copy last command
pb() {
    fc -lnr -1 | awk '{$1=$1};1' | tr -d '\n' | pbcopy 
}

alias 1p="OP_CLOUD_ACCOUNT='dds' source ${HERE}/op_session.sh"

get_list_of_tagged_secrets() {
    # expects first (only) argument to be tag name
    # need to establish default IFS within function
    O_IFS=$IFS    
    unset IFS
    OP_CLOUD_ACCOUNT='dds'
    SESSION_NAME="OP_SESSION_$OP_CLOUD_ACCOUNT"
    eval "export ${SESSION_NAME}=$(1p session)"  
    1p list items --tags $1 --categories login | jq -Mcr '.[].overview.title' | sort
    IFS=$0_IFS  
}

filter_array() {
    # first arg is name of array var
    # second arg is string to filter on
    # TODO: force exit from "choose_aws_secret" on empty set 
    if [ ${BASH_VERSINFO[0]} -lt 4 ]; then
        # this section should never get hit
        echo "BASH_VERSION: ${BASH_VERSION}"
        echo "array vars cannot be filtered on bash versions < 4"
        return 1
    else
        local -n INPUT_ARR=$1
        local FILTER_VAL=$2
        local OUTPUT_ARR=()
        O_IFS=$IFS    
        IFS=$'\n'
        for i in ${INPUT_ARR[*]}
        do
            echo $i | grep ${FILTER_VAL}>/dev/null && OUTPUT_ARR+=( "$i" )
        done
        IFS=${O_IFS}    
        if [ ${#OUTPUT_ARR[@]} -eq 0 ]; then
            exit 1
        else
            printf '%s\n' "${OUTPUT_ARR[@]}"
        fi
    fi
}

choose_aws_secret() {
    IFS=$'\n'
    local ARR=("exit")         
    ARR+=($(get_list_of_tagged_secrets "aws"))
    
    # deprecated approach -- oddly stopped working out of the blue
    # I'm thinking it was related to some weird bash version switching behavior
    # while read -r line; do
    #     echo $line                
    #     ARR+=( "$line" )        
    # done <<< $(get_list_of_tagged_secrets "aws")
     
    if [[ $# -eq 1 ]]; then
        if [ ${BASH_VERSINFO[0]} -ge 4 ]; then
            echo "using filter_array"
            filter_array ARR $1
            choice_set=`filter_array ARR $1` && get_choice \
            || { echo "search for \"$1\" returned empty." && return 1; }
        else
            echo "cannot filter because using bash $BASH_VERSION"
            echo "\"chsh -s /usr/local/bin/bash\" to update bash."
            return 1
        fi
    else        
        [[ $# -eq 0 ]] && choice_set=`printf '%s\n' "${ARR[@]}"` && get_choice
    fi
    unset IFS
    local ON_FAILURE="echo \" \\\"${choice_set}\\\" not recognized. Exiting choose_aws_secret.\";  return 1"   
    { local SECRET_NAME=$choice_set; } || eval ${ON_FAILURE} 
    # choice globally stored as "$choice_set"
}

get_aws_acct_info() {
    choose_aws_secret    
    OP_CLOUD_ACCOUNT='dds'
    SESSION_NAME="OP_SESSION_$OP_CLOUD_ACCOUNT"
    eval "export ${SESSION_NAME}=$(1p session)"     
    export TMP_GLOBAL_ACCOUNT_INFO=`1p get item \"${choice_set}\" | jq -Mcr '.details.sections[] | select(.title=="ACCOUNT_INFO").fields'`    
}

awskeys() {      
    choose_aws_secret            
    OP_CLOUD_ACCOUNT='dds'
    SESSION_NAME="OP_SESSION_$OP_CLOUD_ACCOUNT"
    eval "export ${SESSION_NAME}=$(1p session)"     
    ITEM=`1p get item \"${choice_set}\"`
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
            done <<< $(get_list_of_tagged_secrets "mfa") 
            [[ $# -lt 2 ]] && choice_set=`printf '%s\n' "${ARR[@]}"` && get_choice
            local ON_FAILURE="echo \"Provider \\\"${PROVIDER}\\\" not recognized. Exiting mfa.\";  return 1"
            { local SECRET_NAME=$choice_set; } || eval ${ON_FAILURE}
    else
        local SECRET_NAME=$1
    fi
     
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
        --title 'Template--[AWS]' \
        --generate-password \
        --tags "aws,mfa" \
        --url "https://signin.amazonaws-us-gov.com/console"
}

newawsprofile() {
    # create new aws profile from 1p secret
    get_aws_acct_info
    ACCOUNT_ID=`echo $TMP_GLOBAL_ACCOUNT_INFO | jq -Mcr '.[] | select(.t=="ACCOUNT_ID") | .v'`
    ACCOUNT_TYPE=`echo $TMP_GLOBAL_ACCOUNT_INFO | jq -Mcr '.[] | select(.t=="ACCOUNT_TYPE") | .v'`
    AWS_PROFILE_NAME=`echo $TMP_GLOBAL_ACCOUNT_INFO | jq -Mcr '.[] | select(.t=="AWS_PROFILE_NAME") | .v'`
    USER_NAME=`echo $TMP_GLOBAL_ACCOUNT_INFO | jq -Mcr '.[] | select(.t=="USER_NAME") | .v'`
    SEARCH_STR="[profile ${AWS_PROFILE_NAME}]"
    export AWS_ACCESS_KEY_ID=`echo $TMP_GLOBAL_ACCOUNT_INFO | jq -Mcr '.[] | select(.t=="ACCESS_KEY_ID") | .v'`
    export AWS_SECRET_ACCESS_KEY=`echo $TMP_GLOBAL_ACCOUNT_INFO | jq -Mcr '.[] | select(.t=="ACCESS_KEY_SECRET") | .v'`
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
    aws-vault add $AWS_PROFILE_NAME --env
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY

}
#  moved to https://github.com/deptofdefense/awslogin
# TODO -- REMOVEME
awsloginbash() {           
    OP_CLOUD_ACCOUNT='dds'
    export SESSION_NAME="OP_SESSION_$OP_CLOUD_ACCOUNT"
    eval "export ${SESSION_NAME}=$(1p session)"
    
    # TODO: converge both methods to one (regardless of input argument presence)
    if [[ $# -eq 1 ]]; then 
        choose_aws_secret $1  || { echo "exiting awslogin." && return 1; }
    else
        choose_aws_secret
    fi
    ITEM=`1p get item \"${choice_set}\"`    
    export AWS_PROFILE_NAME=`echo $ITEM | jq -Mcr '.details.sections[] | select(.title=="ACCOUNT_INFO").fields[] | select(.t=="AWS_PROFILE_NAME") | .v'`  
    echo "aws-vault profile: $AWS_PROFILE_NAME"
    read -n 1 -p "Normal(chrome)/Incognito(chrome)/Canary(Normal)/Safari(Normal)? (N/i/c/s) " ans;

    case $ans in
        i|I)            
            export browser_items=( "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" )
            browser_items+=( "--new-window" "--args" "--incognito" );;
        c|C)            
            export browser_items=( "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary" )
            browser_items+=( "--new-window" );;
        s|S)     
            export browser_items=( "open" "-a" )
            browser_items+=( "/Applications/Safari.app/Contents/MacOS/Safari" );;                        
        *)
            export browser_items=( "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" )
            browser_items+=( "--new-window" );;
    esac

    otp_val=`mfa "$choice_set"`
    aws-vault --debug login ${AWS_PROFILE_NAME} --mfa-token ${otp_val} --stdout \
    | xargs -t "${browser_items[@]}"
       
}

help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi

