#!/usr/bin/env bash
# requires gnu-sed
# export PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"
# for 'sed -r'
# (PATH modified in aws.sh)
#
# starts (or restarts) a 1password cli session, sets 30 minute countdown variable
# use: OP_CLOUD_ACCOUNT="[your-account-name]" source /path/to/op_session.sh command
# e.g.: OP_CLOUD_ACCOUNT="familyname" source ~/op_session.sh get account

check_session(){
    # attempt sign in if session is not active
    if ! op get account &> /dev/null; then
        # try loading global session file before logging in anew       
        [[ -f ~/.op_session ]] && source ~/.op_session
        if ! op get account &> /dev/null; then
            signin
            check_session
        fi
    fi    
}

main(){
    # directly pass inactive session args
    case "$*" in
        "" )
            op;;
        --help )
            op --help;;
        --version )
            op --version;;
        signin )
            op signin
            reset_timeout
            update_session_file
            ;;
        signout )
            op signout
            unset OP_EXPIRATION OP_SESSION_"$OP_CLOUD_ACCOUNT"
            ;;
        update )
            op update;;
        session )
            check_session
            eval "echo \$OP_SESSION_$OP_CLOUD_ACCOUNT"
            ;;
        * ) # active session required for everything else
            check_session
            eval "op $*"
            reset_timeout
            update_session_file
            ;;
    esac
}

reset_timeout(){
    # reset 30 min countdown
    OS_TYPE=$(uname -s)
    if [ "$OS_TYPE" = Darwin ]; then # MacOS
        OP_EXPIRATION_TIME=$(date -v +30M -u +%s)
    elif [ "$OS_TYPE" = Linux ]; then
        OP_EXPIRATION_TIME=$(date -d '+30 min' -u +%s)
    fi
    export OP_EXPIRATION="$OP_EXPIRATION_TIME"    
}

signin(){
    token=$(op signin "$OP_CLOUD_ACCOUNT" --raw)    
    export OP_SESSION_"$OP_CLOUD_ACCOUNT"="$token"
    reset_timeout
    update_session_file
}

update_session_file(){
    SESSION_NAME="OP_SESSION_$OP_CLOUD_ACCOUNT"
    echo """
    export $SESSION_NAME=${!SESSION_NAME}
    export OP_EXPIRATION="$OP_EXPIRATION_TIME"
    """ | awk '{$1=$1};1' | sed -r '/^\s*$/d' > ~/.op_session
}

main "$*"
