### overview

This is a non-dependency documentation tool. It takes shell scripts and outputs `.md` summary tables.

**csv2md** (dir)

src from ***[csv2md](https://github.com/lzakharov/csv2md)*** used with:
```
pip install csv2md
```

**sh2csv.sh**

Takes a profile `*.sh` file, gets all aliases and functions and writes them to a csv file. 
 
This outputs with the extension `<originating-file.auto.csv>`, where `auto` is intended to denote that it was not modified by hand.

In order to identify functions, it is necessary that `.sh` files contain the following help method for exposing them:

```
help() {
  typeset -f | awk '!/^main|help[ (]/ && /^[^ {}]+ *\(\)/ { gsub(/[()]/, "", $1); print $1}'
}

if [ "_$1" = "_" ]; then
    help
else
    "$@"
fi
```

**csv2md.sh**

Takes a csv file and generates a `*.md` file (csv -> MarkDown table).  
This outputs with the extension `<originating-file.auto.md>`, where `auto` denotes that it was not modified by hand.

This is dependent on the `csv2md` python module.

**flower.sh**

Does everything across all files.

**notes**

The idea is that the `*.auto.*` files are intermediates for manually editing the documentation. There doesn't appear to be any way to fully automate it.

This is admittedly a clunky process. I wouldn't want to be doing this often, but it's convenient for building everything up from scratch the first time.
