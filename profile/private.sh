# for me only
# this will refer to non public tools

repo_tools_dir="${GOPATH}/src/github.com/dfarrel1/repo-cross-talk"


freshen() {
    repo_tools_env=`pew ls | tr ' ' '\n' | grep repo-cross-talk`
    "[ -d ${repo_tools_dir} ] && pew in ${repo_tools_env} make -C ${repo_tools_dir} pull"
}

# freshen needs to know where the pipenv virtual env is for repo-tools
alias fresh_env="pew workon `pew ls | tr ' ' '\n' | grep repo-cross-talk`"

