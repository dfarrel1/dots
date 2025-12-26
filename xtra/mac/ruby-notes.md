# Ruby Problems

[**rbenv cheatsheet**](https://devhints.io/rbenv)

## FROM https://github.com/rbenv/rbenv/issues/938

[BUT DONT USE THE OLD 2.3.0 VERSION]

### "I'm not sure I installed rbenv and a ruby version correctly"
Yep, sure it can be tricky.

sudo xcode-select --install
Install rbenv with brew install rbenv
Add eval "$(rbenv init -)" to the end of ~/.zshrc or ~/.bash_profile
Install a ruby version rbenv install 2.3.0
Select a ruby version by rbenv rbenv global 2.3.0
Open a new terminal window
Verify that the right gem folder is being used with gem env home (should report something in your user folder not system wide)

### "I want to use bundler and rbenv together"
Perfect match!

Make sure you installed rbenv correctly ☝️
Select a ruby version locally for the folder you are located in e.g. rbenv local 2.3.0 (this creates a file called .ruby-version in the directory)
Verify that the right gem folder is being used with gem env home (should report something in your user folder not system wide)
Run gem install bundler
Run bundle install
Run on of your favorite gems defined in the Gemfile by bundle exec ... e.g. bundle exec fastlane

### "I want to install a gem on user for a specific version of ruby"
Nice, rbenv is your friend.

Make sure you installed rbenv correctly ☝️
Select a ruby version globally by e.g. rbenv global 2.3.0 or even better locally for the folder you are located in e.g. rbenv local 2.3.0
Run gem install ...

### "I want to install a gem globally on my system ruby"
Then why are you using rbenv? Okay, if you decide this is the right option for you then go ahead with sudo gem install ...
