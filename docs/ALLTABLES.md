# Dotfiles Reference

_Auto-generated from source annotations. Run `make docs` to regenerate._

## apps_linux

| Name | Type | Description |
|------|------|-------------|
| `c.` | alias | `'repo_info -s;code $git_local_path'` |
| `a.` | alias | `'repo_info -s;atom $git_local_path'` |
| `s.` | alias | `'repo_info -s;sublime $git_local_path'` |
| `idea` | alias | `'open -a "`ls -dt /Applications/IntelliJ\ IDEA*|he...` |
| `i.` | alias | `'repo_info -s;idea $git_local_path'` |
| `o.` | alias | `'nautilus .'` |
| `chrome` | alias | `'google-chrome'` |
| `pn.` | alias | `'chrome http://127.0.0.1:8192/ && /Applications/po...` |
| `chfox` | alias | `'open -a Charles;open -a Firefox'` |
| `excel` | alias | `'open -a "Microsoft Excel"'` |
| `snowsql` | alias | `'/Applications/SnowSQL.app/Contents/MacOS/snowsql'` |
| `ports` | alias | `'lsof -i | grep -E "(LISTEN|ESTABLISHED)"'` |
| `epc` | alias | `'open_with_code $PROFILE_DIR' # [E]dit [P]rofile (...` |
| `epa` | alias | `'atom $PROFILE_DIR'` |
| `ep` | alias | `'epc'` |
| `stree` | alias | `'~/src/smartgit/bin/smartgit.sh &'` |

## apps_mac

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

## aws-alts

| Name | Type | Description |
|------|------|-------------|
| `awskeys_selfcontained` | function | — |
| `mfa_deprecated` | function | — |
| `mfa_selfcontained` | function | — |

## aws

| Name | Type | Description |
|------|------|-------------|
| `1p` | alias | Start 1Password CLI session |
| `pb` | function | Copy the last shell command to clipboard (pasteboard) — `pb` |
| `get_list_of_tagged_secrets` | function | List 1Password items by tag name — `get_list_of_tagged_secrets <tag>` |
| `filter_array` | function | Filter a bash array by substring match (requires bash >= 4) — `filter_array <array-var-name> <filter-string>` |
| `choose_aws_secret` | function | Interactive picker for AWS secrets from 1Password — `choose_aws_secret [filter-string]` |
| `get_aws_acct_info` | function | Fetch AWS account info from a 1Password secret — `get_aws_acct_info` |
| `awskeys` | function | Export AWS access keys from 1Password to environment — `awskeys` |
| `mfa` | function | Get TOTP MFA code from 1Password and copy to clipboard — `mfa [secret-name]` |
| `newawslogin` | function | Create a new AWS login item template in 1Password — `newawslogin` |
| `newawsprofile` | function | Create a new aws-vault profile from a 1Password secret — `newawsprofile` |
| `awsloginbash` | function | (Deprecated) AWS console login via aws-vault with MFA + browser choice — `awsloginbash [filter-string]` |

## core

| Name | Type | Description |
|------|------|-------------|
| `easy_eyes` | function | Insert a blank line every 5 lines of output for readability — `command | easy_eyes` |
| `get_choice` | function | Interactive fuzzy selector: presents a numbered list, accepts filter text or number — `choice_set="item1\nitem2\nitem3"; get_choice` |
| `ckh` | function | Remove an entry from ~/.ssh/known_hosts by search term — `ckh <search_term>` |
| `source_env` | function | Source a .env file, exporting all variables — `source_env <file>` |
| `close` | function | Kill a process by searching open ports — `close <search_term>` |
| `tf` | function | Run terraform through aws-vault for the current AWS profile — `tf <terraform_args>` |

## docker

| Name | Type | Description |
|------|------|-------------|
| `clearcont` | alias | `'docker rm $(docker ps -a -q)'` |
| `clearimages` | alias | `'docker rmi $(docker images -q)'` |
| `cld` | alias | Full Docker cleanup (containers + images + prune) |
| `dc` | alias | docker-compose shorthand |
| `dcd` | alias | docker-compose down with orphan removal |
| `dcd1` | alias | docker-compose remove single service |
| `dcbuild` | alias | `'docker-compose build --no-cache'` |
| `dcup` | alias | `'docker-compose up'` |
| `buildup` | alias | `'dcbuild;dcup'` |
| `dcrun` | alias | `'docker-compose run --rm'` |
| `burn` | alias | Build, start, and run |
| `drun` | alias | `'docker run -it'` |
| `drunproxy` | alias | docker run with proxy env vars |
| `dbuild` | alias | docker build with proxy args |
| `dinfo` | alias | docker history |
| `dhist` | alias | docker history (no truncation) |
| `k` | alias | `"kubectl"` |
| `ka` | alias | `"kubectl apply -f"` |
| `kpa` | alias | `"kubectl patch -f"` |
| `ked` | alias | `"kubectl edit"` |
| `ksc` | alias | `"kubectl scale"` |
| `kex` | alias | `"kubectl exec -i -t"` |
| `kg` | alias | `"kubectl get"` |
| `kga` | alias | `"kubectl get all"` |
| `kgall` | alias | `"kubectl get all --all-namespaces"` |
| `kinfo` | alias | `"kubectl cluster-info"` |
| `kdesc` | alias | `"kubectl describe"` |
| `ktp` | alias | `"kubectl top"` |
| `klo` | alias | `"kubectl logs -f"` |
| `kn` | alias | `"kubectl get nodes"` |
| `kpv` | alias | `"kubectl get pv"` |
| `kpvc` | alias | `"kubectl get pvc"` |
| `dbash` | function | Interactive bash shell into a running container (fuzzy select) — `dbash [filter]` |
| `dsh` | function | Interactive sh shell into a running container (fuzzy select) — `dsh [filter]` |
| `dlogs` | function | View logs of a container (fuzzy select) — `dlogs [filter]` |
| `dock-run` | function | Run a container interactively with privileged mode — `dock-run <image> [args...]` |
| `dock-exec` | function | Exec into a container with bash — `dock-exec <container>` |
| `dock-log` | function | Follow all logs of a container — `dock-log <container>` |
| `dock-port` | function | Show port mappings for a container — `dock-port <container>` |
| `dock-vol` | function | Show volumes for a container — `dock-vol <container>` |
| `dock-ip` | function | Show IP address of a container — `dock-ip <container>` |
| `dock-rmc` | function | Remove exited containers — `dock-rmc` |
| `dock-rmi` | function | Remove dangling images — `dock-rmi` |
| `dock-stop` | function | Stop all running containers — `dock-stop` |
| `dock-rm` | function | Remove all containers — `dock-rm` |
| `dock-do` | function | Run a docker command on all containers — `dock-do <start|stop|pause|unpause>` |
| `restartdocker` | function | Full Docker restart cycle (stop containers, quit app, relaunch) — `restartdocker` |

## fun

| Name | Type | Description |
|------|------|-------------|
| `chp` | function | Interactive shell prompt theme picker — `chp [theme-name]` |
| `splasher` | function | Display random ASCII art from the art collection — `splasher` |
| `idler` | function | Open an asciiquarium screensaver in a fullscreen Terminal tab — `idler` |
| `tart` | function | Run a random tarts ASCII screensaver — `tart` |

## git

| Name | Type | Description |
|------|------|-------------|
| `bro` | alias | Alias for browse |
| `forcepush` | alias | `'git push origin `git rev-parse --abbrev-ref HEAD`...` |
| `or` | alias | Alias for open_repo |
| `tt` | alias | Open repo in new tab |
| `glog` | alias | Pretty git log graph |
| `gg` | alias | Git grep with line numbers |
| `gs` | alias | `'git status'` |
| `amend` | alias | `'git commit --amend --no-edit && git push origin `...` |
| `amendall` | alias | `'git add . && git commit --amend --no-edit && git ...` |
| `gitclean` | alias | `'git branch --merged | egrep -v "(^\*|master|dev)"...` |
| `gclu` | alias | Alias for git_clean_untracked_safely |
| `gclb` | alias | Alias for git_clean_local_branches |
| `gadd` | function | Git add all, commit with message, and push — `gadd <commit-message>` |
| `gslice` | function | Sparse checkout a single directory from a git repo — `gslice <git-repo> <git-dir> <output-path>` |
| `repo_info` | function | Parse current path into git domain/org/repo/tree/branch components — `repo_info [-s]` |
| `clone` | function | Clone a repo into the GOPATH directory tree with SSH alias resolution — `clone <repo-url|repo-name>` |
| `clonedds` | function | Clone via the dlf-dds GitHub SSH host — `clonedds <repo-url>` |
| `origin` | function | Initialize a git repo and set remote origin based on current path — `origin [push]` |
| `open_repo` | function | Navigate to a repo directory under GOPATH — `open_repo <repo-name>` |
| `alias2host` | function | Resolve an SSH alias to its actual hostname — `alias2host <ssh-alias>` |
| `host2alias` | function | (WIP) Resolve a hostname to its SSH alias — `host2alias <hostname>` |
| `browse` | function | Open the current repo in Chrome on the hosting site — `browse [path]` |
| `st` | function | Open the current repo in SourceTree — `st` |
| `base` | function | cd to the root of the current git repo — `base` |
| `git_clean_untracked_safely` | function | Interactively remove untracked files with confirmation — `git_clean_untracked_safely` |
| `git_clean_local_branches` | function | Remove local branches that are merged/gone from remote — `git_clean_local_branches [-f]` |
| `newghpattern` | function | Map a new GitHub Organization to a specific SSH identity — `newghpattern <https://github.com/my-org/>` |

## java

| Name | Type | Description |
|------|------|-------------|
| `worldcom` | alias | `'mvn clean install'` |
| `sbr` | alias | `'mvn spring-boot:run'` |
| `cr` | alias | `'cargorun'` |
| `vcr` | alias | `'worldcom;jcr'` |
| `adb` | alias | `'~/Library/Android/sdk/platform-tools/adb'` |
| `avd` | alias | `'~/Library/Android/sdk/tools/emulator -avd'` |
| `avdlist` | alias | `'~/Library/Android/sdk/tools/emulator -list-avds'` |
| `intellij` | alias | `'open -a "IntelliJ IDEA CE"'` |

## latch

| Name | Type | Description |
|------|------|-------------|
| `sts` | alias | `'OKTA_PASSWORD="`security find-generic-password -a...` |
| `cdp` | alias | `'./target/universal/stage/bin/cdp-data-transformer...` |
| `cdp-prod` | alias | `'export JAVA_OPTS="-Xmx4g -Denv=prod" && cdp'` |
| `fresh_vpn` | alias | `"${HERE}/../xtra/vpn/refresh-vpn.sh"` |
| `gvpn` | alias | `'ps aux | grep -i "openvpn --config"'` |
| `killvpn` | alias | `"ps aux | grep -i 'openvpn --config' | awk {'print...` |
| `vpnlog` | alias | `'sudo tail -f  /var/log/openvpn.log'` |
| `loadvpn` | alias | `'sudo launchctl load -w /Library/LaunchDaemons/ope...` |
| `unloadvpn` | alias | `'sudo launchctl unload -w /Library/LaunchDaemons/o...` |
| `startvpn` | alias | `'sudo launchctl start openvpn.latch.client'` |
| `stopvpn` | alias | `'sudo launchctl stop openvpn.latch.client'` |
| `listvpn` | alias | `'sudo launchctl list | grep vpn'` |
| `vpn` | function | — |
| `quickdirs` | function | — |

## mac_cpu_type

| Name | Type | Description |
|------|------|-------------|

## misc

| Name | Type | Description |
|------|------|-------------|
| `src` | alias | Re-source bashrc |
| `whatami` | alias | Show current shell process |
| `syslog` | alias | Follow system log |
| `ipecho` | alias | Show external IP address |
| `myip` | alias | Show local IP (en1) |
| `whereami` | alias | Show pwd + external IP |
| `speed` | alias | Run internet speed test |
| `awake` | alias | Prevent sleep (caffeinate) |
| `decaf` | alias | Stop caffeinate |
| `grep` | alias | `'grep --color=auto'` |
| `fgrep` | alias | `'fgrep --color=auto'` |
| `egrep` | alias | `'egrep --color=auto'` |
| `fix_brew_perms` | alias | Fix homebrew permissions |
| `fix_all_perms` | alias | Fix homebrew + cache permissions |
| `code-plugs` | alias | `"""` |
| `hstr` | alias | History search tool |
| `json` | alias | Pretty-print JSON via Python |
| `update_terminal_cwd` | function | Update terminal working directory for VS Code compatibility — `update_terminal_cwd` |

## navigation

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

## newwave

| Name | Type | Description |
|------|------|-------------|
| `install_newwave` | function | Install all modern CLI tools via Homebrew — `install_newwave` |

## op_session

| Name | Type | Description |
|------|------|-------------|
| `check_session` | function | — |
| `main` | function | — |
| `reset_timeout` | function | — |
| `signin` | function | — |
| `update_session_file` | function | — |

## python

| Name | Type | Description |
|------|------|-------------|
| `note` | alias | Launch Jupyter notebook |
| `python` | alias | `"${BIN_PATH}/python3"` |
| `pipup` | function | Reinstall/upgrade pip from the official bootstrap script — `pipup` |
| `venv` | function | Activate a virtualenv by fuzzy name search from ~/envs — `venv <partial-name>` |
| `new_venv` | function | Create a new virtualenv in ~/envs and activate it — `new_venv [virtualenv-options] <name>` |
| `server` | function | Start a Python HTTP server and open browser — `server [port]` |

## scala

| Name | Type | Description |
|------|------|-------------|
| `stest` | function | — |
| `dc_stest` | function | — |
| `get_test_name` | function | — |
| `get_tests` | function | — |
| `RM_COLOR` | function | — |
| `LINES2FILES` | function | — |
| `FILE2LINK` | function | — |
| `RM_TRAILING_COLON` | function | — |
| `clicks` | function | — |

## sls

| Name | Type | Description |
|------|------|-------------|

## typescript

| Name | Type | Description |
|------|------|-------------|

## vim

| Name | Type | Description |
|------|------|-------------|

---

## Coverage

| Metric | Count |
|--------|-------|
| Total items | 226 |
| Documented | 207 |
| Undocumented | 19 |
| Coverage | 91% |

_Generated: 2026-02-08 22:19_
