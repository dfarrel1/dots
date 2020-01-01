

**core**



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


**docker**



| name        |  type     |  desc                                        |  file      |  note |
| ----------- | --------- | -------------------------------------------- | ---------- | ----- |
| clearcont   |  alias    |  'docker rm $(docker ps -a -q)'              |  docker.sh |  <->  |
| clearimages |  alias    |  'docker rmi $(docker images -q)'            |  docker.sh |  <->  |
| cld         |  alias    |  'clearcont;clearimages;docker system pru... |  docker.sh |  <->  |
| dc          |  alias    |  'docker-compose'                            |  docker.sh |  <->  |
| dcbuild     |  alias    |  'docker-compose build --no-cache'           |  docker.sh |  <->  |
| dcup        |  alias    |  'docker-compose up'                         |  docker.sh |  <->  |
| buildup     |  alias    |  'dcbuild;dcup'                              |  docker.sh |  <->  |
| dcrun       |  alias    |  'docker-compose run --rm'                   |  docker.sh |  <->  |
| burn        |  alias    |  'buildup;dcrun'                             |  docker.sh |  <->  |
| drun        |  alias    |  'docker run -it'                            |  docker.sh |  <->  |
| drunproxy   |  alias    |  $"$http_proxy" -it'                         |  docker.sh |  <->  |
| dbuild      |  alias    |  $http_proxy'                                |  docker.sh |  <->  |
| dinfo       |  alias    |  'docker history'                            |  docker.sh |  <->  |
| dhist       |  alias    |  'docker history --no-trunc'                 |  docker.sh |  <->  |
| k           |  alias    |  "kubectl"                                   |  docker.sh |  <->  |
| ka          |  alias    |  "kubectl apply -f"                          |  docker.sh |  <->  |
| kpa         |  alias    |  "kubectl patch -f"                          |  docker.sh |  <->  |
| ked         |  alias    |  "kubectl edit"                              |  docker.sh |  <->  |
| ksc         |  alias    |  "kubectl scale"                             |  docker.sh |  <->  |
| kex         |  alias    |  "kubectl exec -i -t"                        |  docker.sh |  <->  |
| kg          |  alias    |  "kubectl get"                               |  docker.sh |  <->  |
| kga         |  alias    |  "kubectl get all"                           |  docker.sh |  <->  |
| kgall       |  alias    |  "kubectl get all --all-namespaces"          |  docker.sh |  <->  |
| kinfo       |  alias    |  "kubectl cluster-info"                      |  docker.sh |  <->  |
| kdesc       |  alias    |  "kubectl describe"                          |  docker.sh |  <->  |
| ktp         |  alias    |  "kubectl top"                               |  docker.sh |  <->  |
| klo         |  alias    |  "kubectl logs -f"                           |  docker.sh |  <->  |
| kn          |  alias    |  "kubectl get nodes"                         |  docker.sh |  <->  |
| kpv         |  alias    |  "kubectl get pv"                            |  docker.sh |  <->  |
| kpvc        |  alias    |  "kubectl get pvc"                           |  docker.sh |  <->  |
| dbash       |  function |  <what does dbash do ?>                      |  docker.sh |  <->  |
| dlogs       |  function |  <what does dlogs do ?>                      |  docker.sh |  <->  |
| dock-do     |  function |  <what does dock-do do ?>                    |  docker.sh |  <->  |
| dock-exec   |  function |  <what does dock-exec do ?>                  |  docker.sh |  <->  |
| dock-ip     |  function |  <what does dock-ip do ?>                    |  docker.sh |  <->  |
| dock-log    |  function |  <what does dock-log do ?>                   |  docker.sh |  <->  |
| dock-port   |  function |  <what does dock-port do ?>                  |  docker.sh |  <->  |
| dock-rm     |  function |  <what does dock-rm do ?>                    |  docker.sh |  <->  |
| dock-rmc    |  function |  <what does dock-rmc do ?>                   |  docker.sh |  <->  |
| dock-rmi    |  function |  <what does dock-rmi do ?>                   |  docker.sh |  <->  |
| dock-run    |  function |  <what does dock-run do ?>                   |  docker.sh |  <->  |
| dock-stop   |  function |  <what does dock-stop do ?>                  |  docker.sh |  <->  |
| dock-vol    |  function |  <what does dock-vol do ?>                   |  docker.sh |  <->  |
| dsh         |  function |  <what does dsh do ?>                        |  docker.sh |  <->  |


**git-completion**



| name |  type |  desc |  file |  note |
| ---- | ----- | ----- | ----- | ----- |


**git**



| name                       |  type     |  desc                                        |  file   |  note |
| -------------------------- | --------- | -------------------------------------------- | ------- | ----- |
| bro                        |  alias    |  'browse'                                    |  git.sh |  <->  |
| forcepush                  |  alias    |  'git push origin `git rev-parse --abbrev... |  git.sh |  <->  |
| or                         |  alias    |  'open_repo'                                 |  git.sh |  <->  |
| tt                         |  alias    |  'newtab open_repo'                          |  git.sh |  <->  |
| glog                       |  alias    |  format:"%Cred%h%Creset -%C(yellow)%d%Cre... |  git.sh |  <->  |
| gg                         |  alias    |  'git grep --line-number'                    |  git.sh |  <->  |
| gs                         |  alias    |  'git status'                                |  git.sh |  <->  |
| amend                      |  alias    |  'git commit --amend --no-edit && git pus... |  git.sh |  <->  |
| gclu                       |  alias    |  'git_clean_untracked_safely'                |  git.sh |  <->  |
| gclb                       |  alias    |  'git_clean_local_branches'                  |  git.sh |  <->  |
| base                       |  function |  <what does base do ?>                       |  git.sh |  <->  |
| browse                     |  function |  <what does browse do ?>                     |  git.sh |  <->  |
| clone                      |  function |  <what does clone do ?>                      |  git.sh |  <->  |
| git_clean_local_branches   |  function |  <what does git_clean_local_branches do ?>   |  git.sh |  <->  |
| git_clean_untracked_safely |  function |  <what does git_clean_untracked_safely do ?> |  git.sh |  <->  |
| gslice                     |  function |  <what does gslice do ?>                     |  git.sh |  <->  |
| open_repo                  |  function |  <what does open_repo do ?>                  |  git.sh |  <->  |
| origin                     |  function |  <what does origin do ?>                     |  git.sh |  <->  |
| repo_info                  |  function |  <what does repo_info do ?>                  |  git.sh |  <->  |
| st                         |  function |  <what does st do ?>                         |  git.sh |  <->  |


**java**



| name     |  type     |  desc                                        |  file    |  note |
| -------- | --------- | -------------------------------------------- | -------- | ----- |
| worldcom |  alias    |  'mvn clean install'                         |  java.sh |  <->  |
| sbr      |  alias    |  'mvn spring-boot:run'                       |  java.sh |  <->  |
| cr       |  alias    |  'cargorun'                                  |  java.sh |  <->  |
| vcr      |  alias    |  'worldcom;jcr'                              |  java.sh |  <->  |
| intellij |  alias    |  'open -a "IntelliJ IDEA CE"'                |  java.sh |  <->  |
| jenv     |  function |  <what does jenv do ?>                       |  java.sh |  <->  |


**latch**



| name      |  type     |  desc                                                  |  file     |  note |
| --------- | --------- | ------------------------------------------------------ | --------- | ----- |
| sts       |  alias    |  "`security find-generic-password -a ${ok...           |  latch.sh |  <->  |
| cdp       |  alias    |  './target/universal/stage/bin/cdp-data-t...           |  latch.sh |  <->  |
| cdp-prod  |  alias    |  prod" && cdp'                                         |  latch.sh |  <->  |
| fresh_vpn |  alias    |  "sudo ${HERE}/../xtra/vpn/refresh-vpn.sh...           |  latch.sh |  <->  |
| gvpn      |  alias    |  'ps aux &#124; grep -i "openvpn --config"'            |  latch.sh |  <->  |
| killvpn   |  alias    |  "ps aux &#124; grep -i 'openvpn --config' &#124; a... |  latch.sh |  <->  |
| vpnlog    |  alias    |  'sudo tail -f  /var/log/openvpn.log'                  |  latch.sh |  <->  |
| loadvpn   |  alias    |  'sudo launchctl load -w /Library/LaunchD...           |  latch.sh |  <->  |
| unloadvpn |  alias    |  'sudo launchctl unload -w /Library/Launc...           |  latch.sh |  <->  |
| startvpn  |  alias    |  'sudo launchctl start openvpn.latch.clie...           |  latch.sh |  <->  |
| stopvpn   |  alias    |  'sudo launchctl stop openvpn.latch.clien...           |  latch.sh |  <->  |
| listvpn   |  alias    |  'sudo launchctl list &#124; grep vpn'                 |  latch.sh |  <->  |
| vpn       |  function |  <what does vpn do ?>                                  |  latch.sh |  <->  |
| work      |  function |  <what does work do ?>                                 |  latch.sh |  <->  |


**mac**



| name                |  type     |  desc                                                  |  file   |  note |
| ------------------- | --------- | ------------------------------------------------------ | ------- | ----- |
| src                 |  alias    |  "source ~/.bashrc > /dev/null"                        |  mac.sh |  <->  |
| snowsql             |  alias    |  '/Applications/SnowSQL.app/Contents/MacO...           |  mac.sh |  <->  |
| whatami             |  alias    |  'ps -p $$'                                            |  mac.sh |  <->  |
| syslog              |  alias    |  'tail -f /var/log/system.log'                         |  mac.sh |  <->  |
| ipecho              |  alias    |  'curl ipecho.net/plain ; echo'                        |  mac.sh |  <->  |
| myip                |  alias    |  "ifconfig en0 &#124; grep inet &#124; grep -v inet... |  mac.sh |  <->  |
| whereami            |  alias    |  'pwd ; ipecho'                                        |  mac.sh |  <->  |
| speed               |  alias    |  'speedtest-cli'                                       |  mac.sh |  <->  |
| awake               |  alias    |  'caffeinate &'                                        |  mac.sh |  <->  |
| decaf               |  alias    |  'killall caffeinate'                                  |  mac.sh |  <->  |
| grep                |  alias    |  auto"                                                 |  mac.sh |  <->  |
| fgrep               |  alias    |  auto"                                                 |  mac.sh |  <->  |
| egrep               |  alias    |  auto"                                                 |  mac.sh |  <->  |
| code-plugs          |  alias    |  """                                                   |  mac.sh |  <->  |
| hstr                |  alias    |  'hstr'                                                |  mac.sh |  <->  |
| json                |  alias    |  'python -m json.tool'                                 |  mac.sh |  <->  |
| chp                 |  function |  <what does chp do ?>                                  |  mac.sh |  <->  |
| update_terminal_cwd |  function |  <what does update_terminal_cwd do ?>                  |  mac.sh |  <->  |


**navigation**



| name    |  type     |  desc                                             |  file          |  note |
| ------- | --------- | ------------------------------------------------- | -------------- | ----- |
| cd      |  alias    |  'pushd . >> /dev/null;cd'                        |  navigation.sh |  <->  |
| back    |  alias    |  'popd >> /dev/null'                              |  navigation.sh |  <->  |
| ld      |  alias    |  'dirs -p &#124; nl -v 0'                         |  navigation.sh |  <->  |
| rv      |  alias    |  'revisit'                                        |  navigation.sh |  <->  |
| cls     |  alias    |  'newtab;exit'                                    |  navigation.sh |  <->  |
| home    |  alias    |  'cd ~'                                           |  navigation.sh |  <->  |
| ..      |  alias    |  'cd ..'                                          |  navigation.sh |  <->  |
| ...     |  alias    |  'cd ../..'                                       |  navigation.sh |  <->  |
| ....    |  alias    |  'cd ../../..'                                    |  navigation.sh |  <->  |
| .....   |  alias    |  'cd ../../../..'                                 |  navigation.sh |  <->  |
| .3      |  alias    |  'cd ../../../'                                   |  navigation.sh |  <->  |
| .4      |  alias    |  'cd ../../../../'                                |  navigation.sh |  <->  |
| .5      |  alias    |  'cd ../../../../..'                              |  navigation.sh |  <->  |
| ll      |  alias    |  'ls -la'                                         |  navigation.sh |  <->  |
| xx      |  alias    |  'chmod +x'                                       |  navigation.sh |  <->  |
| g2      |  alias    |  'goto'                                           |  navigation.sh |  <->  |
| gd      |  alias    |  'go_deep'                                        |  navigation.sh |  <->  |
| gf      |  alias    |  'go_find'                                        |  navigation.sh |  <->  |
| hg      |  alias    |  'history &#124; grepe '                          |  navigation.sh |  <->  |
| h       |  alias    |  "history"                                        |  navigation.sh |  <->  |
| h1      |  alias    |  "history 10"                                     |  navigation.sh |  <->  |
| h2      |  alias    |  "history 20"                                     |  navigation.sh |  <->  |
| h3      |  alias    |  "history 30"                                     |  navigation.sh |  <->  |
| b       |  function |  <what does b do ?>                               |  navigation.sh |  <->  |
| cdf     |  function |  <what does cdf do ?>                             |  navigation.sh |  <->  |
| go_deep |  function |  <what does go_deep do ?>                         |  navigation.sh |  <->  |
| go_find |  function |  <what does go_find do ?>                         |  navigation.sh |  <->  |
| goto    |  function |  <what does goto do ?>                            |  navigation.sh |  <->  |
| grepe   |  function |  <what does grepe do ?>                           |  navigation.sh |  <->  |
| mkd     |  function |  <what does mkd do ?>                             |  navigation.sh |  <->  |
| newtab  |  function |  <what does newtab do ?>                          |  navigation.sh |  <->  |
| revisit |  function |  <what does revisit do ?>                         |  navigation.sh |  <->  |
| server  |  function |  <what does server do ?>                          |  navigation.sh |  <->  |


**private**



| name      |  type     |  desc                                                  |  file       |  note |
| --------- | --------- | ------------------------------------------------------ | ----------- | ----- |
| fresh_env |  alias    |  "pew workon `pew ls &#124; tr ' ' '\n' &#124; grep... |  private.sh |  <->  |
| freshen   |  function |  <what does freshen do ?>                              |  private.sh |  <->  |


**python**



| name     |  type     |  desc                                        |  file      |  note |
| -------- | --------- | -------------------------------------------- | ---------- | ----- |
| python   |  alias    |  /usr/local/bin/python3                      |  python.sh |  <->  |
| pip      |  alias    |  /usr/local/bin/pip3                         |  python.sh |  <->  |
| new_venv |  function |  <what does new_venv do ?>                   |  python.sh |  <->  |
| pipup    |  function |  <what does pipup do ?>                      |  python.sh |  <->  |
| venv     |  function |  <what does venv do ?>                       |  python.sh |  <->  |


**scala**



| name              |  type     |  desc                               |  file     |  note |
| ----------------- | --------- | ----------------------------------- | --------- | ----- |
| FILE2LINK         |  function |  <what does FILE2LINK do ?>         |  scala.sh |  <->  |
| LINES2FILES       |  function |  <what does LINES2FILES do ?>       |  scala.sh |  <->  |
| RM_COLOR          |  function |  <what does RM_COLOR do ?>          |  scala.sh |  <->  |
| RM_TRAILING_COLON |  function |  <what does RM_TRAILING_COLON do ?> |  scala.sh |  <->  |
| clicks            |  function |  <what does clicks do ?>            |  scala.sh |  <->  |
| get_test_name     |  function |  <what does get_test_name do ?>     |  scala.sh |  <->  |
| get_tests         |  function |  <what does get_tests do ?>         |  scala.sh |  <->  |
| stest             |  function |  <what does stest do ?>             |  scala.sh |  <->  |


**sls**



| name |  type |  desc |  file |  note |
| ---- | ----- | ----- | ----- | ----- |


**vim**



| name |  type |  desc |  file |  note |
| ---- | ----- | ----- | ----- | ----- |
