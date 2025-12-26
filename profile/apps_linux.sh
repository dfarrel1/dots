#!/usr/bin/env bash
# Applications
# instructions to install cli for code: https://code.visualstudio.com/docs/setup/mac


# if using a mac arm M1 then export GOROOT="$(brew --prefix golang)/libexec"
# otherwise export GOROOT=/usr/local/opt/go/libexec
export GOROOT=/usr/local/opt/go/libexec
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:$GOROOT/bin

alias c.='repo_info -s;code $git_local_path'
alias a.='repo_info -s;atom $git_local_path'
# after ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" /usr/local/bin/sublime
alias s.='repo_info -s;sublime $git_local_path'
alias idea='open -a "`ls -dt /Applications/IntelliJ\ IDEA*|head -1`"'
alias i.='repo_info -s;idea $git_local_path'
# 'intellij' cli comes with the paid version of intellij
# alias i.='repo_info -s;intellij $git_local_path'
alias o.='nautilus .'
alias chrome='google-chrome'
alias pn.='chrome http://127.0.0.1:8192/ && /Applications/polynote/polynote'
# stree alias comes from SourceTree, need to activate command line tools
alias chfox='open -a Charles;open -a Firefox'
alias excel='open -a "Microsoft Excel"'
alias snowsql='/Applications/SnowSQL.app/Contents/MacOS/snowsql'
alias ports='lsof -i | grep -E "(LISTEN|ESTABLISHED)"'
alias epc='open_with_code $PROFILE_DIR' # [E]dit [P]rofile (with) [C]ode
alias epa='atom $PROFILE_DIR'
alias ep='epc'
alias stree='~/src/smartgit/bin/smartgit.sh &'