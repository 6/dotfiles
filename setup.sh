#!/bin/sh

curl -fsSL 'https://raw.githubusercontent.com/Homebrew/install/master/install' | ruby
brew update

brew install git postgresql redis awscli
brew install n rbenv ruby-build
brew install openssl libyaml libffi
brew install ffmpeg youtube-dl graphviz wget

mkdir -p ~/Library/LaunchAgents

# Start redis on launch
ln -sfv /usr/local/opt/redis/*.plist ~/Library/LaunchAgents
launchctl load ~/Library/LaunchAgents/homebrew.mxcl.redis.plist

# Start postgresql on launch
ln -sfv /usr/local/opt/postgresql/*.plist ~/Library/LaunchAgents
launchctl load ~/Library/LaunchAgents/homebrew.mxcl.postgresql.plist

# Non-critical software
brew install cask
brew cask install spectacle qlvideo
