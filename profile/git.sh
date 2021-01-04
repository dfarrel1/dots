#!/usr/bin/env bash
alias bro='browse'
alias forcepush='git push origin `git rev-parse --abbrev-ref HEAD` --force'
alias or='open_repo'
alias tt='newtab open_repo'
alias glog='git log --graph --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset" --abbrev-commit'
alias gg='git grep --line-number'
alias gs='git status'
alias amend='git commit --amend --no-edit && git push origin `git rev-parse --abbrev-ref HEAD` --force'
alias amendall='git add . && git commit --amend --no-edit && git push origin `git rev-parse --abbrev-ref HEAD` --force'
alias gitclean='git branch --merged | egrep -v "(^\*|master|dev)" | xargs git branch -d'

gadd() {
 git add . && git commit -m "$1" && git push
}

alias gclu='git_clean_untracked_safely'
alias gclb='git_clean_local_branches'

gslice() {
  # Usage: gslice <git-repo> <git-dir> <output-path>"
  mkdir $3 \
  && cd $3 \
  && git init \
  && echo -e "[core]\nsparseCheckout = true" > .git/config \
  && git remote add origin $1 \
  && echo $2 >> .git/info/sparse-checkout \
  && git pull origin master \
  && rm -rf .git \
  && ( mv $2/* $2/.* . || rmdir $2 )
}

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

GIT_PROMPT_ONLY_IN_REPO=1 # Use the default prompt when not in a git repo.
GIT_PROMPT_FETCH_REMOTE_STATUS=0 # Avoid fetching remote status
GIT_PROMPT_SHOW_UPSTREAM=0 # Don't display upstream tracking branch
GIT_SHOW_UNTRACKED_FILES=no # Don't count untracked files (no, normal, all)
GIT_PROMPT_THEME=Custom # looks for ~/.git-prompt-colors.sh
[[ ! -f ~/.git-prompt-colors.sh ]] && cp "${HERE}/.git-prompt-colors.sh" ~/.git-prompt-colors.sh


repo_info() {
  dir=`pwd`
  [[ $dir != *"$GOPATH/src/"* ]] && export git_local_path="." && return 1
  current_path=`echo ${dir#$GOPATH/src}`
  count=$(echo "${current_path}" | awk -F"/" '{print NF-1}')
  export git_path=""
  [ $count -ge 1 ] && export git_domain=$(echo $current_path | cut -d'/' -f2) && git_path=$git_domain || export git_domain=""
  [ $count -ge 2 ] && export git_org=$(echo $current_path | cut -d'/' -f3) && git_path="$git_path/$git_org" || export git_org=""
  [ $count -ge 3 ] && export git_repo=$(echo $current_path | cut -d'/' -f4) && git_path="$git_path/$git_repo" || export git_repo=""
  export git_tree=`echo ${dir#$GOPATH/src/$git_domain/$git_org/$git_repo/}`
  export git_local_path="$GOPATH/src/$git_path"
  [ $git_tree != $dir ] || export git_tree=""
  [ ! -z $git_repo ] && export git_branch=`git rev-parse --abbrev-ref HEAD`

  if [ "-s" != "$1" ] ;
  then
    echo "domain (git_domain):  $git_domain"
    echo "org (git_org):  $git_org"
    echo "repo (git_repo):  $git_repo"
    echo "tree (git_tree):  $git_tree"
    echo "branch (git_branch):  $git_branch"
  fi
}

clone() {
  repo=$1
  if [[ $repo != *"/"* ]] ; then
    repo_info -s || (echo "no repo found" && return 1)
    repo="git@$git_domain:$git_org/$repo.git"
  fi
  
  if [[ "$repo" == *"@"*":"* ]]; 
  # apply alias2host only on pattern git@<alias>:<username>/<repo>.git
  then
    alias=$(echo $repo | sed 's/.*@\(.*\):.*/\1/')    
    host=$(alias2host $alias)
    repo_real=$(echo $repo | sed 's/'"$alias"'/'"$host"'/g')
  else
    repo_real=$repo
  fi
      
  clone_dir=$(echo $repo_real | sed "s/.*:\//:\//g" | sed "s/git@/:\/\//g" | sed "s/:\/\///g" | sed "s/:/\//g" | sed "s/\.git//g")
  clone_dir="$GOPATH/src/$clone_dir"
  git clone $repo $clone_dir
  cd $clone_dir
}

origin() {
  git init
  repo_info -s || (echo "no repo found" && return 1)
  repo="git@$git_domain:$git_org/$git_repo.git"
  git remote add origin $repo
  if [ ! -z $1 ] && [ $1="push" ]
  then
    git add .
    git commit -m "Initial commit"
    git push -u origin master
  fi
}

open_repo() {
  repo_info -s
  cd "$GOPATH/src/$git_domain/$git_org/$1" 2>/dev/null
  if [ $? -ne 0 ]; then
    cd "$GOPATH/src/$git_domain/$git_org/"
    goto "$1"
  fi
}

alias2host() {
  # e.g. gitlab-rogue -> dev.rogue.diux.io
  ssh -G $1 | awk '$1 == "hostname" { print $2 }'
}

host2alias() {
  # TODO -- THIS IS WIP (still taking alias name)
  # NOTE: deprecated the aliases anyways
  # ~/.ssh/config is now using literal url paths
  # e.g. dev.rogue.diux.io -> gitlab-rogue
  match_str='debug1: /Users/.*/.ssh/config line 9: Applying options for'
  ssh -Gv $1 2>&1 >/dev/null | grep "${match_str}" | sed 's/.*for //'
}

browse() {
  repo_info -s || (echo "no repo found" && return 1)
  current_path="$(alias2host $git_domain)/$git_org/$git_repo"
  [ ! -z $git_tree ] && [ $git_tree != "" ] && current_path="$current_path/tree/$git_branch/$git_tree" && [ ! -z $1 ] && current_path="$current_path/$1"
  open -a "Google Chrome" "http://$current_path"
}

st() {
  repo_info -s || (echo "no repo found" && return 1)
  open -a "SourceTree 2" "$GOPATH/src/$git_path"
}

base() {
  repo_info -s || (echo "no repo found" && return 1)
  cd "$GOPATH/src/$git_path"
}

function git_clean_untracked_safely {
  TO_REMOVE=`git clean -f -d -n`;
  if [[ "$TO_REMOVE" != "" ]] && [[ `echo $TO_REMOVE | wc -l | bc` != "0" ]]; then
    echo "Cleaning...";
    printf "\n$TO_REMOVE\n\n";
    echo "Proceed?";

    select result in Yes No; do
      if [[ "$result" == "Yes" ]]; then
        echo "Cleaning in progress...";
        echo "";
        git clean -f -d;
        echo "";
        echo "All files and directories removed!";
      fi
      break;
    done;
  else
    echo "Everything is clean";
  fi;
}

function git_clean_local_branches {
  OPTION="-d";
  if [[ "$1" == "-f" ]]; then
    echo "WARNING! Removing with force";
    OPTION="-D";
  fi;

  TO_REMOVE=`git branch -r | grep -v "master" | grep -v ^* | awk "{print \$1}" | egrep -v -f /dev/fd/0 <(git branch -vv | grep origin | grep -v "master") | awk "{print \$1}"`;
  if [[ "$TO_REMOVE" != "" ]] && [[ `echo $TO_REMOVE | wc -l | bc` != "0" ]]; then
    echo "Removing branches...";
    echo "";
    printf "\n$TO_REMOVE\n\n";
    echo "Proceed?";

    select result in Yes No; do
      if [[ "$result" == "Yes" ]]; then
        echo "Removing in progress...";
        echo "$TO_REMOVE" | xargs git branch "$OPTION";
        if [[ "$?" -ne "0" ]]; then
          echo ""
          echo "Some branches was not removed, you have to do it manually!";
        else
          echo "All branches removed!";
        fi
      fi

      break;
    done;
  else
    echo "You have nothing to clean";
  fi
}


help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi
