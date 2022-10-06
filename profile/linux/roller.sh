xargs apt-get install < ./apt-list

# install pyenv
curl https://pyenv.run | bash

# install bash-git-prompt
git clone https://github.com/magicmonty/bash-git-prompt.git ~/.bash-git-prompt --depth=1

#asdf manual install
# moved to brew install
# git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.10.2

#install homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"


echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc

#brew install asdf
brew install asdf

echo '. /home/linuxbrew/.linuxbrew/opt/asdf/libexec/asdf.sh' >> ~/.bashrc


# add smartgit
# https://www.syntevo.com/smartgit/download/#installation-instructions
# deb doesn't seem to be working
# wget https://www.syntevo.com/downloads/smartgit/smartgit-21_2_4.deb
# sudo apt install ./smartgit-21_2_4.deb

wget https://www.syntevo.com/downloads/smartgit/smartgit-linux-21_2_4.tar.gz
tar xzf smartgit-linux-21_2_4.tar.gz -C ~/src/
# start smartgit from cli
# ~/src/smartgit/bin/smartgit.sh

#chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb

# disable middle button on trackpad
sudo add-apt-repository universe
sudo apt install gnome-tweak-tool -y
gnome-tweaks
# make changes in UI
