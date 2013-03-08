Update bash to version 4 for autocd:

    brew install bash
    sudo bash -c "echo /usr/local/bin/bash >> /private/etc/shells"
    chsh -s /usr/local/bin/bash

Add some fancy colors to command output:

    brew install grc

Bash and Git completion, including Git branch in PS1:

    brew install git bash-completion

If you have RVM installed, the following will enable `ls` after `cd`:

    echo "ls" >> ~/.rvm/hooks/after_cd
    rvm reload

Install [vundle](https://github.com/gmarik/vundle) for vim package management.

`rake install` to add symlinks to home directory, and `rake uninstall` to remove them.
