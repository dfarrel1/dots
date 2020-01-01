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
