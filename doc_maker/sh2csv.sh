#!/usr/bin/env bash

BASEDIR=$(dirname "$0")
PARSEE=${1:-${BASEDIR}/../profile/c1.sh}  
SHORT=$(basename -- ${PARSEE})
SHORT="${SHORT%.*}" 
OUTPUT=${2:-${BASEDIR}/../docs/${SHORT}.auto.csv}
IFS_BAK=${IFS}
IFS="
"

### output schema ###
# 1. identifying name 
# 2. type name (alias or function)
# 3. description of functionality
# 4. originating file
# 5. note (placeholder)
schema="name, type, desc, file, note"

############# aliases ##################
export aliases=($(grep "^[^#]*alias"  ${PARSEE} | awk '{print $2}' | awk -F'=' '{print $1}'))
export targets=($(grep "^[^#]*alias"  ${PARSEE} | sed 's:.*=::' | awk 'length > 40{$0 = substr($0, 1, 40) "..."} {printf "%-43s\n", $0}' | sed 's/,/;/g' | sed "s/'/\'/g" | sed 's/"/\"/g' | sed 's/|/\&#124;/g' ))
echo ${targets[@]}
unset aliases_zip
for i in "${!aliases[@]}";
do 
    aliases_zip+=( "${aliases[i]}, alias, ${targets[i]}, $(basename -- ${PARSEE}), <-> "); 
done

echo ${schema} > ${OUTPUT}; 
for a in "${aliases_zip[@]}"; do echo $a >> ${OUTPUT}; done;

############# functions #####################
# this requires the script tells us it's functions
funs=($(${PARSEE} help))
unset funs_zip
for i in "${!funs[@]}";
do 
    funs_zip+=( "${funs[i]}, function, <what does ${funs[i]} do ?>, $(basename -- ${PARSEE}), <->"); 
done

for f in "${funs_zip[@]}"; do echo $f >> ${OUTPUT}; done;

IFS=${IFS_BAK}
echo 'wrote to $OUTPUT: '${OUTPUT}
