export ZSH=/Users/petergraham/.oh-my-zsh
export UPDATE_ZSH_DAYS=30
export NVM_DIR=~/.nvm
export PATH="$HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
export EDITOR='vim'

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

alias a="atom ."
alias google='web_search google'
alias mp3="youtube-dl --add-metadata -x --extract-audio --audio-format mp3"

eval "$(rbenv init -)"
. $(brew --prefix nvm)/nvm.sh
source $ZSH/oh-my-zsh.sh

# Load machine-specific ZSH configuration (if present)
if [ -f ~/.zsh_custom ]; then
  source ~/.zsh_custom
fi

ASCII=("totoro" "beach" "stars") 
cat $HOME/.misc/ascii_$ASCII[$RANDOM%$#ASCII+1]
