#!/bin/bash

set -e

# Configuration
ORIGINAL_APP="/Applications/Ghostty.app"
NEW_APP="/Applications/Ghostty Code.app"
NEW_BUNDLE_ID="com.mitchellh.ghostty.code"
NEW_APP_NAME="Ghostty Code"
OUTPUT_ICON="$HOME/Desktop/ghostty_code_icon.png"
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

# Create a compiled C wrapper
echo "🔧 Creating compiled wrapper..."

ORIGINAL_BINARY="$NEW_APP/Contents/MacOS/ghostty"
BACKUP_BINARY="$NEW_APP/Contents/MacOS/ghostty-original"

# Rename the original binary
if [ -f "$ORIGINAL_BINARY" ] && [ ! -f "$BACKUP_BINARY" ]; then
    mv "$ORIGINAL_BINARY" "$BACKUP_BINARY"
fi

# Create C wrapper source - using --config-file=path format
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

# Create an orange-tinted icon PNG for manual application
echo "🎨 Creating orange-tinted icon PNG..."

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null && ! command -v convert &> /dev/null; then
    echo -e "${YELLOW}⚠️  ImageMagick not found. Cannot create custom icon.${NC}"
    echo -e "${YELLOW}   Install with: brew install imagemagick${NC}"
    SKIP_ICON=true
else
    ICNS_FILE="$ORIGINAL_APP/Contents/Resources/Ghostty.icns"

    if [ -f "$ICNS_FILE" ]; then
        # Convert to PNG first
        sips -s format png "$ICNS_FILE" --out /tmp/ghostty_temp.png &>/dev/null

        # Apply orange tint
        if command -v magick &> /dev/null; then
            magick /tmp/ghostty_temp.png -modulate 100,140,60 \
                "$OUTPUT_ICON"
        else
            convert /tmp/ghostty_temp.png -modulate 100,140,60 \
                "$OUTPUT_ICON"
        fi

        rm /tmp/ghostty_temp.png
        echo -e "${GREEN}✓ Orange icon saved to: $OUTPUT_ICON${NC}"
        SKIP_ICON=false
    else
        echo -e "${YELLOW}⚠️  Original icon not found${NC}"
        SKIP_ICON=true
    fi
fi

# Remove the code signature (it's now invalid after our modifications)
echo "🔏 Re-signing application..."
codesign --force --deep --sign - "$NEW_APP" 2>&1 | grep -v "replacing existing signature" || true
echo -e "${GREEN}✓ Application re-signed${NC}"

# Clear any quarantine attributes
echo "🧹 Clearing quarantine attributes..."
xattr -cr "$NEW_APP" 2>/dev/null || true

# Update modification time and register with Launch Services
echo "🔄 Registering with Launch Services..."
touch "$NEW_APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$NEW_APP"

echo ""
echo -e "${GREEN}✅ Done! Ghostty Code.app is ready.${NC}"
echo ""

if [ "$SKIP_ICON" = false ]; then
    echo -e "${YELLOW}📝 MANUAL ICON SETUP:${NC}"
    echo ""
    echo "1. Open Finder and navigate to /Applications"
    echo "2. Right-click 'Ghostty Code.app' and select 'Get Info' (or press Cmd+I)"
    echo "3. Click the icon in the top-left corner of the Get Info window"
    echo "4. Open the generated icon: $OUTPUT_ICON"
    echo "5. Copy it (Cmd+C), go back to Get Info, click the icon, and paste (Cmd+V)"
    echo ""
fi

echo "Ghostty Code will use: $CODE_CONFIG (if it exists)"
