#!/usr/bin/env bash
# needs bash >= 4
alias src="source ~/.bashrc" # @desc Re-source bashrc
alias whatami='ps -p $$' # @desc Show current shell process
alias syslog='tail -f /var/log/system.log' # @desc Follow system log
alias ipecho='curl ipecho.net/plain ; echo' # @desc Show external IP address
alias myip="ipconfig getifaddr en1" # @desc Show local IP (en1)
alias whereami='pwd ; ipecho' # @desc Show pwd + external IP
alias speed='speedtest-cli' # @desc Run internet speed test
alias awake='caffeinate &' # @desc Prevent sleep (caffeinate)
alias decaf='killall caffeinate' # @desc Stop caffeinate


HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

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
alias fix_brew_perms='sudo chown -R $(whoami) $(brew --prefix)/*' # @desc Fix homebrew permissions
alias fix_all_perms='sudo chown -R "$USER":admin /usr/local && sudo chown -R "$USER":admin /Library/Caches/Homebrew' # @desc Fix homebrew + cache permissions

# @desc Update terminal working directory for VS Code compatibility
# @usage update_terminal_cwd
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



# @desc Export VS Code extensions list to install script
alias code-plugs="""
echo '#!/bin/bash' > ${HERE}/../xtra/IDEs/install-vscode-exts.sh \
&& code --list-extensions | xargs -L 1 echo code --install-extension >> \
${HERE}/../xtra/IDEs/install-vscode-exts.sh \
&& chmod +x ${HERE}/../xtra/IDEs/install-vscode-exts.sh
"""

# https://github.com/dvorka/hstr
# managed by homebrew now
# source ${HERE}/.hstrrc

# to include in docs
alias hstr='hstr' # @desc History search tool

# Json tools (pipe unformatted here to test + prettify JSON)
alias json='python -m json.tool' # @desc Pretty-print JSON via Python

help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi

