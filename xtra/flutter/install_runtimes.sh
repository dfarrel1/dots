# Install the asdf plugins for dart, flutter and ruby
echo "installing dart plugin"
asdf install dart 2.7.0
echo "installing flutter plugin"
asdf install flutter 1.12.13+hotfix.7-stable 
echo "installing ruby plugin"
asdf install ruby 2.3.7


asdf global dart 2.7.0
asdf global flutter 1.12.13+hotfix.7-stable 
asdf global ruby 2.3.7 

# WIP
# https://dev.to/0xdonut/how-to-install-flutter-on-macos-using-homebrew-and-asdf-3loa