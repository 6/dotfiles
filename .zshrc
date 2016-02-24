export ZSH=/Users/petergraham/.oh-my-zsh
export UPDATE_ZSH_DAYS=7
export NVM_DIR=~/.nvm
export PATH="$HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='vim'
fi

# Set name of the theme to load ( ~/.oh-my-zsh/themes/ )
ZSH_THEME="robbyrussell"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
plugins=(bundler git)

function web_search() {
  emulate -L zsh
  url="https://www.google.com/search?q=${(j:+:)@[2,-1]}"
  open_command "$url"
}

alias google='web_search google'
alias youtube-mp3="youtube-dl --extract-audio --audio-format mp3"

eval "$(rbenv init -)"
. $(brew --prefix nvm)/nvm.sh
source $ZSH/oh-my-zsh.sh
cat $HOME/.misc/ascii_totoro
