# Long From Documentation.

Bash profile modifying files

> **_NOTE:_** Use only `/bin/bash` with these dotfiles. Things get hairy with other flavors like zsh.

The following is WIP. I'm trying to document code to make it more easily digestible. 
These manual outlines written out below are not yet complete. 

Each linked summary view, however, does contain all aliases and functions for it's corresponding `.sh` if the auto-documentation has been run since the last update to that file, because they are generated programmatically, not manually.

## Summary Views

### **[core.sh](./profile/core.sh)**  -- **[summary](./docs/core.auto.md)**

**highlights**
- applications aliases
- functions used in navigation functions (e.g. `get_choice()`)
  
### **[docker.sh](./profile/docker.sh)**  -- **[summary](./docs/docker.auto.md)**

**highlights**
- docker stuff:
    - build
    - bash
    - run
    - logs
    - cleanup

### **[git.sh](./profile/git.sh)**  -- **[summary](./docs/git.auto.md)**

**highlights**

By using a fully qualified directory in the local volume, we can tether web browsing and file browsing.
  
### **[java.sh](./profile/java.sh)**  -- **[summary](./docs/java.auto.md)**

**highlights**

Kafka, MVN, etc.

### **[navigation.sh](./profile/navigation.sh)**  -- **[summary](./docs/navigation.auto.md)**

**highlights**

FS navigation leveraging grep


### **[python.sh](./profile/python.sh)**  -- **[summary](./docs/python.auto.md)**

**highlights**

`venv` management function

### Full Table

A comprehensive list of all aliases and functions.

\>\>**[everything](./docs/ALLTABLES.md)**<<
 

### Note about documentation
The `./profile` directory is self-sufficient. The surrounding repo is for automatically constructing documentation.

### quickstart auto-documentation

```
### (if necessary) pip install pipenv 
make everything
```
