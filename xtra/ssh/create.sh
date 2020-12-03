#!/bin/bash

KEY="id_rsa_<NAME_HERE>"
ssh-keygen -f ~/.ssh/${KEY}
chmod 600 ~/.ssh/${KEY}{,.pub}
ssh-add ~/.ssh/${KEY}
cat ~/.ssh/${KEY}.pub