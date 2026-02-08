| Name | Type | Description |
|------|------|-------------|
| `code` | alias | `'/Applications/Visual\ Studio\ Code.app/Contents/R...` |
| `open_with_code` | alias | `'open -a "Visual Studio Code"'` |
| `c.` | alias | `'repo_info -s;open_with_code $git_local_path'` |
| `a.` | alias | `'repo_info -s;atom $git_local_path'` |
| `s.` | alias | `'repo_info -s;sublime $git_local_path'` |
| `idea` | alias | `'open -a "`ls -dt /Applications/IntelliJ\ IDEA*|he...` |
| `i.` | alias | `'repo_info -s;idea $git_local_path'` |
| `o.` | alias | `'open .'` |
| `chrome` | alias | `'open -a "Google Chrome"'` |
| `pn.` | alias | `'chrome http://127.0.0.1:8192/ && /Applications/po...` |
| `chfox` | alias | `'open -a Charles;open -a Firefox'` |
| `excel` | alias | `'open -a "Microsoft Excel"'` |
| `snowsql` | alias | `'/Applications/SnowSQL.app/Contents/MacOS/snowsql'` |
| `ports` | alias | `'lsof -i | grep -E "(LISTEN|ESTABLISHED)"'` |
| `epc` | alias | `'open_with_code $PROFILE_DIR' # [E]dit [P]rofile (...` |
| `epa` | alias | `'atom $PROFILE_DIR'` |
| `ep` | alias | `'epc'` |
