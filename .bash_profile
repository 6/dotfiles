PS1='\[\e[0;34m\]\w\[\e[m\] '

export PATH=/Applications/Postgres.app/Contents/MacOS/bin:$HOME/.rvm/bin:$HOME/bin:/usr/local/bin:$PATH
export EDITOR=vim
export GREP_OPTIONS='--color=auto'
export LESS='-iNR'
export PAGER=less

alias ..="cd .."
alias -- -="cd -"
alias ls="ls -aGp"
alias history='fc -l 1'

# `cd` just by typing folder name and hitting enter
shopt -s autocd

# Load RVM into a shell session *as a function*
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

command_exists () {
  type "$1" &> /dev/null ;
}

# Add more colors
if command_exists brew ; then
  source "`brew --prefix grc`/etc/grc.bashrc"
fi

cat $HOME/.misc/ascii_totoro
