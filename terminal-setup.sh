#!/bin/bash

set -e

# Configuration
ORIGINAL_APP="/Applications/Ghostty.app"
NEW_APP="/Applications/CCode.app"
NEW_BUNDLE_ID="com.mitchellh.ccode"
NEW_APP_NAME="CCode"
CODE_CONFIG="$HOME/.config/ghostty/config-code"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🚀 Ghostty Duplicator Script"
echo "============================"

# Check if original Ghostty exists
if [ ! -d "$ORIGINAL_APP" ]; then
    echo -e "${RED}Error: Ghostty.app not found at $ORIGINAL_APP${NC}"
    exit 1
fi

# Check if duplicate already exists
if [ -d "$NEW_APP" ]; then
    echo -e "${YELLOW}⚠️  $NEW_APP already exists.${NC}"
    echo -e "${YELLOW}Please delete it using Finder (drag to Trash or right-click > Move to Trash)${NC}"
    echo -e "${YELLOW}Then run this script again.${NC}"
    echo ""
    exit 0
fi

echo "📋 Duplicating Ghostty.app..."
cp -R "$ORIGINAL_APP" "$NEW_APP"
echo -e "${GREEN}✓ Duplication complete${NC}"

# Update bundle identifier and name
echo "🔧 Updating bundle identifier..."
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $NEW_BUNDLE_ID" "$NEW_APP/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $NEW_BUNDLE_ID" "$NEW_APP/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleName '$NEW_APP_NAME'" "$NEW_APP/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleName string '$NEW_APP_NAME'" "$NEW_APP/Contents/Info.plist"

echo -e "${GREEN}✓ Bundle identifier updated${NC}"

# Modify the icon and rename it to bypass cache
echo "🎨 Creating custom colored icon..."

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null && ! command -v convert &> /dev/null; then
    echo -e "${YELLOW}⚠️  ImageMagick not found. Skipping icon modification.${NC}"
    echo -e "${YELLOW}   Install with: brew install imagemagick${NC}"
else
    ORIGINAL_ICNS="$NEW_APP/Contents/Resources/Ghostty.icns"
    NEW_ICNS="$NEW_APP/Contents/Resources/CCode.icns"

    if [ -f "$ORIGINAL_ICNS" ]; then
        echo "  Processing icon file..."

        # Create a temporary directory
        TEMP_DIR=$(mktemp -d)

        # Extract iconset from the original icns file
        iconutil -c iconset "$ORIGINAL_ICNS" -o "$TEMP_DIR/original.iconset" 2>/dev/null

        # Create new iconset directory
        mkdir -p "$TEMP_DIR/new.iconset"

        # Apply color transformation to each PNG in the iconset
        # Using HSL color space with hue=1.4 and saturation=1.2
        for png in "$TEMP_DIR/original.iconset"/*.png; do
            if [ -f "$png" ]; then
                filename=$(basename "$png")
                if command -v magick &> /dev/null; then
                    magick "$png" \
                        -colorspace HSL \
                        -channel R -evaluate multiply 1.4 \
                        -channel G -evaluate multiply 1.2 \
                        +channel \
                        -colorspace sRGB \
                        "$TEMP_DIR/new.iconset/$filename"
                else
                    convert "$png" \
                        -colorspace HSL \
                        -channel R -evaluate multiply 1.4 \
                        -channel G -evaluate multiply 1.2 \
                        +channel \
                        -colorspace sRGB \
                        "$TEMP_DIR/new.iconset/$filename"
                fi
            fi
        done

        # Convert iconset to new icns file with different name
        iconutil -c icns "$TEMP_DIR/new.iconset" -o "$NEW_ICNS"

        # Remove the original icon file
        rm "$ORIGINAL_ICNS"

        # CRITICAL: Remove CFBundleIconName so it doesn't use Assets.car
        /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$NEW_APP/Contents/Info.plist" 2>/dev/null || true

        # Update Info.plist to reference the new icon name
        /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile CCode" "$NEW_APP/Contents/Info.plist" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string CCode" "$NEW_APP/Contents/Info.plist"

        # Clean up
        rm -rf "$TEMP_DIR"

        echo -e "${GREEN}✓ Custom colored icon created${NC}"
    else
        echo -e "${YELLOW}⚠️  Icon file not found${NC}"
    fi
fi

# Create a compiled C wrapper
echo "🔧 Creating compiled wrapper..."

ORIGINAL_BINARY="$NEW_APP/Contents/MacOS/ghostty"
BACKUP_BINARY="$NEW_APP/Contents/MacOS/ghostty-original"

# Rename the original binary
if [ -f "$ORIGINAL_BINARY" ] && [ ! -f "$BACKUP_BINARY" ]; then
    mv "$ORIGINAL_BINARY" "$BACKUP_BINARY"
fi

# Create C wrapper source with environment variable
WRAPPER_SOURCE=$(mktemp).c
cat > "$WRAPPER_SOURCE" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libgen.h>
#include <sys/stat.h>
#include <limits.h>

int main(int argc, char *argv[]) {
    char exe_path[PATH_MAX];
    char dir_path[PATH_MAX];
    char binary_path[PATH_MAX];
    char config_path[PATH_MAX];
    char config_arg[PATH_MAX + 20];
    char *home = getenv("HOME");

    // Set environment variable to identify CCode terminal
    setenv("CCODE", "1", 1);

    // Get the full path of the current executable
    uint32_t size = sizeof(exe_path);
    if (_NSGetExecutablePath(exe_path, &size) != 0) {
        fprintf(stderr, "Failed to get executable path\n");
        return 1;
    }

    // Get directory of the executable
    strcpy(dir_path, exe_path);
    char *dir = dirname(dir_path);

    // Build path to original binary
    snprintf(binary_path, sizeof(binary_path), "%s/ghostty-original", dir);

    // Build path to config file
    snprintf(config_path, sizeof(config_path), "%s/.config/ghostty/config-code", home);

    // Check if config file exists
    struct stat st;
    if (stat(config_path, &st) == 0) {
        // Config exists, use it with --config-file=path format
        snprintf(config_arg, sizeof(config_arg), "--config-file=%s", config_path);

        char **new_argv = malloc(sizeof(char*) * (argc + 2));
        new_argv[0] = binary_path;
        new_argv[1] = config_arg;
        for (int i = 1; i < argc; i++) {
            new_argv[i + 1] = argv[i];
        }
        new_argv[argc + 1] = NULL;

        execv(binary_path, new_argv);
    } else {
        // Config doesn't exist, run normally
        argv[0] = binary_path;
        execv(binary_path, argv);
    }

    perror("execv failed");
    return 1;
}
EOF

# Compile the wrapper
clang -o "$ORIGINAL_BINARY" "$WRAPPER_SOURCE"
rm "$WRAPPER_SOURCE"

echo -e "${GREEN}✓ Compiled wrapper created${NC}"

# Remove the code signature (it's now invalid after our modifications)
echo "🔏 Re-signing application..."
codesign --force --deep --sign - "$NEW_APP" 2>&1 | grep -v "replacing existing signature" || true
echo -e "${GREEN}✓ Application re-signed${NC}"

# Clear any quarantine attributes
echo "🧹 Clearing quarantine attributes..."
xattr -cr "$NEW_APP" 2>/dev/null || true

# Touch the app to update modification time
touch "$NEW_APP"

# Clear icon cache and restart Dock
echo "🔄 Clearing icon cache and restarting Dock..."
rm -rf ~/Library/Caches/com.apple.iconservices.store 2>/dev/null || true

# Update modification time and register with Launch Services
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$NEW_APP"

# Restart Dock to refresh icons
killall Dock 2>/dev/null || true

echo ""
echo -e "${GREEN}✅ Done! CCode.app is ready.${NC}"
echo ""
echo "The app now has your chosen custom colored icon (hue-1.4-sat-1.2)."
echo "CCode sets CCODE=1 environment variable for prompt customization."
echo "CCode will use: $CODE_CONFIG (if it exists)"
echo ""
echo "Add this to your ~/.zshrc to customize the CCode prompt:"
echo ""
echo "if [[ -n \"\$CCODE\" ]]; then"
echo "  # Orange/yellow prompt for CCode"
echo "  PROMPT='%F{214}%n@%m%f %F{208}%~%f %F{214}\$%f '"
echo "fi"
