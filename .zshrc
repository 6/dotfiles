# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Couple of critical exports first:
export PATH="$HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="$PATH:/opt/homebrew/bin"

# Set homebrew env vars like $HOMEBREW_PREFIX
eval "$(brew shellenv)"

export ZSH="$HOME/.oh-my-zsh"
export UPDATE_ZSH_DAYS=30
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
export PATH="$HOME/Library/Android/sdk/platform-tools:$HOME/Library/Android/sdk/tools:$PATH"
export PATH="/Applications/Genymotion.app/Contents/MacOS/tools/:$PATH"
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
export PATH="$HOMEBREW_PREFIX/opt/openssl@1.1/bin:$PATH"
export EDITOR='vim'
export GOPATH="$HOME/go"
export PATH="$HOME/flutter/bin:$PATH"
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$HOME/.jenv/bin:$PATH"
export PATH="$PYENV_ROOT/bin:$PATH"
export PATH="$PATH:$HOME/.foundry/bin"
export PATH="$PATH:$HOME/.cargo/bin"
export PATH="$PATH:$HOME/.local/bin"
export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$HOMEBREW_PREFIX/opt/openssl@1.1"
export PATH=$PATH:/usr/local/go/bin
export ZSH_DISABLE_COMPFIX=true

export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_AVD_HOME="$HOME/.android/avd"

export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools

# ARM/M1 libs:
export CPATH="$HOMEBREW_PREFIX/include"
export LIBRARY_PATH="$HOMEBREW_PREFIX/lib"

# For ruby/fastlane:
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Set name of the theme to load ( ~/.oh-my-zsh/themes/ )
ZSH_THEME="powerlevel10k/powerlevel10k"

# Disable autosuggest for large buffers
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_USE_ASYNC=true

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
plugins=(bundler git git-extras gitfast zsh-autosuggestions)

function screenshot() {
  local seconds=0
  if [[ $1 ]]; then seconds=$1; fi
  screencapture -x -T $seconds -t png ~/Desktop/screenshot-$(date +"%Y-%m-%d-%H-%M-%S").png
}

# Useful if you have to force-shutdown and leave Postgres in a weird state.
function fixpg() {
  rm -f /usr/local/var/postgres/postmaster.pid
  brew services restart postgresql
  echo 'If still not working, try running `pg_ctl -D /usr/local/var/postgres start` to see full output.'
  echo 'or on M1: `pg_ctl -D /opt/homebrew/var/postgres start`'
}

# When OS X camera stops working occasionally.
function fixcamera {
  sudo killall VDCAssistant
}

# Fix LoL config file (gets overwritten sometimes).
function fixlol() {
  cp ~/.misc/PersistedSettings.json "/Applications/League of Legends.app/Contents/LoL/Config/PersistedSettings.json"
}

function spec() {
  test -e package.json && grep -q '"test":' package.json && yarn test $1
  test -e .rspec && bundle exec rspec $1
}

function main() {
  # If main branch exists, use it, otherwise fall back to master:
  if git show-ref --quiet refs/heads/main; then
    git checkout main
  else
    git checkout master
  fi
}

function pastesim() {
  local textToPaste=$1
  if [ -z "$textToPaste" ]; then
    echo 'Usage: pastesim "Text to paste"'
    return
  fi

  # Grab the udid of the first booted simulator:
  local booted=`idb list-targets | grep "Booted" | grep -Eio "[0-9a-f]{8}-[-0-9a-f]+" | head -1`
  if [ -z "$booted" ]; then
    echo "No iOS Simulator currently booted!"
  else
    echo "Pasting text to iOS simulator ($booted)"
    idb ui text "$textToPaste" --udid "$booted"
  fi
}

alias fixdns='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'
alias a="code ."
alias mp3="youtube-dl --add-metadata -x --extract-audio --audio-format mp3"
alias most="du -hs * | gsort -rh | head -10"
alias gti='git'
alias igt='git'
alias gt='git'
alias mainp='main && git pull'
alias mainpd='mainp && git b -d @{-1}'
alias canary="/Applications/Google\ Chrome\ Canary.app/Contents/MacOS/Google\ Chrome\ Canary --remote-debugging-port=9222"
alias canaryh="echo 'Starting canary in headless mode.\nPress Ctrl+C to exit.' && canary --disable-gpu --headless"
alias ap='osascript ~/.misc/airpods.applescript'

eval "$(rbenv init -)"
eval "$(pyenv init -)"
eval "$(jenv init -)"
eval "$(direnv hook zsh)"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export GVM_DIR="$HOME/.gvm"
[[ -s "$GVM_DIR/scripts/gvm" ]] && source "$GVM_DIR/scripts/gvm"

source $ZSH/oh-my-zsh.sh

# Load machine-specific ZSH configuration (if present)
if [ -f $HOME/.zsh_custom ]; then
  source "$HOME/.zsh_custom"
fi

if [ -f ~/google-cloud-sdk/completion.zsh.inc ]; then
  source ~/google-cloud-sdk/completion.zsh.inc
  source ~/google-cloud-sdk/path.zsh.inc
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# heroku autocomplete setup
HEROKU_AC_ZSH_SETUP_PATH="$HOME/Library/Caches/heroku/autocomplete/zsh_setup" && test -f $HEROKU_AC_ZSH_SETUP_PATH && source $HEROKU_AC_ZSH_SETUP_PATH;

ASCII=("totoro" "beach" "stars")
cat $HOME/.misc/ascii_$ASCII[$RANDOM%$#ASCII+1]
