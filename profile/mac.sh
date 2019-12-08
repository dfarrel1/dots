alias src="source ~/.bashrc > /dev/null"
alias snowsql='/Applications/SnowSQL.app/Contents/MacOS/snowsql'
alias whatami='ps -p $$'

#bash-completion
[[ -f "$(brew --prefix)/etc/bash_completion" ]] && source "$(brew --prefix)/etc/bash_completion"

#bash-git-prompt
[[ -f "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh" ]] && source "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh"

#history-completion+
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
bind -f ${HERE}/.inputrc

# work out colors later [http://tldp.org/HOWTO/Bash-Prompt-HOWTO/x860.html]

# PS1="(/•-•)/ >"
# PS1="\W 🐙 " 
PS1='\[\e[1;33m\][ \W ]\[\e[0m\] $ '

#update vscode plugins list
alias code-plugs="""
code --list-extensions | xargs -L 1 echo code --install-extension > \
${HERE}/../xtra/install-vscode-exts.sh \
&& chmod +x ${HERE}/../xtra/install-vscode-exts.sh
"""
