#!/bin/bash

set -e

echo "📦 Creating UNSIGNED .app bundle for personal use..."

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$PROJECT_DIR/src"
APP_NAME="VibeProxy"
BUNDLE_ID="com.vibeproxy.app"
BUILD_DIR="$SRC_DIR/.build/release"
OUTPUT_DIR="/Users/eddie/Downloads"
APP_DIR="$OUTPUT_DIR/$APP_NAME.app"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Build the Swift executable first
echo -e "${BLUE}Building Swift executable (release)...${NC}"
cd "$SRC_DIR"
swift build -c release
cd "$PROJECT_DIR"
echo -e "${GREEN}✅ Build complete${NC}"

# Clean any existing output
echo -e "${BLUE}Cleaning previous build...${NC}"
rm -rf "$APP_DIR"

# Create .app structure
echo -e "${BLUE}Creating .app bundle structure...${NC}"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
echo -e "${BLUE}Copying executable...${NC}"
cp "$BUILD_DIR/CLIProxyMenuBar" "$APP_DIR/Contents/MacOS/"
chmod +x "$APP_DIR/Contents/MacOS/CLIProxyMenuBar"

# Copy resources (copy contents, not the folder itself)
echo -e "${BLUE}Copying resources...${NC}"
if [ -d "$SRC_DIR/Sources/Resources" ]; then
    # Use a loop to copy each item to avoid nested Resources folder
    for item in "$SRC_DIR/Sources/Resources/"*; do
        if [ -e "$item" ]; then
            # Skip if it's a Swift file or Package.swift
            if [[ "$item" != *.swift ]]; then
                cp -r "$item" "$APP_DIR/Contents/Resources/"
            fi
        fi
    done
fi

# Copy Info.plist
echo -e "${BLUE}Copying Info.plist...${NC}"
cp "$SRC_DIR/Info.plist" "$APP_DIR/Contents/"

# Create PkgInfo
echo -e "${BLUE}Creating PkgInfo...${NC}"
echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

# SKIP ALL CODE SIGNING - This creates an unsigned app
echo -e "${YELLOW}⚠️ Skipping code signing (unsigned app for personal use)${NC}"

# Remove any extended attributes that might cause issues
xattr -cr "$APP_DIR" 2>/dev/null || true

# Set appropriate permissions
chmod -R 755 "$APP_DIR"

echo -e "${GREEN}✅ UNSIGNED app bundle created successfully!${NC}"
echo ""
echo -e "${GREEN}📍 Location: $APP_DIR${NC}"
echo ""
echo -e "${YELLOW}⚠️ IMPORTANT - To run this unsigned app:${NC}"
echo "1. Move '$APP_NAME.app' to your desired location"
echo "2. First time launch (one of these methods):"
echo "   • Right-click the app > 'Open' > click 'Open' in dialog"
echo "   • OR: System Preferences > Security & Privacy > Allow apps from: 'Anywhere'"
echo "   • OR: Terminal command: sudo spctl --master-disable"
echo ""
echo -e "${BLUE}For sharing with others:${NC}"
echo "• Zip the .app file: zip -r $APP_NAME-unsigned.zip '$APP_DIR'"
echo "• Or create a DMG if you have create-dmg installed"
echo ""
echo -e "${GREEN}App size: $(du -sh "$APP_DIR" | cut -f1)${NC}"