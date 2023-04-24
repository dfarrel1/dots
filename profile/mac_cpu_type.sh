#!/bin/bash
# The script will return "arm64" for M1-based Macs, "x86_64" for Intel-based Macs, 
# and "None" for other systems or unknown CPU types.
os_type=$(uname)

if [ "$os_type" == "Darwin" ]; then
  cpu_type=$(uname -m)
  if [ "$cpu_type" == "arm64" ] || [ "$cpu_type" == "x86_64" ]; then
    echo "$cpu_type"
  else
    echo "None"
  fi
else
  echo "None"
fi
