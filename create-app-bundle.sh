#!/bin/bash

set -e

echo "📦 Creating .app bundle..."

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$PROJECT_DIR/src"
APP_NAME="VibeProxy"
BUNDLE_ID="com.cliproxyapi.menubar"
BUILD_DIR="$SRC_DIR/.build/release"
APP_DIR="$PROJECT_DIR/$APP_NAME.app"

# Build first
echo -e "${BLUE}Building application...${NC}"
bash "$PROJECT_DIR/build.sh"

# Create .app structure
echo -e "${BLUE}Creating .app bundle structure...${NC}"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
echo -e "${BLUE}Copying executable...${NC}"
cp "$BUILD_DIR/CLIProxyMenuBar" "$APP_DIR/Contents/MacOS/"
chmod +x "$APP_DIR/Contents/MacOS/CLIProxyMenuBar"

# Copy resources
echo -e "${BLUE}Copying resources...${NC}"
cp -r "$SRC_DIR/Sources/Resources" "$APP_DIR/Contents/Resources/"

# Copy app icon
if [ -f "$SRC_DIR/Sources/Resources/AppIcon.icns" ]; then
    cp "$SRC_DIR/Sources/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"
fi

# Copy Info.plist
echo -e "${BLUE}Copying Info.plist...${NC}"
cp "$SRC_DIR/Info.plist" "$APP_DIR/Contents/"

# Create PkgInfo
echo -e "${BLUE}Creating PkgInfo...${NC}"
echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

# Sign the app (ad-hoc signature)
echo -e "${BLUE}Signing app...${NC}"
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || echo -e "${YELLOW}⚠️  Code signing skipped (not critical for local use)${NC}"

echo -e "${GREEN}✅ App bundle created successfully!${NC}"
echo ""
echo -e "${GREEN}Location: $APP_DIR${NC}"
echo ""
echo "To install:"
echo "  1. Drag '$APP_NAME.app' to /Applications"
echo "  2. Double-click to launch"
echo ""
echo "To allow opening (if macOS blocks it):"
echo "  Right-click > Open, then click 'Open' in the dialog"
