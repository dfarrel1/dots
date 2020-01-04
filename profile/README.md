This directory is self-sufficient. 

[docs](../docs) and [doc_maker](../doc_maker) exist for documentation of files within this directory.

[xtra](../xtra) has expanded to IDE and macOS management scopes.

[vim](../vim) for vim.

.

## Installation [Mac]

1. Decide on a parent directory to keep all of your repos (I use `~/src`) and install there.

```
dots_dir = <repo-parent-dir-of-your-choice>/github.com/dfarrel1/dots
mkdir -p ${dots_dir} && cd ${dots_dir} && git clone https://github.com/dfarrel1/dots.git .
echo "source ${dots_dir}/profile/.profile" >> ~/.bashrc
echo "source ~/.bashrc" >> ~/.bash_profile
source ~/.bashrc
```

2. Add ons.

```
# hstr
brew bundle --f=${dots_dir}/xtra/MinimalBrewfile
```

3. Create PWDs

```
# okta - modify as needed
security add-generic-password -a ${USER} -s okta-user -w <okta-user>
security add-generic-password -a <okta-user> -s okta -w <okta-pass>
#
```

4. Add system python reqs

`pip install -r ${dots_dir}/xtra/python/global-reqs.txt`


5. Open up a terminal and have fun!


## Uninstall

To remove, you just need to take out the line you added in `~/.bashrc`

You can also delete the directory containing this repo.

## dotfile design pattern

`./profile/<category>.sh` files will include env, aliases, and functions for a scope of functionality. This modularity should make discoverability and management easier.

The following files are core dependencies:

- [.profile](./profile/.profile)
- [core.sh](./profile/core.sh)
- [navigation.sh](./profile/navigation.sh)

Everything else is (and should remain) self-contained and independent of one another with the exception of the those dependencies above. That means you can start your own dotfiles repo by stripping down to those three files if you want to avoid the overhead of inspecting so many files.
