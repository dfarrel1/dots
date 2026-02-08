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
