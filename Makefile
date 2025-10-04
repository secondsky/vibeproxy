.PHONY: build app install clean run help

help: ## Show this help message
	@echo "CLI Proxy API - macOS Menu Bar App"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build the Swift executable (debug)
	@echo "🔨 Building Swift executable..."
	@swift build
	@echo "✅ Build complete: .build/debug/CLIProxyMenuBar"

release: ## Build the Swift executable (release)
	@echo "🔨 Building Swift executable (release)..."
	@./build.sh
	@echo "✅ Build complete: .build/release/CLIProxyMenuBar"

app: ## Create the .app bundle
	@echo "📦 Creating .app bundle..."
	@./create-app-bundle.sh
	@echo "✅ App bundle created: CLI Proxy API.app"

install: app ## Build and install to /Applications
	@echo "📲 Installing to /Applications..."
	@rm -rf "/Applications/CLI Proxy API.app"
	@cp -r "CLI Proxy API.app" /Applications/
	@echo "✅ Installed to /Applications/CLI Proxy API.app"

run: app ## Build and run the app
	@echo "🚀 Launching app..."
	@open "CLI Proxy API.app"

clean: ## Clean build artifacts
	@echo "🧹 Cleaning..."
	@rm -rf .build
	@rm -rf "CLI Proxy API.app"
	@rm -rf Sources/Resources/cli-proxy-api
	@rm -rf Sources/Resources/config.yaml
	@rm -rf Sources/Resources/static
	@echo "✅ Clean complete"

test: ## Run a quick test build
	@echo "🧪 Testing build..."
	@swift build
	@echo "✅ Test build successful"

info: ## Show project information
	@echo "Project: CLI Proxy API Menu Bar"
	@echo "Language: Swift 5.9+"
	@echo "Platform: macOS 13.0+"
	@echo ""
	@echo "Files:"
	@find Sources -name "*.swift" -exec wc -l {} + | tail -1 | awk '{print "  Swift code: " $$1 " lines"}'
	@echo "  Documentation: 4 files"
	@echo ""
	@echo "Structure:"
	@tree -L 2 -I ".build" || echo "  (install 'tree' for better output)"

open: ## Open app bundle to inspect contents
	@if [ -d "CLI Proxy API.app" ]; then \
		open "CLI Proxy API.app"; \
	else \
		echo "❌ App bundle not found. Run 'make app' first."; \
	fi

edit-config: ## Edit the bundled config.yaml
	@if [ -d "CLI Proxy API.app" ]; then \
		open -e "CLI Proxy API.app/Contents/Resources/config.yaml"; \
	else \
		echo "❌ App bundle not found. Run 'make app' first."; \
	fi

# Shortcuts
all: app ## Same as 'app'
