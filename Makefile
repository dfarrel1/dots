### testers ###
csv_fname="./docs/c1.auto.csv"
csv2md:
	./doc_maker/csv2md.sh ${csv_fname}

refresh-csv:
	./doc_maker/sh2csv.sh

### general
install:
	pipenv install

docs:
	pipenv run ./doc_maker/flower.sh
	
everything: install docs

FILENAME="dotfiles-`date +%d-%m-%Y-%T`.tgz"
zip:
	tar -zcvf ${FILENAME} --exclude .git --exclude .pytest* --exclude *.egg-info .

.PHONY: docs
