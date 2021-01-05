#!/usr/bin/env bash
# Applications
# instructions to install cli for code: https://code.visualstudio.com/docs/setup/mac
alias code='/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code'
alias open_with_code='open -a "Visual Studio Code"'
alias c.='repo_info -s;open_with_code $git_local_path'
alias a.='repo_info -s;atom $git_local_path'
# after ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" /usr/local/bin/sublime
alias s.='repo_info -s;sublime $git_local_path'
alias i.='repo_info -s;intellij $git_local_path'
alias o.='open .'
alias chrome='open -a "Google Chrome"'
alias pn.='chrome http://127.0.0.1:8192/ && /Applications/polynote/polynote'
# stree alias comes from SourceTree, need to activate command line tools
alias chfox='open -a Charles;open -a Firefox'
alias excel='open -a "Microsoft Excel"'

alias ports='lsof -i | grep -E "(LISTEN|ESTABLISHED)"'
alias epc='open_with_code $PROFILE_DIR' # [E]dit [P]rofile (with) [C]ode
alias epa='atom $PROFILE_DIR'
alias ep='epc'
