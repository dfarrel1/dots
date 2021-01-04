#!/usr/bin/env bash
# bash 3+

bash3_dict_lookup() {
    # takes an array of colon separated strings and looks up 
    # right side (val) given left side (key)
    [ $# -lt 2 ] && { echo "Usage: bash3_dict_lookup <KEY> <A[@]>"; return 1; }
    local SEARCH_KEY="$1"   # Save the search key
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
