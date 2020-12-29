#!/bin/bash
# [ https://polynote.org/docs/01-installation.html ]
# [ https://github.com/polynote/polynote ]

# UPDATE: there is a homebrew formula now
# brew install polynote

# ANOTHER UPDATE: homebrew formula cd's into /usr/local/Cellar/polynote/0.3.12/libexec
# recapitulates a notebook permissions issue, going to just use docker -- fuck this.

poly_base="https://github.com/polynote/polynote/releases/download"
poly_version="0.3.12"
poly_dist="polynote-dist-2.12"
poly_dir=~/src/polynote
cd $poly_dir || ( mkdir -p $poly_dir && cd $poly_dir ) 
wget "$poly_base/$poly_version/$poly_dist.tar.gz"
tar -xf ${poly_dist}.tar.gz -C "${poly_dir}/.." && rm ${poly_dist}.tar.gz
cd $poly_dir

# install requirements
brew install apache-spark

### ISSUES ###
# python interpreter error when running polynote server:
# /usr/local/lib/python3.9/site-packages/jep/jep.cpython-39-darwin.so:
# dlopen(/usr/local/lib/python3.9/site-packages/jep/jep.cpython-39-darwin.so,
# 1): no suitable image found. Did find:
# /usr/local/lib/python3.9/site-packages/jep/jep.cpython-39-darwin.so: code
# signature in
# (/usr/local/lib/python3.9/site-packages/jep/jep.cpython-39-darwin.so) not
# valid for use in process using Library Validation: mapped file has no cdhash,
# completely unsigned? Code has to be at least ad-hoc signed.
###
# Looks like polynote needs anaconda (?)
brew install --cask anaconda
# remember to:
echo '''
export PATH="/usr/local/anaconda3/bin:$PATH"
''' >> ~/.bashrc && source ~/.bashrc

# then you have to use conda for env managmenet
# and maybe polynote (jep) need PYTHONHOME too

# not sure -- I failed to get polynote working w/o conda
# OS 11.0.1
# python3 -- Python 3.9.1
# pip3 show jep:
# Name: jep
# Version: 3.9.0
# Summary: Jep embeds CPython in Java
# Home-page: https://github.com/ninia/jep
# Author: Jep Developers
# Author-email: jep-project@googlegroups.com
# License: zlib/libpng
# Location: /usr/local/lib/python3.9/site-packages
# Requires: 
# Required-by: 

pip3 install -r ./requirements.txt
# run the server
# DEBUG ISSUE -- create a folder under $poly_dir/notebooks
mkdir "${poly_dir}/notebooks"
chrome http://localhost:8192
./polynote.py

