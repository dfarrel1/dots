#!/usr/bin/env bash

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# aws-vault (set on a per repo basis with ./.envrc)
[[ ! -f ~/.envrc ]] && touch ~/.envrc && ln -fs "${HERE}/.envrc" ~/.envrc

# copy last command
pb() {
    fc -lnr -1 | awk '{$1=$1};1' | tr -d '\n' | pbcopy 
}

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
