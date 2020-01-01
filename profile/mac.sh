alias src="source ~/.bashrc > /dev/null"
alias snowsql='/Applications/SnowSQL.app/Contents/MacOS/snowsql'
alias whatami='ps -p $$'
alias syslog='tail -f /var/log/system.log'
alias ipecho='curl ipecho.net/plain ; echo'
alias whereami='pwd ; ipecho'
alias speed='speedtest-cli'
alias awake='caffeinate &'
alias decaf='killall caffeinate'

#bash-completion
[[ -f "$(brew --prefix)/etc/bash_completion" ]] && source "$(brew --prefix)/etc/bash_completion"

#bash-git-prompt
[[ -f "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh" ]] && source "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh"

#history-completion+
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
bind -f ${HERE}/.inputrc

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

# PS1="(/•-•)/ >"
# PS1="\W 🐙$ " 
# PS1='\[\e[1;33m\][ \W ]\[\e[0m\] $ '
PS1='\[\e[1;33m\][ \W ]\[\e[0m\] 🐣  $ '

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
