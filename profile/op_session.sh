#!/usr/bin/env bash
# starts (or restarts) a 1password cli session, sets 30 minute countdown variable
# use: OP_CLOUD_ACCOUNT="[your-account-name]" source /path/to/op_session.sh command
# e.g.: OP_CLOUD_ACCOUNT="familyname" source ~/op_session.sh get account

check_session(){
    # attempt sign in if session is not active
    # echo "(check_session - before) -- OP_SESSION_dds: ${OP_SESSION_dds}"
    if ! op get account &> /dev/null; then
        signin
        check_session
    fi
    # echo "(check_session - after) -- OP_SESSION_dds: ${OP_SESSION_dds}"
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
            op signin;;
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
    token=$(op signin "$OP_CLOUD_ACCOUNT" | \
        grep 'export' | \
        awk -F\" '{print $2}'
    )
    export OP_SESSION_"$OP_CLOUD_ACCOUNT"="$token"
    # echo "(signin) -- OP_SESSION_dds: ${OP_SESSION_dds}"
}

main "$*"
