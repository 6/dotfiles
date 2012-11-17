Update bash to version 4 for autocd:

    brew install bash
    sudo bash -c "echo /usr/local/bin/bash >> /private/etc/shells"
    chsh -s /usr/local/bin/bash

`rake install` to add symlinks to home directory, and `rake uninstall` to remove them.
