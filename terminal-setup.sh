#!/bin/bash

set -e

# Configuration
ORIGINAL_APP="/Applications/Ghostty.app"
NEW_APP="/Applications/Ghostty Code.app"
NEW_BUNDLE_ID="com.mitchellh.ghostty.code"
NEW_APP_NAME="Ghostty Code"
OUTPUT_ICON="$HOME/Desktop/ghostty_code_icon.png"

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

        # Apply orange tint using ImageMagick
        if command -v magick &> /dev/null; then
            magick /tmp/ghostty_temp.png -modulate 100,130,100 \
                -colorspace HSL -channel R -evaluate multiply 1.3 +channel \
                -colorspace sRGB \
                "$OUTPUT_ICON"
        else
            convert /tmp/ghostty_temp.png -modulate 100,130,100 \
                -colorspace HSL -channel R -evaluate multiply 1.3 +channel \
                -colorspace sRGB \
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
codesign --force --deep --sign - "$NEW_APP"
echo -e "${GREEN}✓ Application re-signed${NC}"

# Update modification time and register with Launch Services
echo "🔄 Registering with Launch Services..."
touch "$NEW_APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$NEW_APP"

echo ""
echo -e "${GREEN}✅ Done! Ghostty Code.app is ready.${NC}"
echo ""

if [ "$SKIP_ICON" = false ]; then
    echo -e "${YELLOW}📝 MANUAL ICON SETUP REQUIRED:${NC}"
    echo ""
    echo "1. Open Finder and navigate to /Applications"
    echo "2. Right-click 'Ghostty Code.app' and select 'Get Info' (or press Cmd+I)"
    echo "3. In the Get Info window, click on the small icon in the top-left corner"
    echo "4. Press Cmd+C to copy the current icon (this step is optional but good practice)"
    echo "5. Open the generated icon on your Desktop: $OUTPUT_ICON"
    echo "6. Select the image and press Cmd+C to copy it"
    echo "7. Go back to the Get Info window for Ghostty Code.app"
    echo "8. Click the icon in the top-left corner again"
    echo "9. Press Cmd+V to paste the new orange icon"
    echo "10. Close the Get Info window"
    echo ""
    echo "The icon should update immediately without needing to restart!"
else
    echo -e "${YELLOW}Icon generation was skipped. The apps will have the same icon.${NC}"
fi
