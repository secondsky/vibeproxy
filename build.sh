#!/bin/bash

set -e

echo "🔨 Building CLI Proxy MenuBar App..."

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="$PROJECT_DIR/Sources/Resources"
PARENT_DIR="$(dirname "$PROJECT_DIR")"

echo -e "${BLUE}📦 Checking resources...${NC}"

# Create Resources directory if it doesn't exist
mkdir -p "$RESOURCES_DIR"
mkdir -p "$RESOURCES_DIR/static"

# Check if resources already exist, otherwise try to copy from parent
if [ -f "$RESOURCES_DIR/cli-proxy-api" ]; then
    echo -e "${GREEN}✓${NC} cli-proxy-api binary already in Resources"
elif [ -f "$PARENT_DIR/cli-proxy-api" ]; then
    cp "$PARENT_DIR/cli-proxy-api" "$RESOURCES_DIR/"
    chmod +x "$RESOURCES_DIR/cli-proxy-api"
    echo -e "${GREEN}✓${NC} Copied cli-proxy-api binary from parent directory"
else
    echo "❌ Error: cli-proxy-api binary not found"
    exit 1
fi

# Check config.yaml
if [ -f "$RESOURCES_DIR/config.yaml" ]; then
    echo -e "${GREEN}✓${NC} config.yaml already in Resources"
elif [ -f "$PARENT_DIR/config.yaml" ]; then
    cp "$PARENT_DIR/config.yaml" "$RESOURCES_DIR/"
    echo -e "${GREEN}✓${NC} Copied config.yaml from parent directory"
else
    echo "❌ Error: config.yaml not found"
    exit 1
fi

# Check static files
if [ -d "$RESOURCES_DIR/static" ] && [ "$(ls -A $RESOURCES_DIR/static)" ]; then
    echo -e "${GREEN}✓${NC} Static files already in Resources"
elif [ -d "$PARENT_DIR/static" ]; then
    cp -r "$PARENT_DIR/static/"* "$RESOURCES_DIR/static/"
    echo -e "${GREEN}✓${NC} Copied static files from parent directory"
else
    echo "⚠️  Warning: static directory not found"
fi

echo -e "${BLUE}🏗️  Building Swift app...${NC}"

# Build the Swift package
swift build -c release

echo -e "${GREEN}✓ Build complete!${NC}"
echo ""
echo "To create a .app bundle, you can use:"
echo "  1. Xcode (recommended for distribution)"
echo "  2. Platypus (for quick wrapping)"
echo "  3. Manual .app bundle creation"
echo ""
echo "The binary is located at:"
echo "  .build/release/CLIProxyMenuBar"
