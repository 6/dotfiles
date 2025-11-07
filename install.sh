#!/usr/bin/env bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Dotfiles directory
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Detect platform
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
else
    echo -e "${RED}Unsupported platform: $OSTYPE${NC}"
    exit 1
fi

echo -e "${BLUE}Detected platform: $PLATFORM${NC}"

# Configuration: XDG config symlinks
# Format: "target_dir:source_path:filename"
# Creates: ~/.config/$target_dir/$filename -> $DOTFILES_DIR/$source_path
XDG_CONFIGS=(
    "ghostty:.misc/ghostty:config"
)

# Configuration: Subdirectory/file symlinks
# Format: "target_path:source_path"
# Creates: ~/$target_path -> $DOTFILES_DIR/$source_path
SUBDIR_LINKS=(
    ".claude/commands:.claude/commands"
    ".claude/settings.json:.claude/settings.json"
)

# Files to exclude from root-level dotfile symlinking
EXCLUDE_FILES=(
    ".DS_Store"
    ".git"
    ".gitignore"
    "settings.local.json"
)

# Conflict resolution state
SKIP_ALL=false
OVERWRITE_ALL=false
BACKUP_ALL=false

# Function to check if file should be excluded
should_exclude() {
    local file="$1"
    for exclude in "${EXCLUDE_FILES[@]}"; do
        if [[ "$file" == *"$exclude"* ]]; then
            return 0
        fi
    done
    return 1
}

# Function to handle conflicts
handle_conflict() {
    local target="$1"
    local source="$2"

    # Check global flags first
    if $SKIP_ALL; then
        echo -e "${YELLOW}Skipping${NC} $target"
        return 1
    fi

    if $OVERWRITE_ALL; then
        rm -rf "$target"
        return 0
    fi

    if $BACKUP_ALL; then
        mv "$target" "${target}.backup"
        echo -e "${GREEN}Backed up${NC} $target to ${target}.backup"
        return 0
    fi

    # Ask user
    echo -e "${YELLOW}File exists:${NC} $target"
    echo -e "  Target: $target"
    echo -e "  Source: $source"

    while true; do
        read -p "Action? [s]kip, [S]kip all, [o]verwrite, [O]verwrite all, [b]ackup, [B]ackup all: " choice
        case "$choice" in
            s)
                echo -e "${YELLOW}Skipping${NC} $target"
                return 1
                ;;
            S)
                SKIP_ALL=true
                echo -e "${YELLOW}Skipping${NC} $target (and all future conflicts)"
                return 1
                ;;
            o)
                rm -rf "$target"
                return 0
                ;;
            O)
                OVERWRITE_ALL=true
                rm -rf "$target"
                return 0
                ;;
            b)
                mv "$target" "${target}.backup"
                echo -e "${GREEN}Backed up${NC} $target to ${target}.backup"
                return 0
                ;;
            B)
                BACKUP_ALL=true
                mv "$target" "${target}.backup"
                echo -e "${GREEN}Backed up${NC} $target to ${target}.backup"
                return 0
                ;;
            *)
                echo "Invalid choice. Please try again."
                ;;
        esac
    done
}

# Function to create symlink with conflict handling
create_symlink() {
    local source="$1"
    local target="$2"

    # Check if source exists
    if [[ ! -e "$source" ]]; then
        echo -e "${RED}Source does not exist:${NC} $source"
        return 1
    fi

    # If target already exists and is not a symlink, or is a symlink to different location
    if [[ -e "$target" ]] || [[ -L "$target" ]]; then
        if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$source" ]]; then
            echo -e "${GREEN}Already linked:${NC} $target"
            return 0
        fi

        if ! handle_conflict "$target" "$source"; then
            return 1
        fi
    fi

    # Create parent directory if needed
    local parent_dir="$(dirname "$target")"
    if [[ ! -d "$parent_dir" ]]; then
        mkdir -p "$parent_dir"
        echo -e "${BLUE}Created directory:${NC} $parent_dir"
    fi

    # Create symlink
    ln -s "$source" "$target"
    echo -e "${GREEN}Linked:${NC} $target -> $source"
}

# Function to get source directory based on platform
get_source_dir() {
    if [[ "$PLATFORM" == "linux" ]] && [[ -d "$DOTFILES_DIR/linux" ]]; then
        echo "$DOTFILES_DIR/linux"
    else
        echo "$DOTFILES_DIR"
    fi
}

# Main installation function
install_dotfiles() {
    echo -e "\n${BLUE}=== Installing Dotfiles ===${NC}\n"

    local source_dir=$(get_source_dir)

    # 1. Symlink root-level dotfiles
    echo -e "${BLUE}Installing root-level dotfiles...${NC}"
    for file in "$source_dir"/.[^.]*; do
        [[ -e "$file" ]] || continue

        local filename=$(basename "$file")

        # Skip if in exclude list
        if should_exclude "$filename"; then
            continue
        fi

        # Skip directories (we handle them separately)
        if [[ "$filename" == ".misc" ]] || [[ "$filename" == ".claude" ]] || [[ "$filename" == ".config" ]]; then
            continue
        fi

        local target="$HOME/$filename"
        create_symlink "$file" "$target"
    done

    # 2. Symlink .misc directory as a whole (legacy behavior)
    if [[ -d "$DOTFILES_DIR/.misc" ]]; then
        echo -e "\n${BLUE}Installing .misc directory...${NC}"
        create_symlink "$DOTFILES_DIR/.misc" "$HOME/.misc"
    fi

    # 3. Symlink XDG config files
    if [[ ${#XDG_CONFIGS[@]} -gt 0 ]]; then
        echo -e "\n${BLUE}Installing XDG config files...${NC}"
        for config in "${XDG_CONFIGS[@]}"; do
            IFS=':' read -r target_dir source_path filename <<< "$config"

            local source="$DOTFILES_DIR/$source_path"
            local target="$HOME/.config/$target_dir/$filename"

            create_symlink "$source" "$target"
        done
    fi

    # 4. Symlink subdirectories and specific files
    if [[ ${#SUBDIR_LINKS[@]} -gt 0 ]]; then
        echo -e "\n${BLUE}Installing subdirectory links...${NC}"
        for link in "${SUBDIR_LINKS[@]}"; do
            IFS=':' read -r target_path source_path <<< "$link"

            local source="$DOTFILES_DIR/$source_path"
            local target="$HOME/$target_path"

            create_symlink "$source" "$target"
        done
    fi

    echo -e "\n${GREEN}=== Installation Complete! ===${NC}\n"
}

# Uninstall function
uninstall_dotfiles() {
    echo -e "\n${BLUE}=== Uninstalling Dotfiles ===${NC}\n"

    local source_dir=$(get_source_dir)

    # Remove root-level dotfile symlinks
    for file in "$source_dir"/.[^.]*; do
        [[ -e "$file" ]] || continue

        local filename=$(basename "$file")

        if should_exclude "$filename"; then
            continue
        fi

        local target="$HOME/$filename"

        if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$file" ]]; then
            rm "$target"
            echo -e "${GREEN}Removed:${NC} $target"
        fi
    done

    # Remove .misc symlink
    if [[ -L "$HOME/.misc" ]]; then
        rm "$HOME/.misc"
        echo -e "${GREEN}Removed:${NC} $HOME/.misc"
    fi

    # Remove XDG config symlinks
    for config in "${XDG_CONFIGS[@]}"; do
        IFS=':' read -r target_dir source_path filename <<< "$config"
        local target="$HOME/.config/$target_dir/$filename"

        if [[ -L "$target" ]]; then
            rm "$target"
            echo -e "${GREEN}Removed:${NC} $target"
        fi
    done

    # Remove subdirectory symlinks
    for link in "${SUBDIR_LINKS[@]}"; do
        IFS=':' read -r target_path source_path <<< "$link"
        local target="$HOME/$target_path"

        if [[ -L "$target" ]]; then
            rm "$target"
            echo -e "${GREEN}Removed:${NC} $target"
        fi
    done

    echo -e "\n${GREEN}=== Uninstallation Complete! ===${NC}\n"
}

# Main script
case "${1:-install}" in
    install)
        install_dotfiles
        ;;
    uninstall)
        uninstall_dotfiles
        ;;
    *)
        echo "Usage: $0 {install|uninstall}"
        exit 1
        ;;
esac
