export ZSH=/Users/petergraham/.oh-my-zsh
export UPDATE_ZSH_DAYS=30
export NVM_DIR="$HOME/.nvm"
export PATH="$HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
export PATH="$HOME/Library/Android/sdk/platform-tools:$HOME/Library/Android/sdk/tools:$PATH"
export EDITOR='vim'
export GOPATH="$HOME/go"

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

alias a="atom ."
alias google='web_search google'
alias mp3="youtube-dl --add-metadata -x --extract-audio --audio-format mp3"
alias vid="youtube-dl"
alias most="du -hs * | gsort -rh | head -10"

eval "$(rbenv init -)"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh" # load nvm
[[ -s "$HOME/.avn/bin/avn.sh" ]] && source "$HOME/.avn/bin/avn.sh" # load avn
source $ZSH/oh-my-zsh.sh

# Load machine-specific ZSH configuration (if present)
if [ -f ~/.zsh_custom ]; then
  source ~/.zsh_custom
fi

ASCII=("totoro" "beach" "stars")
cat $HOME/.misc/ascii_$ASCII[$RANDOM%$#ASCII+1]
