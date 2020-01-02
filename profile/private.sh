# for me only
# this will refer to non public tools

repo_tools_dir="${GOPATH}/src/github.com/dfarrel1/repo-cross-talk"

# makes it easy to work on multiple machines on multiple repos
freshen() {
    repo_tools_env=`pew ls | tr ' ' '\n' | grep repo-cross-talk`
    [ -d ${repo_tools_dir} ] && pew in ${repo_tools_env} make -C ${repo_tools_dir} pull
}

help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi
