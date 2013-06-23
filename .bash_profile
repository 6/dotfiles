PS1='\[\e[0;34m\]\w\[\e[m\] '

export PATH=/Applications/Postgres.app/Contents/MacOS/bin:$HOME/.rvm/bin:$HOME/bin:/usr/local/bin:$PATH
export EDITOR=vim
export GREP_OPTIONS='--color=auto'
export LESS='-iNR'
export PAGER=less
export GIT_PS1_SHOWDIRTYSTATE=1

alias ..="cd .."
alias -- -="cd -"
if [[ `uname` == 'Linux' ]] ; then
  alias ls="ls -ap --color=auto"
else
  alias ls="ls -aGp"
fi
alias history='fc -l 1'

# `cd` just by typing folder name and hitting enter
shopt -s autocd

# Load RVM into a shell session *as a function*
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

command_exists () {
  type "$1" &> /dev/null ;
}

# Add more colors and git branch
if command_exists brew ; then
  source "`brew --prefix grc`/etc/grc.bashrc"
  if [ -f `brew --prefix`/etc/bash_completion.d/git-prompt.sh ]; then
    source `brew --prefix`/etc/bash_completion.d/git-prompt.sh
    PS1='\[\e[0;34m\]\w\[\e[m\] \[\033[31m\]$(__git_ps1 "%s ")\[\033[00m\]'
  fi
fi

source $HOME/dotfiles/z.sh
cat $HOME/.misc/ascii_totoro
