#!/bin/sh

# For each dotfile in /linux/, create a symlink in $HOME
# If a file already exists, ask user if they want to overwrite it.
DOTFILES=$(find linux -type f -name '.*')
for dotfile in $DOTFILES; do
  filename=$(basename $dotfile)
  if [ -f "$HOME/$filename" ]; then
    echo "File already exists: $HOME/$filename"
    read -p "Overwrite? (y/n) " overwrite
    echo
    if [ "$overwrite" = "y" ]; then
      ln -sfv "$PWD/$dotfile" "$HOME/$filename"
    fi
  else
    ln -sfv "$PWD/$dotfile" "$HOME/$filename"
  fi
done
