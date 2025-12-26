

# TODO -- choose pure 'op' or op_session.sh implementation
awskeys_selfcontained() {
    # independent of '1p'           
    if [ ! $OP_SESSION_dds ]; then
        eval $(op signin dds);
    else
        op list users > /dev/null 2>&1 
        test $? -eq 0 || eval $(op signin dds);
    fi;
    VAULT_NAME="dene"
    choose_aws_secret
    ITEM=`op get item "$choice_set" --vault=$VAULT_NAME`    
    export AWS_ACCESS_KEY_ID=`echo $ITEM | jq -Mcr '.details.sections[] | select(.title=="ACCOUNT_INFO").fields[] | select(.t=="ACCESS_KEY_ID") | .v'`
    export AWS_ACCESS_KEY_SECRET=`echo $ITEM | jq -Mcr '.details.sections[] | select(.title=="ACCOUNT_INFO").fields[] | select(.t=="ACCESS_KEY_SECRET") | .v'`
 }

mfa_deprecated() {
    # deprecated -- changed to using a file for the array and get_choice() for the mechanism
    [ $# -eq 0 ] && { echo "Usage: mfa <provider>"; return 1; }
    local PROVIDER=$1; unset SECRET_NAME;        
    declare -A SECRETS_ARRAY
    # TODOD -- move VPN MFA to 1Pass
    local SECRETS_ARRAY=( \
              ["rogue"]="AWS rogue-ci-govcloud" \
              ["github"]="DDS Github" \
              ["gitlab"]="Gitlab Rogue Squadron" \
              ["cuas-dev"]="AWS dds-cuas-dev-govcloud")
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
    local ARR=("exit")     
    while read -r col1
    do         
        ARR+=("$col1")
    done <"${HERE}/picklists/dds-all-mfa"
    [[ $# -lt 2 ]] && choice_set=`printf '%s\n' "${ARR[@]}"` && get_choice
    local ON_FAILURE="echo \"Provider \\\"${PROVIDER}\\\" not recognized. Exiting mfa.\";  return 1"
    { local SECRET_NAME=$choice_set; } || eval ${ON_FAILURE} 
    echo ${SECRET_NAME}       
    ONEPASS_ALIAS="dds"
    if [ ! $OP_SESSION_${ONEPASS_ALIAS} ]; then
        eval $(op signin $ONEPASS_ALIAS);
    else
        op list users > /dev/null 2>&1 
        test $? -eq 0 || eval $(op signin $ONEPASS_ALIAS);
    fi;    
    op get totp "${SECRET_NAME}" | tr -d '\n' | pbcopy && pbpaste && echo ''    
}
