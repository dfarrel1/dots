#!/bin/bash
### hard overwrite of whatever is in remote repo

start_dir=$(pwd)
stree_dir="${start_dir}/sourcetree-settings/"

[[ ! -d ${stree_dir} ]] && mkdir $stree_dir \
&& cp -r ~/Library/Application\ Support/SourceTree/ ./sourcetree-settings/ \
&& cd $stree_dir \
&& git init \
&& git add . \
&& git commit -m "add all" \
&& git remote add origin https://github.com/dfarrel1/sourcetree-settings.git \
&& git push -u origin master -f \
&& rm -rf $stree_dir \
&& cd $start_dir