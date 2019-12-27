| name           |  type     |  desc                                                  |  file    |  note |
| -------------- | --------- | ------------------------------------------------------ | -------- | ----- |
| code           |  alias    |  '/Applications/Visual\ Studio\ Code.app/...           |  core.sh |  <->  |
| open_with_code |  alias    |  'open -a "Visual Studio Code"'                        |  core.sh |  <->  |
| c.             |  alias    |  'repo_info -s;open_with_code $git_local_...           |  core.sh |  <->  |
| a.             |  alias    |  'repo_info -s;atom $git_local_path'                   |  core.sh |  <->  |
| s.             |  alias    |  'repo_info -s;sublime $git_local_path'                |  core.sh |  <->  |
| i.             |  alias    |  'repo_info -s;intellij $git_local_path'               |  core.sh |  <->  |
| o.             |  alias    |  'open .'                                              |  core.sh |  <->  |
| chrome         |  alias    |  'open -a "Google Chrome"'                             |  core.sh |  <->  |
| pn.            |  alias    |  'chrome http://127.0.0.1:8192/ && /Appli...           |  core.sh |  <->  |
| chfox          |  alias    |  'open -a Charles;open -a Firefox'                     |  core.sh |  <->  |
| excel          |  alias    |  'open -a "Microsoft Excel"'                           |  core.sh |  <->  |
| ports          |  alias    |  'lsof -i &#124; grep -E "(LISTEN&#124;ESTABLISHED)... |  core.sh |  <->  |
| epc            |  alias    |  'open_with_code $PROFILE_DIR'                         |  core.sh |  <->  |
| epa            |  alias    |  'atom $PROFILE_DIR'                                   |  core.sh |  <->  |
| ep             |  alias    |  'epc'                                                 |  core.sh |  <->  |
| ckh            |  function |  <what does ckh do ?>                                  |  core.sh |  <->  |
| close          |  function |  <what does close do ?>                                |  core.sh |  <->  |
| get_choice     |  function |  <what does get_choice do ?>                           |  core.sh |  <->  |
| source_env     |  function |  <what does source_env do ?>                           |  core.sh |  <->  |
