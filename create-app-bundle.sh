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

# Build the Swift executable first
echo -e "${BLUE}Building Swift executable (release)...${NC}"
cd "$SRC_DIR"
swift build -c release
cd "$PROJECT_DIR"
echo -e "${GREEN}✅ Build complete${NC}"

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

# Copy Info.plist and inject version
echo -e "${BLUE}Copying Info.plist...${NC}"
cp "$SRC_DIR/Info.plist" "$APP_DIR/Contents/"

# Inject version from git tag or environment variable
VERSION="${APP_VERSION:-}"
if [ -z "$VERSION" ]; then
    # Try to get version from git tag
    VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")
    # Remove 'v' prefix if present
    VERSION="${VERSION#v}"
fi

# Extract build number from full git describe (e.g., v1.0.0-5-g1234567 -> 5, or just use commit count)
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo "1")

echo -e "${BLUE}Setting version to: ${VERSION} (build ${BUILD_NUMBER})${NC}"

# Update Info.plist with version
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "$APP_DIR/Contents/Info.plist"

# Create PkgInfo
echo -e "${BLUE}Creating PkgInfo...${NC}"
echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

# Sign the app with Developer ID if available, otherwise ad-hoc
echo -e "${BLUE}Signing app...${NC}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
if [ -z "$CODESIGN_IDENTITY" ]; then
    # Try to find Developer ID automatically
    CODESIGN_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')
fi

if [ -n "$CODESIGN_IDENTITY" ]; then
    echo -e "${GREEN}Signing with: $CODESIGN_IDENTITY${NC}"
    
    # Clean up extended attributes and resource forks that prevent signing
    xattr -cr "$APP_DIR"
    
    # Remove any existing signatures first
    codesign --remove-signature "$APP_DIR/Contents/MacOS/CLIProxyMenuBar" 2>/dev/null || true
    
    # Sign the executable first with hardened runtime
    codesign --force --sign "$CODESIGN_IDENTITY" --options runtime --timestamp "$APP_DIR/Contents/MacOS/CLIProxyMenuBar"
    
    # Then sign the entire app bundle
    codesign --force --sign "$CODESIGN_IDENTITY" --options runtime --timestamp "$APP_DIR"
    
    echo -e "${GREEN}✅ Code signed successfully${NC}"
    
    # Verify the signature
    codesign --verify --deep --strict --verbose=2 "$APP_DIR" && echo -e "${GREEN}✅ Signature verified${NC}"
else
    echo -e "${YELLOW}⚠️ No Developer ID found, using ad-hoc signature${NC}"
    codesign --force --deep --sign - "$APP_DIR"
fi

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
