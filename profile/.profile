[[ "$0" =~ "dotfiles/profile" ]] && PROFILE_DIR=$(dirname $0) || PROFILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export PATH="/usr/local/bin:${PATH}"
export GOPATH=~

# these are for everyone
sources=( core navigation git-completion docker python java latch scala mac git sls vim z )
for i in "${sources[@]}"
do
    source "$PROFILE_DIR/$i.sh" > /dev/null
done

# some stuff that's just for me. 
# go ahead and personalize your own
# you will need to fork your own repo at this point if you want
# to use this aspect of the dot files
if [ "$NONPUBLIC_DOTS_BOOL" = true ] ; then
    private_sources=( "${GOPATH}/src/github.com/dfarrel1/dots-private/" )    
    for private_dir in "${private_sources[@]}"    
        do
            for i in "${private_dir}"/*.sh
                do
                    source "$i"
                done
        done
fi

# More third-party stuff

# bash-completion
[[ -f "$(brew --prefix)/etc/bash_completion" ]] && source "$(brew --prefix)/etc/bash_completion"

# bash-git-prompt
[[ -f "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh" ]] && source "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh"

# history-completion+
bind -f ${HERE}/.inputrc

#rbenv for ruby
eval "$(rbenv init -)"
