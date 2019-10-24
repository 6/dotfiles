First, install Xcode along with command line tools.

`rake install` to add symlinks to home directory, and `rake uninstall` to remove them.

# Font

Install [Meslo](https://github.com/andreberg/Meslo-Font)

# iTerm2

Point preferences to dotfiles directory:

<img width="462" alt="screen shot 2016-02-20 at 11 44 01 am" src="https://cloud.githubusercontent.com/assets/158675/13197838/5e528d0e-d7c7-11e5-8b52-3b4ab0401bdc.png">

Then quit and reopen iTerm.

# ZSH

Install [oh-my-zsh](https://github.com/robbyrussell/oh-my-zsh)

# Rbenv/Nodenv

set default globals:

```
rbenv install ...latest...
nodenv install ...latest...

rbenv global ...latest...
nodenv global ...latest...
```

# VS Code

Install the `Settings Sync` extension and run Cmd+Opt+D to sync from private gist.

# Other

Go to https://github.com/settings/tokens/new and create a `repo` scope access token. Then run:

```
bundle config --global github.com [GITHUB_USERNAME]:[ACCESS_TOKEN]
```
