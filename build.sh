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

echo -e "${BLUE}📦 Copying resources...${NC}"

# Create Resources directory
mkdir -p "$RESOURCES_DIR"
mkdir -p "$RESOURCES_DIR/static"

# Copy binary
if [ -f "$PARENT_DIR/cli-proxy-api" ]; then
    cp "$PARENT_DIR/cli-proxy-api" "$RESOURCES_DIR/"
    chmod +x "$RESOURCES_DIR/cli-proxy-api"
    echo -e "${GREEN}✓${NC} Copied cli-proxy-api binary"
else
    echo "❌ Error: cli-proxy-api binary not found in parent directory"
    exit 1
fi

# Copy config
if [ -f "$PARENT_DIR/config.yaml" ]; then
    cp "$PARENT_DIR/config.yaml" "$RESOURCES_DIR/"
    echo -e "${GREEN}✓${NC} Copied config.yaml"
else
    echo "❌ Error: config.yaml not found in parent directory"
    exit 1
fi

# Copy static files
if [ -d "$PARENT_DIR/static" ]; then
    cp -r "$PARENT_DIR/static/"* "$RESOURCES_DIR/static/"
    echo -e "${GREEN}✓${NC} Copied static files"
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
