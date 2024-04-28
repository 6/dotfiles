# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
export UPDATE_ZSH_DAYS=30
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
export EDITOR='vim'
export GOPATH="$HOME/go"
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
export PATH="$PATH:$HOME/.cargo/bin"
export PATH="$PATH:$HOME/.local/bin"
export PATH=$PATH:/usr/local/go/bin
export ZSH_DISABLE_COMPFIX=true

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

function main() {
  # If main branch exists, use it, otherwise fall back to master:
  if git show-ref --quiet refs/heads/main; then
    git checkout main
  else
    git checkout master
  fi
}

alias gti='git'
alias igt='git'
alias gt='git'
alias mainp='main && git pull'
alias mainpd='mainp && git b -d @{-1}'

eval "$(rbenv init -)"
eval "$(pyenv init -)"
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

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
