#!/bin/bash

# reminders:
# 1. set vscode settings: dots/IDES/vscode-settings.md
# 2. set cursor speed to max in terminal, keyboard settings
# 3. for any ssh keys not managed in 1pass: ssh-add ~/.ssh/*


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
# upgraded to OP CLI to Version 2
# There were breaking changes going from Version 1 to Version 2
# CLI Version 1 must be manually downloaded from here:
# https://app-updates.agilebits.com/product_history/CLI
OP_STATE_FILE=$SCRIPT_DIR/newcompstate_opcomplete
if [[ -f "$OP_STATE_FILE" ]]; then
    echo "$OP_STATE_FILE exists."
else
    echo "signing in to 1pass for the first time (step requires \"op\" aka 1pass CLI tool to be installed)"
    # if op.env exists, source it
    if [ -f "$SCRIPT_DIR/op.env" ]; then
        source $SCRIPT_DIR/op.env
    fi
    OP_SITE="${OP_ACCOUNT_NAME:-missing-op-site}"
    # first signing will require the user to enter their email and secret key
    op signin --account ${OP_SITE} &&\
    touch $OP_STATE_FILE
fi


#ssh stuff
SSH_STATE_FILE="${SCRIPT_DIR}/newcompstate_sshcomplete"
if [[ -f "$SSH_STATE_FILE" ]]; then
    echo "$SSH_STATE_FILE exists."
else
    if [ -f "$SCRIPT_DIR/op.env" ]; then
        source $SCRIPT_DIR/op.env
    fi
    echo "adding ssh keys from 1pass to machine files"

    OP_SITE="${OP_ACCOUNT_NAME:-missing-op-site}"
    op signin --account ${OP_SITE}

    # NOTE: this is a personalized vault name in 1pass
    VAULT_NAME="${OP_SSH_VAULT_NAME:-work-ssh}"  
    echo $(op item list --vault $VAULT_NAME --format 'json')  
    op_items=$(op document list --vault $VAULT_NAME --format 'json' | jq -Mcr '.[].title' | sort)
    echo "op_items: $op_items"
    for word in $op_items; do
        echo $word              
        op document get --vault $VAULT_NAME "$word" --out-file ~/.ssh/${word}
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
    # echo "adding all \'newfile\' tagged files to the home dir"
    if [ -f "$SCRIPT_DIR/op.env" ]; then
        source $SCRIPT_DIR/op.env
    fi
    OP_SITE="${OP_ACCOUNT_NAME:-missing-op-site}"        
    VAULT_NAME=${OP_AWS_VAULT_NAME:-"work-aws"}    
    echo "adding all documents in the vault ${VAULT_NAME} to the home dir"
    op_items=$(op document list --vault $VAULT_NAME --format 'json' | jq -Mcr '.[].title' | sort)
    for word in $op_items; do
        echo $word              
        op document get --vault $VAULT_NAME "$word" --out-file ~/${word}        
    done

    O_IFS=$IFS    
    IFS=$'\n'    
    op_items=( $(op item list --vault $VAULT_NAME --tags 'aws' | op item get - --fields title) )
    echo ${op_items[@]}

    for ((i = 0; i < ${#op_items[@]}; i++)); do
        word="${op_items[$i]}"
        echo "word: $word"
        export AWS_ACCESS_KEY_ID=`op item get "${word}" --fields ACCESS_KEY_ID`    
        export AWS_SECRET_ACCESS_KEY=`op item get "${word}" --fields ACCESS_KEY_SECRET`  
        export AWS_PROFILE_NAME=`op item get "${word}" --fields AWS_PROFILE_NAME`           
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

# install rustup
RUSTUP_STATE_FILE=$SCRIPT_DIR/newcompstate_rustupomplete
if [[ -f "$RUSTUP_STATE_FILE" ]]; then
    echo "$RUSTUP_STATE_FILE exists."
else 
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    touch $RUSTUP_STATE_FILE
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


# hotspot tether script
TETHER_STATE_FILE=$SCRIPT_DIR/newcompstate_tethercomplete
if [[ -f "$TETHER_STATE_FILE" ]]; then
    echo "$TETHER_STATE_FILE exists."
else
    ${SCRIPT_DIR}/tether/update-crontab.sh
    touch $TETHER_STATE_FILE
fi

# make sure you have stree cli tools
# With the Source Tree app open go to:
# Installing the SourceTree Command Line Tools
# ![](imgs/stree-cli-setting.png)

# make sure to enable gpg signing by creating a
# new gpg key, adding it to github and configuring stree to use it
