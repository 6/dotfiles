# Installation

First, install Xcode along with command line tools (macOS only):
```sh
xcode-select --install
```

Then run the install script:
```sh
./install.sh
```

This will automatically symlink:
- All root-level dotfiles (`.zshrc`, `.gitconfig`, etc.) to your home directory
- Everything in `.config/` directory to `~/.config/` (auto-discovered)
- Specific subdirectories listed in the manifest (`.claude/commands`, `.claude/settings.json`)

The script supports both macOS and Linux. On Linux, it will use the Linux-specific configs from the `linux/` folder.

To remove all symlinks:
```sh
./install.sh uninstall
```

## Adding New Configs

**For XDG-compliant apps** (modern apps using `~/.config/`):
- Just create the directory/file in `dotfiles/.config/`
- Example: Add `dotfiles/.config/nvim/init.vim` → auto-symlinks to `~/.config/nvim/init.vim`
- No need to edit install.sh!

**For partial directory linking** (when you don't want to symlink an entire directory):
- Edit the `SUBDIR_LINKS` array in `install.sh`
- Example: `.claude/commands` is symlinked, but other files in `.claude/` are not

## Conflict Handling

If a file already exists at the target location, the installer will prompt you to:
- `[s]kip` - Skip this file
- `[S]kip all` - Skip all future conflicts
- `[o]verwrite` - Replace the existing file
- `[O]verwrite all` - Replace all future conflicts
- `[b]ackup` - Move existing file to `.backup` extension
- `[B]ackup all` - Backup all future conflicts

# Font

Install [Meslo](https://github.com/andreberg/Meslo-Font)

# Claude Code

Commands starting with `private-` are gitignored for sensitive/machine-specific commands.

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
