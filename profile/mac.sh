alias src="source ~/.bashrc"
#bash-completion
[[ -f "$(brew --prefix)/etc/bash_completion" ]] && source "$(brew --prefix)/etc/bash_completion"

#bash-git-prompt
[[ -f "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh" ]] && source "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh"

#history-completion+
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
bind -f ${HERE}/.inputrc

GIT_PROMPT_ONLY_IN_REPO=1 # Use the default prompt when not in a git repo.
GIT_PROMPT_FETCH_REMOTE_STATUS=0 # Avoid fetching remote status
GIT_PROMPT_SHOW_UPSTREAM=0 # Don't display upstream tracking branch
GIT_SHOW_UNTRACKED_FILES=no # Don't count untracked files (no, normal, all)
# GIT_PROMPT_THEME=Custom
# looks for ~/.git-prompt-colors.sh

# work out colors later [http://tldp.org/HOWTO/Bash-Prompt-HOWTO/x860.html]

# PS1="(/•-•)/ >"
# PS1="\W 🐙 " 
PS1='\[\e[1;33m\][ \W ]\[\e[0m\] $ '

#update vscode plugins list
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
alias code-plugs='ls ~/.vscode/extensions > ${DIR}/../xtras/vscode-exts && cat ${DIR}/../xtras/vscode-exts'
