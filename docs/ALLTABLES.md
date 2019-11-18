

**core**



| name       |  type     |  desc                                                  |  file    |  note |
| ---------- | --------- | ------------------------------------------------------ | -------- | ----- |
| code       |  alias    |  'open -a "Visual Studio Code"'                        |  core.sh |  <->  |
| c.         |  alias    |  'repo_info -s;code $git_local_path'                   |  core.sh |  <->  |
| a.         |  alias    |  'repo_info -s;atom $git_local_path'                   |  core.sh |  <->  |
| s.         |  alias    |  'repo_info -s;sublime $git_local_path'                |  core.sh |  <->  |
| i.         |  alias    |  'repo_info -s;intellij $git_local_path'               |  core.sh |  <->  |
| o.         |  alias    |  'open .'                                              |  core.sh |  <->  |
| chrome     |  alias    |  'open -a "Google Chrome"'                             |  core.sh |  <->  |
| pn.        |  alias    |  'chrome http://127.0.0.1:8192/ && /Appli...           |  core.sh |  <->  |
| chfox      |  alias    |  'open -a Charles;open -a Firefox'                     |  core.sh |  <->  |
| excel      |  alias    |  'open -a "Microsoft Excel"'                           |  core.sh |  <->  |
| ports      |  alias    |  'lsof -i &#124; grep -E "(LISTEN&#124;ESTABLISHED)... |  core.sh |  <->  |
| epc        |  alias    |  'code $PROFILE_DIR'                                   |  core.sh |  <->  |
| epa        |  alias    |  'atom $PROFILE_DIR'                                   |  core.sh |  <->  |
| ep         |  alias    |  'epc'                                                 |  core.sh |  <->  |
| ckh        |  function |  <what does ckh do ?>                                  |  core.sh |  <->  |
| close      |  function |  <what does close do ?>                                |  core.sh |  <->  |
| get_choice |  function |  <what does get_choice do ?>                           |  core.sh |  <->  |
| source_env |  function |  <what does source_env do ?>                           |  core.sh |  <->  |


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
| dbash       |  function |  <what does dbash do ?>                      |  docker.sh |  <->  |
| dlogs       |  function |  <what does dlogs do ?>                      |  docker.sh |  <->  |
| dsh         |  function |  <what does dsh do ?>                        |  docker.sh |  <->  |


**git-completion**



| name                                                                                                           |  type              |  desc                                        |
| -------------------------------------------------------------------------------------------------------------- | ------------------ | -------------------------------------------- |
| --list-cmds                                                                                                    |  alias             |  main;others;alias;nohelpers)                |
| ()                                                                                                             |  alias             |  __git_pretty_aliases ()                     |
| ()                                                                                                             |  alias             |  __git_aliased_command ()                    |
| word                                                                                                           |  alias             |  $(__git config --get "alias.$1")            |
| :                                                                                                              |  alias             |  		\!*)	: shell command alias ;;             |
| $GIT_TESTING_ALL_COMMAND_LIST, alias, alias;list-guide) gitk                                                   |  git-completion.sh |  <->                                         |
| $(__git, alias, main;nohelpers;alias;list-guide) gitk                                                          |  git-completion.sh |  <->                                         |
| $__git_log_pretty_formats, alias, 		__gitcomp $__git_log_pretty_formats $...                                   |  git-completion.sh |  <->                                         |
| $(__git, alias, 		__gitcomp $(__git send-email --dump-a...                                                     |  git-completion.sh |  <->                                         |
| $(__git, alias, }                                                                                              |  git-completion.sh |  <->                                         |
| $__git_log_pretty_formats, alias, 	sendemail.aliasfiletype)                  , git-completion.sh, <-> 
$(__git |  alias             |  		__gitcomp "$__git_log_pretty_formats $... |
| expansion                                                                                                      |  alias             |  list-mainporcelain;others;nohelpers;alia... |


**git**



| name                       |  type     |  desc                                        |  file   |  note |
| -------------------------- | --------- | -------------------------------------------- | ------- | ----- |
| bro                        |  alias    |  'browse'                                    |  git.sh |  <->  |
| forcepush                  |  alias    |  'git push origin `git rev-parse --abbrev... |  git.sh |  <->  |
| or                         |  alias    |  'open_repo'                                 |  git.sh |  <->  |
| tt                         |  alias    |  'newtab open_repo'                          |  git.sh |  <->  |
| glog                       |  alias    |  format:"%Cred%h%Creset -%C(yellow)%d%Cre... |  git.sh |  <->  |
| gg                         |  alias    |  'git grep --line-number'                    |  git.sh |  <->  |
| gclu                       |  alias    |  'git_clean_untracked_safely'                |  git.sh |  <->  |
| gclb                       |  alias    |  'git_clean_local_branches'                  |  git.sh |  <->  |
| base                       |  function |  <what does base do ?>                       |  git.sh |  <->  |
| browse                     |  function |  <what does browse do ?>                     |  git.sh |  <->  |
| clone                      |  function |  <what does clone do ?>                      |  git.sh |  <->  |
| git_clean_local_branches   |  function |  <what does git_clean_local_branches do ?>   |  git.sh |  <->  |
| git_clean_untracked_safely |  function |  <what does git_clean_untracked_safely do ?> |  git.sh |  <->  |
| open_repo                  |  function |  <what does open_repo do ?>                  |  git.sh |  <->  |
| origin                     |  function |  <what does origin do ?>                     |  git.sh |  <->  |
| repo_info                  |  function |  <what does repo_info do ?>                  |  git.sh |  <->  |
| st                         |  function |  <what does st do ?>                         |  git.sh |  <->  |


**java**



| name      |  type     |  desc                                        |  file    |  note |
| --------- | --------- | -------------------------------------------- | -------- | ----- |
| worldcom  |  alias    |  'mvn clean install'                         |  java.sh |  <->  |
| sbr       |  alias    |  'mvn spring-boot:run'                       |  java.sh |  <->  |
| cr        |  alias    |  'cargorun'                                  |  java.sh |  <->  |
| vcr       |  alias    |  'worldcom;jcr'                              |  java.sh |  <->  |
| intellij  |  alias    |  'open -a "IntelliJ IDEA CE"'                |  java.sh |  <->  |
| kafkaup   |  alias    |  'zookeeper-server-start /usr/local/etc/k... |  java.sh |  <->  |
| kafkadown |  alias    |  'zookeeper-server-stop'                     |  java.sh |  <->  |
| _jenv     |  function |  <what does _jenv do ?>                      |  java.sh |  <->  |
| cargorun  |  function |  <what does cargorun do ?>                   |  java.sh |  <->  |
| jcr       |  function |  <what does jcr do ?>                        |  java.sh |  <->  |
| jenv      |  function |  <what does jenv do ?>                       |  java.sh |  <->  |
| kafkacomm |  function |  <what does kafkacomm do ?>                  |  java.sh |  <->  |
| mcr       |  function |  <what does mcr do ?>                        |  java.sh |  <->  |
| wcr       |  function |  <what does wcr do ?>                        |  java.sh |  <->  |


**latch**



| name     |  type  |  desc                                        |  file     |  note |
| -------- | ------ | -------------------------------------------- | --------- | ----- |
| sts      |  alias |  'gimme-aws-creds'                           |  latch.sh |  <->  |
| cdp      |  alias |  './target/universal/stage/bin/cdp-data-t... |  latch.sh |  <->  |
| cdp-prod |  alias |  prod" && cdp'                               |  latch.sh |  <->  |


**mac**



| name       |  type  |  desc                                        |  file   |  note |
| ---------- | ------ | -------------------------------------------- | ------- | ----- |
| code-plugs |  alias |  'ls ~/.vscode/extensions > ${DIR}/../xtr... |  mac.sh |  <->  |


**navigation**



| name    |  type     |  desc                                             |  file          |  note |
| ------- | --------- | ------------------------------------------------- | -------------- | ----- |
| cd      |  alias    |  'pushd . >> /dev/null;cd'                        |  navigation.sh |  <->  |
| back    |  alias    |  'popd >> /dev/null'                              |  navigation.sh |  <->  |
| ld      |  alias    |  'dirs -p &#124; nl -v 0'                         |  navigation.sh |  <->  |
| rv      |  alias    |  'revisit'                                        |  navigation.sh |  <->  |
| cls     |  alias    |  'newtab;exit'                                    |  navigation.sh |  <->  |
| ..      |  alias    |  'cd ..'                                          |  navigation.sh |  <->  |
| ...     |  alias    |  'cd ../..'                                       |  navigation.sh |  <->  |
| ....    |  alias    |  'cd ../../..'                                    |  navigation.sh |  <->  |
| .....   |  alias    |  'cd ../../../..'                                 |  navigation.sh |  <->  |
| ll      |  alias    |  'pwd;ls -la'                                     |  navigation.sh |  <->  |
| xx      |  alias    |  'chmod +x'                                       |  navigation.sh |  <->  |
| g2      |  alias    |  'goto'                                           |  navigation.sh |  <->  |
| gd      |  alias    |  'go_deep'                                        |  navigation.sh |  <->  |
| gf      |  alias    |  'go_find'                                        |  navigation.sh |  <->  |
| hg      |  alias    |  'history &#124; grep '                           |  navigation.sh |  <->  |
| b       |  function |  <what does b do ?>                               |  navigation.sh |  <->  |
| go_deep |  function |  <what does go_deep do ?>                         |  navigation.sh |  <->  |
| go_find |  function |  <what does go_find do ?>                         |  navigation.sh |  <->  |
| goto    |  function |  <what does goto do ?>                            |  navigation.sh |  <->  |
| mkd     |  function |  <what does mkd do ?>                             |  navigation.sh |  <->  |
| newtab  |  function |  <what does newtab do ?>                          |  navigation.sh |  <->  |
| revisit |  function |  <what does revisit do ?>                         |  navigation.sh |  <->  |


**python**



| name     |  type     |  desc                                        |  file      |  note |
| -------- | --------- | -------------------------------------------- | ---------- | ----- |
| python   |  alias    |  /usr/local/bin/python3                      |  python.sh |  <->  |
| pip      |  alias    |  /usr/local/bin/pip3                         |  python.sh |  <->  |
| new_venv |  function |  <what does new_venv do ?>                   |  python.sh |  <->  |
| pipup    |  function |  <what does pipup do ?>                      |  python.sh |  <->  |
| venv     |  function |  <what does venv do ?>                       |  python.sh |  <->  |


**scala**



| name      |  type  |  desc                                        |  file     |  note |
| --------- | ------ | -------------------------------------------- | --------- | ----- |
| submit    |  alias |  'sbt "submit dene.farrell@latch.com $(re... |  scala.sh |  <->  |
| subm-test |  alias |  'read -p "Assignment Password:" pass; ec... |  scala.sh |  <->  |
