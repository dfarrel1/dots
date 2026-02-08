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
