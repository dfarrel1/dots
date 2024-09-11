# xtra

## overview

- Managing settings for IDEs and Applications
  - Intellij Idea
  - VSCode
  - Sublime
  - SourceTree
- Managing Mac OS brew installs

## newcomp.sh

>NOTE: the newcomp.sh script adds an auto-tether behavior. 

### IDEs

IDE settings

### mac

notes about customizing MacOS

### python

global system python reqs

### Brewfile

- before brew you need `xcode-select --install`
- `./newcomp.sh`
- `brew bundle --file=Brewfile`

### Notes

*zsh* issues -> switch to bash:

```
mv .zshrc .zshrc.bkup
chsh -s $(which bash)
ps -p $$
```

** show .files **
```
defaults write com.apple.Finder AppleShowAllFiles true
```

```
killall Finder
```

### Unmanaged Add-ons

[balena-etcher](https://etcher.balena.io/#download-etcher)  
[raindrop](https://raindrop.io/download)


