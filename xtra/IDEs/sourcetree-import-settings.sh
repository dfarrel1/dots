#!/bin/bash
### hard overwrite of local with whatever is in remote repo

start_dir=$(pwd)
home_dir=$(echo ~)
app_supp_dir="${home_dir}/Library/Application Support"
stree_dir="${app_supp_dir}/SourceTree/"
stree_settings_repo="https://github.com/dfarrel1/sourcetree-settings.git"


[[ -d ${stree_dir} ]] && zip -r "${app_supp_dir}/SourceTree.$(date +%s).bkup.zip" "${stree_dir}" \
&& rm -rf "${stree_dir}" \
&& git clone $stree_settings_repo "${stree_dir}" \
&& rm -rf "${stree_dir}/.git"