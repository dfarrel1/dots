#!/usr/bin/env bash
# UPDATE: (homebrew) In #9117, we switched to a new prefix of /opt/homebrew for installations on Apple Silicon. 
# Applications
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
MAC_TYPE=$(${HERE}/mac_cpu_type.sh)

if [ ${MAC_TYPE} = "x86_64" ]
then
    echo -e "found an: intel mac."
elif [ ${MAC_TYPE} = "arm64" ]
then
    echo -e "found an: m1 mac."
    export GOROOT="$(brew --prefix golang)/libexec"    
    # if using a mac arm M1 then export GOROOT="$(brew --prefix golang)/libexec"
    # otherwise export GOROOT=/usr/local/opt/go/libexec    
    export PATH=$PATH:$GOPATH/bin
    export PATH=$PATH:$GOROOT/bin
else
    echo -e "found an: unknown type mac."
fi
   
# instructions to install cli for code: https://code.visualstudio.com/docs/setup/mac
alias code='/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code'
alias open_with_code='open -a "Visual Studio Code"'
alias c.='repo_info -s;open_with_code $git_local_path'
alias a.='repo_info -s;atom $git_local_path'
# Intel Mac: after ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" /usr/local/bin/sublime
# M1 Mac: after ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" /opt/homebrew/bin/sublime
alias s.='repo_info -s;sublime $git_local_path'
alias idea='open -a "`ls -dt /Applications/IntelliJ\ IDEA*|head -1`"'
alias i.='repo_info -s;idea $git_local_path'
# 'intellij' cli comes with the paid version of intellij
# alias i.='repo_info -s;intellij $git_local_path'
alias o.='open .'
alias chrome='open -a "Google Chrome"'
alias pn.='chrome http://127.0.0.1:8192/ && /Applications/polynote/polynote'
# stree alias comes from SourceTree, need to activate command line tools
alias chfox='open -a Charles;open -a Firefox'
alias excel='open -a "Microsoft Excel"'
alias snowsql='/Applications/SnowSQL.app/Contents/MacOS/snowsql'
alias ports='lsof -i | grep -E "(LISTEN|ESTABLISHED)"'
alias epc='open_with_code $PROFILE_DIR' # [E]dit [P]rofile (with) [C]ode
alias epa='atom $PROFILE_DIR'
alias ep='epc'
# alias stree='open -a "SourceTree 2"'
# getting stree from built in cli 
# /usr/local/bin/stree
