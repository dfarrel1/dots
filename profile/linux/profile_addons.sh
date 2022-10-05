# add to ~/.bashrc

export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

if [ -f "$HOME/.bash-git-prompt/gitprompt.sh" ]; then
    GIT_PROMPT_ONLY_IN_REPO=1
    source $HOME/.bash-git-prompt/gitprompt.sh
fi

. /home/dds/src/orphans/linux-dots/deps/z.sh

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

source /home/dds/src/github.com/dfarrel1/dots/profile/.profile