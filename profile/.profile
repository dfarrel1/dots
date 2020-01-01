[[ "$0" =~ "dotfiles/profile" ]] && PROFILE_DIR=$(dirname $0) || PROFILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export PATH="/usr/local/bin:${PATH}"
export GOPATH=~

sources=( core navigation git-completion docker python java latch scala mac git sls vim private )
for i in "${sources[@]}"
do
    source "$PROFILE_DIR/$i.sh" > /dev/null
done

#bash-completion
[[ -f "$(brew --prefix)/etc/bash_completion" ]] && source "$(brew --prefix)/etc/bash_completion"

#bash-git-prompt
[[ -f "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh" ]] && source "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh"

#history-completion+
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
bind -f ${HERE}/.inputrc
