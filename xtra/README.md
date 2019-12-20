# xtra

## xplain

- Managing settings for IDEs and Applications
- Managing Mac OS brew installs

### Brewfile

- before brew you need `xcode-select --install`
- then `brew bundle --file=Brewfile`

### Notes

*zsh* issues -> switch to bash:

```
mv .zshrc .zshrc.bkup
chsh -s $(which bash)
ps -p $$
```