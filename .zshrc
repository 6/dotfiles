export ZSH="$HOME/.oh-my-zsh"
export UPDATE_ZSH_DAYS=30
export PATH="$HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
export PATH="$HOME/Library/Android/sdk/platform-tools:$HOME/Library/Android/sdk/tools:$PATH"
export PATH="$PATH:`yarn global bin`"
export PATH="$HOME/.nodenv/shims:$PATH"
export EDITOR='vim'
export GOPATH="$HOME/go"
export PHANTOMJS_BIN=/usr/local/bin/phantomjs

# Set name of the theme to load ( ~/.oh-my-zsh/themes/ )
ZSH_THEME="robbyrussell"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
plugins=(bundler git git-extras)

function web_search() {
  emulate -L zsh
  url="https://www.google.com/search?q=${(j:+:)@[2,-1]}"
  open_command "$url"
}

function screenshot() {
  local seconds=0
  if [[ $1 ]]; then seconds=$1; fi
  screencapture -x -T $seconds -t png ~/Desktop/screenshot-$(date +"%Y-%m-%d-%H-%M-%S").png
}

function mp3ltrim() {
  local seconds=$1
  local file=$2
  ffmpeg -ss $seconds -i $file -acodec copy $file-ltrim.mp3
}

# Usage: calc "123.5 + 345"
function calc() {
  bc -l <<< "$@"
}

# Useful if you have to force-shutdown and leave Postgres in a weird state.
function fixpg() {
  rm -f /usr/local/var/postgres/postmaster.pid
  brew services restart postgresql
}

# When OS X camera stops working occasionally.
function fixcamera {
  sudo killall VDCAssistant
}

# Fix LoL config file (gets overwritten sometimes).
function fixlol() {
  cp ~/.misc/PersistedSettings.json "/Applications/League of Legends.app/Contents/LoL/Config/PersistedSettings.json"
}

alias a="atom ."
alias google='web_search google'
alias mp3="youtube-dl --add-metadata -x --extract-audio --audio-format mp3"
alias vid="youtube-dl"
alias vidsub="youtube-dl --write-srt --sub-lang en"
alias most="du -hs * | gsort -rh | head -10"
alias gti='git'
alias igt='git'
alias gt='git'

eval "$(rbenv init -)"
eval "$(nodenv init -)"

source $ZSH/oh-my-zsh.sh

# Load machine-specific ZSH configuration (if present)
if [ -f ~/.zsh_custom ]; then
  source ~/.zsh_custom
fi

ASCII=("totoro" "beach" "stars")
cat $HOME/.misc/ascii_$ASCII[$RANDOM%$#ASCII+1]
