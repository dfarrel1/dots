alias note='jupyter notebook'
alias python='/usr/local/bin/python3'
alias pip='/usr/local/bin/pip3'

pipup() {
  curl https://bootstrap.pypa.io/get-pip.py | python
}

venv() {
  cd ~/envs
  export choice_set=`ls -ad *$1*`
  back
  get_choice $@
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
