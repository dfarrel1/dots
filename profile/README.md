This directory is self-sufficient. 

[docs](../docs) and [doc_maker](../doc_maker) exist for documentation of files within this directory.

[xtra](../xtra) has expanded to IDE and macOS management scopes.

[vim](../vim) for vim.

.

## Installation [Mac]

[ windows: **[windows-install](.#installation-windows)** ]

**prerequisites**
[homebrew](https://brew.sh)
[rosetta2](https://support.apple.com/en-us/102527) : `sudo softwareupdate --install-rosetta`

1. Decide on a parent directory to keep all of your repos (I use `~/src`) and install there.

```
dots_dir = <repo-parent-dir-of-your-choice>/github.com/dfarrel1/dots
mkdir -p ${dots_dir} && cd ${dots_dir} && git clone https://github.com/dfarrel1/dots.git .
echo "source ${dots_dir}/profile/.profile" >> ~/.bashrc
echo "source ~/.bashrc" >> ~/.bash_profile
source ~/.bashrc
```

2. New Computer Script (Assumes 1Password exists)

```
./xtra/newcomp.sh
```

3. Add system python reqs

`pip install -r ${dots_dir}/xtra/python/global-reqs.txt`

4. Additional \(out of band\) installations

**[rust](https://www.rust-lang.org/tools/install)**

5. Open up a terminal and have fun!

>**[New computer script](../xtra/newcomp.sh)**

## Uninstall

To remove, you just need to take out the line you added in `~/.bashrc`

You can also delete the directory containing this repo.

## dotfile design pattern

`./profile/<category>.sh` files will include env, aliases, and functions for a scope of functionality. This modularity should make discoverability and management easier.

The following files are core dependencies:

- [.profile](./.profile)
- [core.sh](./core.sh)
- [navigation.sh](./navigation.sh)

Everything else is (and should remain) self-contained and independent of one another. That means you can start your own dotfiles repo by stripping down to those three files if you want to avoid the overhead of inspecting so many files.

## Installation [Windows]

Use [wsl](https://docs.microsoft.com/en-us/windows/wsl/install) *windows subsystem linux*. 

Install [homebrew]
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

>> **GOTCHA**: In a WSL Bash terminal, running `pwd` will return something like `/home/<user>` if you're in your home directory. That same directory literally translates to `\\wsl$\Ubuntu\home\<user>` in the Windows native directory addressing system.
