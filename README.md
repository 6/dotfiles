# Installation

First, install Xcode along with command line tools (macOS only):
```sh
xcode-select --install
```

Then run the install script:
```sh
./install.sh
```

This will automatically discover and symlink:
- All root-level dotfiles (`.zshrc`, `.gitconfig`, `.gitignore`, etc.) to your home directory
- Everything in `.config/` to `~/.config/` (e.g., `.config/ghostty/` → `~/.config/ghostty/`)
- Contents of other dot directories (e.g., `.claude/commands/` → `~/.claude/commands/`, `.claude/settings.json` → `~/.claude/settings.json`)

**No manual configuration needed** - just add files to the repo and they're auto-symlinked!

The script supports both macOS and Linux. On Linux, it will use Linux-specific configs from the `linux/` folder.

To remove all symlinks:
```sh
./install.sh uninstall
```

## Adding New Configs

Everything is auto-discovered - just add files to the repo:

**XDG-compliant apps** (modern apps using `~/.config/`):
```bash
# Create config in .config/
mkdir -p dotfiles/.config/nvim
echo "set number" > dotfiles/.config/nvim/init.vim

# Run install - auto-discovered!
./install.sh
# Result: ~/.config/nvim/ → dotfiles/.config/nvim/
```

**Other dot directories** (partial directory linking):
```bash
# Add files/folders to any dot directory
mkdir -p dotfiles/.aws
echo "[default]" > dotfiles/.aws/config

# Run install - auto-discovered!
./install.sh
# Result: ~/.aws/config → dotfiles/.aws/config
```

**Global gitignore**:
- `.gitignore` in repo root → symlinked to `~/.gitignore` (global gitignore)

**Files are excluded automatically**:
- Gitignored files (like `.claude/settings.local.json`) won't be symlinked
- Script files (`install.sh`, `README.md`) won't be symlinked

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
