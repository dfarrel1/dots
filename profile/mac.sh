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
export AWS_VAULT_KEYCHAIN_NAME=login
export AWS_SDK_LOAD_CONFIG=1
export CHAMBER_KMS_KEY_ALIAS='alias/aws/ssm'
export CHAMBER_USE_PATHS=1


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
source ${HERE}/.hstrrc

# to include in docs
alias hstr='hstr'

# Json tools (pipe unformatted here to test + prettify JSON)
alias json='python -m json.tool'

1pass() {
    eval $(op signin dds)
}

# this is redundant w/ aws-vault; will prob deprecate
awskeys() {    
    VAULT_NAME="dene"
    ITEM_NAME="rogue-ci AWS key"
    export AWS_REGION=us-gov-east-1
    # Prereqs:
    # 1) jq installed https://stedolan.github.io/jq/
    # 2) 1Password client installed https://support.1password.com/command-line/
    # 3) Signed in once before with op signin https://support.1password.com/command-line/#sign-in-or-out
    if [ ! $OP_SESSION_dds ]; then
        eval $(op signin dds);
    else
        # This is a void command to test whether your session is still valid,
        op list users > /dev/null 2>&1 
        test $? -eq 0 || eval $(op signin dds);
    fi;

    ITEM=`op get item "$ITEM_NAME" --vault=$VAULT_NAME`
    export AWS_ACCESS_KEY_ID=`echo $ITEM | jq -Mcr '.details.fields[] | select(.name=="username") | .value'`
    export AWS_SECRET_ACCESS_KEY=`echo $ITEM | jq -Mcr '.details.fields[] | select(.name=="password") | .value'`
}

mfa() {
    provider=${1-aws}
    onepass_alias="dds"
    if [ ! $OP_SESSION_${onepass_alias} ]; then
        eval $(op signin $onepass_alias);
    else
        # This is a void command to test whether your session is still valid,
        op list users > /dev/null 2>&1 
        test $? -eq 0 || eval $(op signin $onepass_alias);
    fi;    
    allowed_providers=("aws github")
    ARRAY=( "aws:AWS rogue-ci Login"
            "github:DDS Github" )
    if [[ ! " ${allowed_providers[@]} " =~ " ${provider} " ]]; then
        echo "provider ${provider} not recognized. exiting mfa." 
        return 1
    fi
    unset secret_name
    for pairing in "${ARRAY[@]}" ; do
        KEY="${pairing%%:*}"
        VALUE="${pairing##*:}"
        if [ $KEY = $provider ]; then
            secret_name=$VALUE
        fi
    done     
    echo "{provider: ${provider}, secret: \"${secret_name}\"} " && \
    op get totp "${secret_name}" | tr -d '\n' | pbcopy && echo "Copied to clipboard."
}

console() {
    aws-vault login labyrinth-developers --mfa-token $(awsmfa)
}

help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi
