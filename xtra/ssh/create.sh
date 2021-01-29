#!/bin/bash

usage()
{
    echo "usage: ./create.sh -o <output>"
}

if [ $# == 0 ]; then
    usage
    exit 1
fi

while getopts o: flag
do
    case "${flag}" in
        o | --output ) KEY=${OPTARG};; 
        * ) usage
            exit 1       
    esac
done

ssh-keygen -f ~/.ssh/${KEY}
chmod 600 ~/.ssh/${KEY}{,.pub}
ssh-add ~/.ssh/${KEY}
cat ~/.ssh/${KEY}.pub
