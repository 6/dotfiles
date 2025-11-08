#!/bin/bash

set -e

# Configuration
ORIGINAL_APP="/Applications/Ghostty.app"
NEW_APP="/Applications/Ghostty Code.app"
NEW_BUNDLE_ID="com.mitchellh.ghostty.code"
NEW_APP_NAME="Ghostty Code"

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
    echo -e "${YELLOW}If you want to recreate it, manually delete it first:${NC}"
    echo -e "${YELLOW}  rm -rf \"$NEW_APP\"${NC}"
    echo ""
    echo "Exiting without changes."
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

# Modify the icon to be orange-tinted
echo "🎨 Creating orange-tinted icon..."

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null && ! command -v convert &> /dev/null; then
    echo -e "${YELLOW}⚠️  ImageMagick not found. Skipping icon modification.${NC}"
    echo -e "${YELLOW}   Install with: brew install imagemagick${NC}"
else
    ICNS_FILE="$NEW_APP/Contents/Resources/Ghostty.icns"

    if [ -f "$ICNS_FILE" ]; then
        echo "  Processing: Ghostty.icns"

        # Create a temporary directory for icon processing
        TEMP_DIR=$(mktemp -d)

        # Extract all PNG representations from the .icns file
        iconutil -c iconset "$ICNS_FILE" -o "$TEMP_DIR/original.iconset" 2>/dev/null || {
            echo -e "${YELLOW}  ⚠️  Could not extract iconset${NC}"
            rm -rf "$TEMP_DIR"
            exit 1
        }

        # Create new iconset directory
        mkdir -p "$TEMP_DIR/new.iconset"

        # Apply orange tint to each PNG - using hue rotation to maintain clarity
        for png in "$TEMP_DIR/original.iconset"/*.png; do
            if [ -f "$png" ]; then
                filename=$(basename "$png")
                if command -v magick &> /dev/null; then
                    # Hue rotation approach - shifts colors to orange while maintaining contrast
                    # Also boost saturation slightly to make it pop
                    magick "$png" -modulate 100,130,100 \
                        -colorspace HSL -channel R -evaluate multiply 1.3 +channel \
                        -colorspace sRGB \
                        "$TEMP_DIR/new.iconset/$filename"
                else
                    convert "$png" -modulate 100,130,100 \
                        -colorspace HSL -channel R -evaluate multiply 1.3 +channel \
                        -colorspace sRGB \
                        "$TEMP_DIR/new.iconset/$filename"
                fi
            fi
        done

        # Convert iconset back to icns
        iconutil -c icns "$TEMP_DIR/new.iconset" -o "$ICNS_FILE"

        if [ -f "$ICNS_FILE" ]; then
            echo -e "${GREEN}✓ Orange-tinted icon created${NC}"
        fi

        # Clean up
        rm -rf "$TEMP_DIR"
    else
        echo -e "${YELLOW}⚠️  Icon file not found${NC}"
    fi
fi

# Remove the code signature (it's now invalid after our modifications)
echo "🔏 Re-signing application..."
codesign --force --deep --sign - "$NEW_APP"
echo -e "${GREEN}✓ Application re-signed${NC}"

# Update modification time and register with Launch Services
echo "🔄 Registering with Launch Services..."
touch "$NEW_APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$NEW_APP"

echo -e "${GREEN}✅ Done! Ghostty Code.app is ready.${NC}"
echo ""
echo -e "${YELLOW}⚠️  RESTART YOUR MAC for the new icon to appear.${NC}"
