First, install Xcode along with command line tools and run `sudo xcode-select --switch /Applications/Xcode.app`

`rake install` to add symlinks to home directory, and `rake uninstall` to remove them.

# Font

Install [Meslo](https://github.com/andreberg/Meslo-Font)

# iTerm2

Point preferences to dotfiles directory:

<img width="462" alt="screen shot 2016-02-20 at 11 44 01 am" src="https://cloud.githubusercontent.com/assets/158675/13197838/5e528d0e-d7c7-11e5-8b52-3b4ab0401bdc.png">

Then quit and reopen iTerm.

# ZSH

Install [oh-my-zsh](https://github.com/robbyrussell/oh-my-zsh)

Install [p10k](https://github.com/romkatv/powerlevel10k#oh-my-zsh)

Install [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions/blob/master/INSTALL.md)

# Rbenv/Nodenv

set default globals:

```
rbenv install ...latest...
nodenv install ...latest...

rbenv global ...latest...
nodenv global ...latest...
```

# VS Code

Install the `Settings Sync` extension and run Cmd+Opt+D to sync from private gist.

# other software

Install brew. Then run:

```
brew install git postgres redis libyaml libffi cmake imagemagick graphviz ffmpeg node yarn libxml2

mkdir -p ~/Library/LaunchAgents

ln -sfv /opt/homebrew/opt/postgresql/*.plist ~/Library/LaunchAgents
ln -sfv /opt/homebrew/opt/redis/*.plist ~/Library/LaunchAgents

echo $UID => 501

launchctl enable gui/501/homebrew.mxcl.postgresql
launchctl kickstart -kp gui/501/homebrew.mxcl.postgresql

launchctl enable gui/501/homebrew.mxcl.redis.plist

createuser -s postgres

bundle config --global build.libxml-ruby --with-xml2-config="$(brew --prefix libxml2)/bin/xml2-config"
```

Also install fzf:

```
brew install fzf
$(brew --prefix)/opt/fzf/install
```

# clearing up disk space

```
yarn cache clean
xcrun simctl delete unavailable
```

OmniDiskSweeper: https://www.omnigroup.com/more/

Clear old iOS device support folders at `open ~/Library/Developer/Xcode/iOS\ DeviceSupport`

# Other

Go to https://github.com/settings/tokens/new and create a `repo` scope access token. Then run:

```
bundle config --global github.com [GITHUB_USERNAME]:[ACCESS_TOKEN]
```
