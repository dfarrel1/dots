This directory is self-sufficient. 

[docs](../docs) and [doc_maker](../doc_maker) exist for documentation of files within this directory.

[xtra](../xtra) has expanded to IDE and macOS management scopes.

[vim](../vim) for vim.

.

## Installation [Mac]

1. Decide on a parent directory to keep all of your repos. I use `~/src`

```
mkdir <repo-parent-dir>
cd <repo-parent-dir>
git clone https://github.com/dfarrel1/dots.git
echo "source <repo-parent-dir>/github.com/dfarrel1/dots/profile/.profile" >> ~/.bashrc
echo "source ~/.bashrc" >> ~/.bash_profile
source ~/.bashrc
```
