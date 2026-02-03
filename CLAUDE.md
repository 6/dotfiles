# Dotfiles

Personal dotfiles for macOS/Linux with automatic symlink management.

## Usage

```bash
./install.sh          # Install symlinks
./install.sh -f       # Force overwrite existing files
./install.sh uninstall
```

## Structure

- **Root dotfiles** (`.zshrc`, `.gitconfig`, etc) → symlinked to `~/`
- **`.config/` directories** → individual files symlinked (not whole directories) to prevent generated files from polluting the repo
- **`.claude/`, `.misc/`** → contents symlinked individually
- **`linux/`** → platform-specific overrides

## Key Config

- `EXCLUDE_PATTERNS` - files/dirs to skip
- `CONFIG_DIR_SYMLINKS` - `.config` dirs that need whole-directory symlinks (empty by default; file-level is safer)

## Adding New Configs

1. Add files to appropriate location in this repo
2. Run `./install.sh`

For `.config/` apps: only tracked files get symlinked, so generated files (caches, databases) stay local.
