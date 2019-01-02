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

# Atom

Install [Atom](https://atom.io/) and install the [package-sync](https://atom.io/packages/package-sync) package.

- Sync all packages with Cmd+Shift+P > `Package Sync: Sync`
- After installing a new package, update the list with Cmd+Shift+P > `Package Sync: Create Package List`

# Xcode

Install command line tools and headers:

```
xcode-select --install
open /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg
```
