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

# Directories and files to exclude from symlinking
EXCLUDE_PATTERNS=(
    ".DS_Store"
    ".git"
    "settings.local.json"
    "README.md"
    "install.sh"
    "linux"
)

# Conflict resolution state
SKIP_ALL=false
OVERWRITE_ALL=false
BACKUP_ALL=false

# Parse flags
FORCE=false
while [[ "$1" == -* ]]; do
    case "$1" in
        -f|--force)
            FORCE=true
            OVERWRITE_ALL=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Function to check if file should be excluded
should_exclude() {
    local file="$1"
    for exclude in "${EXCLUDE_PATTERNS[@]}"; do
        # Use exact match to avoid false positives (e.g., .gitconfig matching .git)
        if [[ "$file" == "$exclude" ]]; then
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

# Function to get source directory (same for all platforms now that configs are consolidated)
get_source_dir() {
    echo "$DOTFILES_DIR"
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
        if [[ -d "$file" ]]; then
            continue
        fi

        # Check for platform-specific override in linux/ directory
        local source_file="$file"
        if [[ "$PLATFORM" == "linux" ]] && [[ -f "$DOTFILES_DIR/linux/$filename" ]]; then
            source_file="$DOTFILES_DIR/linux/$filename"
            echo -e "${BLUE}Using Linux override:${NC} $filename"
        fi

        local target="$HOME/$filename"
        create_symlink "$source_file" "$target"
    done

    # 2. Symlink .misc directory as a whole (legacy behavior)
    if [[ -d "$DOTFILES_DIR/.misc" ]]; then
        echo -e "\n${BLUE}Installing .misc directory...${NC}"
        create_symlink "$DOTFILES_DIR/.misc" "$HOME/.misc"
    fi

    # 3. Auto-discover and symlink .config directory contents
    if [[ -d "$DOTFILES_DIR/.config" ]]; then
        echo -e "\n${BLUE}Installing .config directory contents...${NC}"

        # Use find to get all files and directories in .config, preserving structure
        while IFS= read -r -d '' item; do
            # Get relative path from .config directory
            local rel_path="${item#$DOTFILES_DIR/.config/}"

            # Skip the .config directory itself
            [[ "$rel_path" == "" ]] && continue

            local source="$item"
            local target="$HOME/.config/$rel_path"

            # Only symlink top-level items in .config (let subdirectories be handled by their parent symlinks)
            # This prevents creating individual symlinks for every file when we can symlink the directory
            if [[ "$rel_path" != */* ]]; then
                create_symlink "$source" "$target"
            fi
        done < <(find "$DOTFILES_DIR/.config" -mindepth 1 -maxdepth 1 -print0)
    fi

    # 4. Auto-discover and symlink other dot directories (like .claude/)
    # These are directories where we want to symlink contents, not the directory itself
    echo -e "\n${BLUE}Installing other dot directory contents...${NC}"
    for dir in "$DOTFILES_DIR"/.[^.]*; do
        [[ -d "$dir" ]] || continue

        local dirname=$(basename "$dir")

        # Skip if in exclude list
        if should_exclude "$dirname"; then
            continue
        fi

        # Skip directories we've already handled
        if [[ "$dirname" == ".misc" ]] || [[ "$dirname" == ".config" ]]; then
            continue
        fi

        # Symlink top-level items within this directory
        for item in "$dir"/*; do
            [[ -e "$item" ]] || continue

            local itemname=$(basename "$item")

            # Skip if in exclude list
            if should_exclude "$itemname"; then
                continue
            fi

            local source="$item"
            local target="$HOME/$dirname/$itemname"

            create_symlink "$source" "$target"
        done
    done

    # Post-install: trust mise config if mise is installed
    if command -v mise &> /dev/null && [[ -d "$DOTFILES_DIR/.config/mise" ]]; then
        echo -e "\n${BLUE}Trusting mise config...${NC}"
        mise trust "$DOTFILES_DIR/.config/mise/config.toml" 2>/dev/null || true
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

    # Remove .config directory symlinks
    if [[ -d "$DOTFILES_DIR/.config" ]]; then
        while IFS= read -r -d '' item; do
            local rel_path="${item#$DOTFILES_DIR/.config/}"
            [[ "$rel_path" == "" ]] && continue

            local target="$HOME/.config/$rel_path"

            # Only check top-level items
            if [[ "$rel_path" != */* ]]; then
                if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$item" ]]; then
                    rm "$target"
                    echo -e "${GREEN}Removed:${NC} $target"
                fi
            fi
        done < <(find "$DOTFILES_DIR/.config" -mindepth 1 -maxdepth 1 -print0)
    fi

    # Remove other dot directory symlinks
    for dir in "$DOTFILES_DIR"/.[^.]*; do
        [[ -d "$dir" ]] || continue

        local dirname=$(basename "$dir")

        # Skip if in exclude list
        if should_exclude "$dirname"; then
            continue
        fi

        # Skip directories we've already handled
        if [[ "$dirname" == ".misc" ]] || [[ "$dirname" == ".config" ]]; then
            continue
        fi

        # Remove top-level item symlinks within this directory
        for item in "$dir"/*; do
            [[ -e "$item" ]] || continue

            local itemname=$(basename "$item")

            # Skip if in exclude list
            if should_exclude "$itemname"; then
                continue
            fi

            local target="$HOME/$dirname/$itemname"

            if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$item" ]]; then
                rm "$target"
                echo -e "${GREEN}Removed:${NC} $target"
            fi
        done
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
        echo "Usage: $0 [-f|--force] {install|uninstall}"
        exit 1
        ;;
esac
