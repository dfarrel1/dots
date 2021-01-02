# entire .profile should take about 0.9 seconds to load (+ ASL on standard bash)
# see xtra/mac/faster-bash-notes if terminal load is more than a second
# TODO: port over to zsh.

[[ "$0" =~ "dotfiles/profile" ]] && PROFILE_DIR=$(dirname $0) || PROFILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export GOPATH=~
export BASH_SILENCE_DEPRECATION_WARNING=1

# for diagnostics 
timer=${SRC_TIMER:-false}

# these are for everyone
sources=( core navigation docker mac git vim )
for i in "${sources[@]}"
do
    if [ ${timer} = true ]
        then
            echo -e "\n \n$i"
            time (echo $i && source "$PROFILE_DIR/$i.sh" > /dev/null)
    fi
    echo $i && source "$PROFILE_DIR/$i.sh" > /dev/null
done

# history-completion+
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
bind -f ${HERE}/.inputrc

# NOTE: SLOWEST ITEM: bash_complete takes 0.5 secs to load
brew_sources=( 
    "/etc/bash_completion" \
    "/opt/bash-git-prompt/share/gitprompt.sh" \
    "/opt/asdf/asdf.sh" \
    "/opt/z/etc/profile.d/z.sh"
    )
for i in "${brew_sources[@]}"
do
    if [ ${timer} = true ]
        then
            echo -e "\n \n$i"
            time ([[ -f "$(brew --prefix)/$i" ]] && echo "found $i" && source "$(brew --prefix)/$i" )
    fi
    [[ -f "$(brew --prefix)/$i" ]] && echo "$i" && source "$(brew --prefix)/$i"    
done

# # rbenv - 0.1 secs
# # not using
# if [ ${timer} = true ]
#     then
#         echo -e "\n\nrbenv for ruby"
#         time eval "$(rbenv init -)"
# fi
# eval "$(rbenv init -)"
# echo "rbenv"
echo "Done: .profile loaded."

# NOTES
# bash-completion
# TODO: maybe remove this since asdf installed a bash completion
# Bash completion has been installed to:
#  /usr/local/etc/bash_completion.d
#asdf
# TODO: this might need more love: https://dev.to/0xdonut/manage-your-runtime-environments-using-asdf-and-not-nvm-or-rvm-etc-2c7c
# according to official instructions though, this is all we need ( https://asdf-vm.com/#/core-manage-asdf-vm )
# . $(brew --prefix asdf)/asdf.sh
