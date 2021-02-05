#!/usr/bin/env bash
# export PATH="/usr/local/opt/python@3.8/bin:$PATH"
alias note='jupyter notebook'
# WARNING: Make sure this path agrees with python install from `brew info python`
alias python='/usr/local/bin/python3'
alias pip='/usr/local/bin/pip3'
# alias ansible='/Users/denefarrell/Library/Python/3.9/bin/ansible'

eval "$(pyenv init -)"
# For pyenv on mac OS 11
export LDFLAGS="-L/usr/local/opt/zlib/lib -L/usr/local/opt/bzip2/lib"
export CPPFLAGS="-I/usr/local/opt/zlib/include -I/usr/local/opt/bzip2/include"

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
