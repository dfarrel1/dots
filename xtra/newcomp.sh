#!/bin/bash

# reminders:
# set vscode settings: dots/IDES/vscode-settings.md
# set cursor speed to max in terminal, keyboard settings


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

#brew stuff

#install from Brewfile
BREW_STATE_FILE=$SCRIPT_DIR/newcompstate_brewcomplete
if [[ -f "$BREW_STATE_FILE" ]]; then
    echo "$BREW_STATE_FILE exists."
else
    #install homebrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # configure mac machine with Brewfile
    brew bundle install --file=${SCRIPT_DIR}/Brewfile
    touch $BREW_STATE_FILE
fi

# OP stuff
# TODO upgrade to OP CLI Version 2
# CLI Version 1 must be manually downloaded from here:
# https://app-updates.agilebits.com/product_history/CLI
OP_STATE_FILE=$SCRIPT_DIR/newcompstate_opcomplete
if [[ -f "$OP_STATE_FILE" ]]; then
    echo "$OP_STATE_FILE exists."
else
    op_site="https://defense-digital-service.1password.com"
    op_user="dene@dds.mil"
    OP_CLOUD_ACCOUNT='dds'
    op signin ${op_site} ${op_user} --shorthand ${OP_CLOUD_ACCOUNT}
    touch $OP_STATE_FILE
fi

#ssh stuff
SSH_STATE_FILE=$SCRIPT_DIR/newcompstate_sshcomplete
if [[ -f "$SSH_STATE_FILE" ]]; then
    echo "$SSH_STATE_FILE exists."
else

    echo "adding ssh keys from 1pass to machine files"
    OP_CLOUD_ACCOUNT='dds'
    SESSION_NAME="OP_SESSION_$OP_CLOUD_ACCOUNT"
    eval "export ${SESSION_NAME}=$(op signin --account ${OP_CLOUD_ACCOUNT} --raw)"
    VAULT_NAME="DDS-DENE-ssh"    
    op_items=$(op list items --vault $VAULT_NAME | jq -Mcr '.[].overview.title' | sort)
    for word in $op_items; do
        echo $word              
        op get document --vault $VAULT_NAME "$word" --output ~/.ssh/${word}
    done
    cat ~/.ssh/config

    echo "adding ssh keys from machine files to machine ssh agent"
    for possiblekey in ${HOME}/.ssh/id_*; do
        if grep -q PRIVATE "$possiblekey"; then
            ssh-add "$possiblekey"
        fi
    done
    touch $SSH_STATE_FILE
fi

#aws stuff
AWS_STATE_FILE=$SCRIPT_DIR/newcompstate_awscomplete
if [[ -f "$AWS_STATE_FILE" ]]; then
    echo "$AWS_STATE_FILE exists."
else
    echo "adding all \'newfile\' tagged files to the home dir"    
    OP_CLOUD_ACCOUNT='dds'
    SESSION_NAME="OP_SESSION_$OP_CLOUD_ACCOUNT"
    eval "export ${SESSION_NAME}=$(op signin --account ${OP_CLOUD_ACCOUNT} --raw)"
    VAULT_NAME="dene"    
    op_items=$(op list items --vault $VAULT_NAME --tags 'newcomp' | jq -Mcr '.[].overview.title' | sort)
    for word in $op_items; do
        echo $word              
        op get document --vault $VAULT_NAME "$word" --output ~/${word}        
    done

    O_IFS=$IFS    
    IFS=$'\n'    
    op_items=( $(op list items --vault $VAULT_NAME --tags 'aws' | op get item - --fields title) )
    echo ${op_items[@]}

    for ((i = 0; i < ${#op_items[@]}; i++)); do
        word="${op_items[$i]}"
        echo "word: $word"
        export AWS_ACCESS_KEY_ID=`op get item "${word}" --fields ACCESS_KEY_ID`    
        export AWS_SECRET_ACCESS_KEY=`op get item "${word}" --fields ACCESS_KEY_SECRET`  
        export AWS_PROFILE_NAME=`op get item "${word}" --fields AWS_PROFILE_NAME`           
        aws-vault add "$AWS_PROFILE_NAME" --env
    done 
    IFS=${O_IFS}
    touch $AWS_STATE_FILE
fi

# install cli helpers
CLI_HELPER_STATE_FILE=$SCRIPT_DIR/newcompstate_cli_helpercomplete
if [[ -f "$CLI_HELPER_STATE_FILE" ]]; then
    echo "$CLI_HELPER_STATE_FILE exists."
else 
    # go helper repos
    # clone https://github.com/deptofdefense/awsutil
    # clone https://github.com/deptofdefense/awslogin
    echo '''
    clone https://github.com/deptofdefense/awsutil
    clone https://github.com/deptofdefense/awslogin
    and follow installation steps
    '''
    touch $CLI_HELPER_STATE_FILE
fi


# install garage
GARAGE_STATE_FILE=$SCRIPT_DIR/newcompstate_garagecomplete
if [[ -f "$GARAGE_STATE_FILE" ]]; then
    echo "$GARAGE_STATE_FILE exists."
else 
    cargo install garage
    cp $HOME/.cargo/bin/garage /usr/local/bin/garage
    touch $GARAGE_STATE_FILE
fi

# aws env
HOME_ENV_STATE_FILE=$SCRIPT_DIR/newcompstate_homeenvcomplete
if [[ -f "$HOME_ENV_STATE_FILE" ]]; then
    echo "$HOME_ENV_STATE_FILE exists."
else
    # read in home dir .env file on terminal start
    echo '''
    if [ -f .env ]
    then
        export $(cat .env | xargs)
    fi
    ''' | sed -e 's/^[[:space:]]*//' >> ~/.bashrc
    touch $HOME_ENV_STATE_FILE
fi

# make sure you have stree cli tools
# With the Source Tree app open go to:
# Installing the SourceTree Command Line Tools
# ![](imgs/stree-cli-setting.png)

# make sure to enable gpg signing by creating a
# new gpg key, adding it to github and configuring stree to use it
