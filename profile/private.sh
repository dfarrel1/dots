# for me only
# this will refer to non public tools

repo_tools_dir="${GOPATH}/src/github.com/dfarrel1/repo-cross-talk"

# makes it easy to work on multiple machines on multiple repos
# uses pew: https://github.com/berdario/pew#usage
# new virtual env:
# (from $repo_tools_dir) 
# pew new -r requirements.txt repo-cross-talk-env

repo_prep() {
    repo_tools_env=`pew ls | tr ' ' '\n' | grep repo-cross-talk`
    echo $repo_tools_env | [ ! $(wc -w) == 1 ] \
        && echo "need one and only one env" \
        && echo -e "envs: \n${repo_tools_env}" \
        && return 1
    echo "cross-talk venv looks good."
    return 0
}

repo_act() {
    repo_prep \
    && [ -d ${repo_tools_dir} ] && pew in ${repo_tools_env} make -C ${repo_tools_dir} $1
}

pullall() {
    repo_act "pull"
}

pushall() {
    repo_act "push"
}

crossall() {
    repo_act "cross"
}

help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi
