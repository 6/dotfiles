export ZSH=/Users/petergraham/.oh-my-zsh
# Set name of the theme to load ( ~/.oh-my-zsh/themes/ )
ZSH_THEME="robbyrussell"
export UPDATE_ZSH_DAYS=7

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
plugins=(git)

export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
eval "$(rbenv init -)"

export NVM_DIR=~/.nvm
. $(brew --prefix nvm)/nvm.sh

# LS after CD:
function chpwd() {
  ls -A
}

source $ZSH/oh-my-zsh.sh

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='vim'
fi

cat $HOME/.misc/ascii_totoro
