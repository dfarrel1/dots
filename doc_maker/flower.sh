#!/usr/bin/env bash

BASEDIR=$(dirname "$0")
DOTDIR="${BASEDIR}/../profile/"
DOTFILES=($(ls ${DOTDIR}*.sh | xargs -n 1 basename))
echo ${DOTFILES}

### make csvs
for f in ${DOTFILES[@]}; do "${BASEDIR}/sh2csv.sh" "${DOTDIR}${f}"; done;
echo "csv files done."

### make md tables
DOCSDIR="${BASEDIR}/../docs/"
for f in ${DOTFILES[@]}; do "${BASEDIR}/csv2md.sh" "${DOCSDIR}${f%.*}.auto.csv"; done;
echo "md tables done."

### combine tables
ALLTABLESFILE=${DOCSDIR}"ALLTABLES.md"; > ${ALLTABLESFILE};
for f in ${DOTFILES[@]}
do
    echo -e "\n" >> ${ALLTABLESFILE}
    echo "**${f%.*}**" >> ${ALLTABLESFILE}
    echo -e "\n\n" >> ${ALLTABLESFILE}
    cat "${DOCSDIR}${f%.*}.auto.md" >> ${ALLTABLESFILE}
done

echo "finished writing to combined tables file."
