# add some folders to the path
export PATH=/usr/local/Cellar/ctags/5.8/bin:$PATH

# color the prompt
autoload -U colors && colors
PS1="%{$fg[red]%}%~ %{$reset_color%}"

# history saves 50,000 in it if we want to open it
# only the last 1000 are part of backward searching
HISTFILE=~/.zshhistory
HISTSIZE=1000
SAVEHIST=50000

# share history across terminal sessions
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY

# ignore dupes 
setopt HIST_IGNORE_ALL_DUPS
setopt HISTVERIFY

# don't beep on ambiguous completion
setopt NO_LIST_BEEP

# spelling correction
setopt CORRECT

# just type in name of folder and hit enter, no 'cd' necessary
setopt AUTOCD

# ls colors
export CLICOLOR=1

# less case-insensitive search, colors, line numbers
export LESS='-iNR'

# output colored grep
export GREP_OPTIONS='--color=auto' 
export GREP_COLOR='7;31'

# Load RVM into a shell session *as a function*
[[ -s "$HOME/.rvm/scripts/rvm" ]] && . "$HOME/.rvm/scripts/rvm"  

# basic shortcuts
alias ..='cd ..'
alias -- -='cd -'
alias ls='ls -AF'

# show history
alias history='fc -l 1'

# software aliases
alias play='~/software/play-1.1.1/play'
alias java_dev_appserver='~/software/appengine-java-sdk/bin/dev_appserver.sh'
alias java_appcfg='~/software/appengine-java-sdk/bin/appcfg.sh'
alias start_pg="su - postgres -c '/usr/local/Cellar/postgresql/9.0.3/bin/pg_ctl start -D /usr/local/Cellar/postgresql/9.0.3/data'"
alias stop_pg="su - postgres -c '/usr/local/Cellar/postgresql/9.0.3/bin/pg_ctl stop -D /usr/local/Cellar/postgresql/9.0.3/data'"
alias redis-server="~/software/redis-2.2.6/src/redis-server"
alias redis-cli="~/software/redis-2.2.6/src/redis-cli"

# rails-specific
alias ss='script/server'

# make cd do an ls afterwards
function chpwd() {
    emulate -LR zsh
    ls
}

# welcome message
cat $HOME/.misc/ascii_totoro