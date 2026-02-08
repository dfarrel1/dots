| Name | Type | Description |
|------|------|-------------|
| `cd` | alias | pushd wrapper that saves directory history |
| `back` | alias | `'popd >> /dev/null'` |
| `ld` | alias | List directory stack with indices |
| `rv` | alias | Shorthand for revisit |
| `cls` | alias | Open new tab and close current |
| `home` | alias | `'cd ~'` |
| `..` | alias | `'cd ..'` |
| `...` | alias | `'cd ../..'` |
| `....` | alias | `'cd ../../..'` |
| `.....` | alias | `'cd ../../../..'` |
| `.3` | alias | `'cd ../../../'` |
| `.4` | alias | `'cd ../../../../'` |
| `.5` | alias | `'cd ../../../../..'` |
| `ll` | alias | `'ls -la'` |
| `xx` | alias | Make file executable |
| `g2` | alias | Shorthand for goto |
| `gd` | alias | Shorthand for go_deep |
| `gf` | alias | Shorthand for go_find |
| `hg` | alias | History grep with highlighting |
| `h` | alias | `"history"` |
| `h1` | alias | `"history 10"` |
| `h2` | alias | `"history 20"` |
| `h3` | alias | `"history 30"` |
| `path` | alias | `'echo $PATH | tr -s ":" "\n"'` |
| `grepe` | function | Grep with highlighted matches — `command | grepe <pattern>` |
| `mkd` | function | Create directory and cd into it — `mkd <dir_name>` |
| `cdf` | function | cd to the frontmost Finder window location — `cdf` |
| `newtab` | function | Open a new Terminal tab, optionally running a command in it — `newtab [command]` |
| `mkd` | function | Create directory if not exists, then cd into it — `mkd <dir_name>` |
| `b` | function | Go back N entries in the directory stack (default: 1) — `b [N]` |
| `revisit` | function | Fuzzy search the directory stack and cd to a match — `revisit [search_term]` |
| `goto` | function | Fuzzy search current directory's subdirectories and cd to match — `goto [search_term]` |
| `go_deep` | function | Recursive fuzzy directory search from current location — `go_deep [search_term]` |
| `go_find` | function | Recursive fuzzy file search from current location — `go_find [search_term]` |
