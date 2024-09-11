#!/usr/bin/env bash
# UPDATE: (homebrew) In #9117, we switched to a new prefix of /opt/homebrew for installations on Apple Silicon. 
HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CPU_TYPE=$(${HERE}/mac_cpu_type.sh)
case "$CPU_TYPE" in
    x86_64)
      BIN_PATH="$(brew --prefix)/bin"
      ;;
    arm64)
      BIN_PATH="$(brew --prefix)/bin"
      ;;
    *)
      BIN_PATH="/usr/local/bin"
      ;;
esac

# export PATH="/usr/local/opt/python@3.8/bin:$PATH"
alias note='jupyter notebook'
# WARNING: Make sure this path agrees with python install from `brew info python`
echo "BIN_PATH: $BIN_PATH"
# TODO generalize away from 3.9
# NOTE: had to force specification to python3.9 for kanga stuff
# TODO come back to this if it's needed
alias python="${BIN_PATH}/python3"
# alias python3="${BIN_PATH}/python3.9"
# alias pip="${BIN_PATH}/pip3.9"
# alias pip3="${BIN_PATH}/pip3.9"
# alias vpython='$VIRTUAL_ENV/bin/python'
# alias vpip='$VIRTUAL_ENV/bin/pip'
# alias vpip3='$VIRTUAL_ENV/bin/pip3'
# alias ansible='/Users/denefarrell/Library/Python/3.9/bin/ansible'

export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# For pyenv on mac OS 11
# export LDFLAGS="-L/usr/local/opt/zlib/lib -L/usr/local/opt/bzip2/lib"
# export CPPFLAGS="-I/usr/local/opt/zlib/include -I/usr/local/opt/bzip2/include"

# # conda from "brew install --cask anaconda"
# export PATH="/usr/local/anaconda3/bin:$PATH"
# # >>> conda initialize >>>
# # !! Contents within this block are managed by 'conda init' !!
# __conda_setup="$('/usr/local/anaconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
# if [ $? -eq 0 ]; then
#     eval "$__conda_setup"
# else
#     if [ -f "/usr/local/anaconda3/etc/profile.d/conda.sh" ]; then
#         . "/usr/local/anaconda3/etc/profile.d/conda.sh"
#     else
#         export PATH="/usr/local/anaconda3/bin:$PATH"
#     fi
# fi
# unset __conda_setup
# # <<< conda initialize <<<

pipup() {
  curl https://bootstrap.pypa.io/get-pip.py | python
}

venv() {
  cd ~/envs
  export choice_set=`ls -ad *$1*`
  back
  get_choice "$@"
  [ "$choice_set" != "" ] && ([[ "$VIRTUAL_ENV" != *"/"* ]] || deactivate) && source "$HOME/envs/$choice_set/bin/activate"
}

new_venv() {
  local name="${@: -1}"
  local params=$@
  [ -z $1 ] && echo "please provide virtual env name" && read name
  [ -z $name ] && name=$(basename "$PWD")
  params="${params[@]:1}"
  virtualenv$params "$HOME/envs/$name"
  cp "$HOME/envs/default/pip.conf" "$HOME/envs/$name/pip.conf"
  xx $HOME/envs/$name/bin/*
  xx $HOME/envs/$name/*
  venv "$name"
}

# WIP
python_server='''
import http.server
import socketserver
PORT = 8000
Handler = http.server.SimpleHTTPRequestHandler
with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print("serving at port", PORT)
    httpd.serve_forever()
'''
# Start an HTTP server from a directory, optionally specifying the port
function server() {
	local port="${1:-8000}";
	sleep 1 && open "http://localhost:${port}/" &
	python -m http.server ${port}
}

help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi
