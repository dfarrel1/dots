#!/usr/bin/env bash

# entire .profile should take about 0.9 seconds to load (+ ASL on standard bash)
# see xtra/mac/faster-bash-notes if terminal load is more than a second
# TODO: port over to zsh.

[[ "$0" =~ "dotfiles/profile" ]] && PROFILE_DIR=$(dirname $0) || PROFILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export GOPATH=~
# moved GOROOT definition to apps_<type>

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
mkdir -p "$HOME/.runtime"
export XDG_RUNTIME_DIR="$HOME/.runtime"

export BASH_SILENCE_DEPRECATION_WARNING=1

# local bin
export PATH=$PATH:/Users/dene/.local/bin

# "just" makefile reader
export PATH=$PATH:/Users/dene/.cargo/bin

# Setup environment for Rust toolchain
source $HOME/.cargo/env

# TeX tools for mactex
export PATH=$PATH:/Library/TeX/texbin/

# for diagnostics 
timer=${SRC_TIMER:-false}

# for verbosity
verbosity=${SRC_VERBOSE:-false}
echo "SRC_VERBOSE: $verbosity"

# these are for everyone
sources=( core navigation docker git vim python aws misc fun )

# these are for just me
if [ -d "$PROFILE_DIR/private" ]; then
    # Find all .sh files in the private directory
    shopt -s nullglob
    private_files=("$PROFILE_DIR/private/"*.sh)
    shopt -u nullglob
    
    if [ ${#private_files[@]} -eq 0 ]; then
        echo "No private profile files found, skipping"
    else
        echo "adding private profile files"
        for file in "${private_files[@]}"; do
            filename=$(basename "$file" .sh)
            sources+=( "private/$filename" )            
        done
    fi
else
    echo "No private directory found, skipping"
fi

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    CYGWIN*)    machine=Cygwin;;
    MINGW*)     machine=MinGw;;
    *)          machine="UNKNOWN:${unameOut}"
esac
echo "found a ${machine}"
if [ ${machine} = "Linux" ]
then
    sources+=("apps_linux")
fi
if [ ${machine} = "Mac" ]
then
    sources+=("apps_mac")
fi
for i in "${sources[@]}"
do
    if [ "${timer}" = true ]; then
        echo -e "\n \nTiming $i"
        time source "$PROFILE_DIR/$i.sh" > /dev/null
    elif [ "${verbosity}" = "$i" ]; then
        echo "Sourcing $i with verbosity"
        source "$PROFILE_DIR/$i.sh"
    else
        echo "Sourcing $i without verbosity"
        source "$PROFILE_DIR/$i.sh" > /dev/null
    fi
done

# history-completion+
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
bind -f ${HERE}/.inputrc

# NOTE: SLOWEST ITEM: bash_complete takes 0.5 secs to load
brew_sources=( 
    "/etc/profile.d/bash_completion.sh" \
    "/opt/bash-git-prompt/share/gitprompt.sh" \
    "/opt/asdf/asdf.sh" \
    "/opt/z/etc/profile.d/z.sh"
    )
echo "loading brew sources"

eval $(brew --prefix)/bin/brew shellenv

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

# fix copy-paste behavior
printf '\e[?2004l'

echo "Done: .profile loaded."
echo "Welcome, $(whoami)!"
echo "Uptime: $(uptime | awk -F 'up ' '{print $2}' | cut -d, -f1-2)"


# clear
splasher


#asdf
# TODO: this might need more love: https://dev.to/0xdonut/manage-your-runtime-environments-using-asdf-and-not-nvm-or-rvm-etc-2c7c
# according to official instructions though, this is all we need ( https://asdf-vm.com/#/core-manage-asdf-vm )
# . $(brew --prefix asdf)/asdf.sh
