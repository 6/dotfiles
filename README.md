On macOS:
- First, install Xcode along with command line tools and run `xcode-select --install`
- `rake install` to add symlinks to home directory, and `rake uninstall` to remove them.

On Linux:
- Run `./install_linux.sh`

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

# NVM

Install nvm without brew: https://github.com/nvm-sh/nvm?tab=readme-ov-file#installing-and-updating

# other software

Install brew. Then run:

```
brew install git postgresql@14 redis libyaml libffi cmake imagemagick graphviz ffmpeg yarn libxml2 ansible jq watchman cocoapods

brew tap facebook/fb
brew install idb-companion

mkdir -p ~/Library/LaunchAgents

# Note: replace `postgresql@14` with the version you installed:
ln -sfv /opt/homebrew/opt/postgresql@14/*.plist ~/Library/LaunchAgents
ln -sfv /opt/homebrew/opt/redis/*.plist ~/Library/LaunchAgents

echo $UID => 501

launchctl enable gui/501/homebrew.mxcl.postgresql
launchctl enable gui/501/homebrew.mxcl.redis.plist

brew services start postgresql@14
createuser -s postgres
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

If allowing Remote Login, add these in target computer's `/etc/ssh/sshd_config` to allow only public key authentication:

```
PasswordAuthentication no
ChallengeResponseAuthentication no
```

and then modify target computer's `~/.ssh/authorized_keys` to include the public key of the source computer.
