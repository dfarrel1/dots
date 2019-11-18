#!/usr/bin/env bash

BASEDIR=$(dirname "$0")
PARSEE=${1:-${BASEDIR}/../docs/c1.auto.csv}  
SHORT=$(basename -- ${PARSEE})
SHORT="${SHORT%.*}" 
SHORT="${SHORT%.*}"
OUTPUT=${2:-${BASEDIR}/../docs/${SHORT}.auto.md}

### ref: [https://github.com/lzakharov/csv2md]
### pip install csv2md

csv2md ${PARSEE} > ${OUTPUT}

### alternatively
# python ${BASEDIR}/csv2md/csv2md.py ${PARSEE} > ${OUTPUT}
