# VibeProxy

<p align="center">
  <img src="icon.png" width="128" height="128" alt="VibeProxy Icon">
</p>

A native macOS menu bar application for managing [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) - the unified proxy server for AI services.

## Features

- 🎯 **Native macOS Experience** - Clean, native SwiftUI interface that feels right at home on macOS
- 🚀 **One-Click Server Management** - Start/stop the proxy server from your menu bar
- 🔐 **OAuth Integration** - Authenticate with Codex and Claude Code directly from the app
- 📊 **Real-Time Status** - Live connection status and automatic credential detection
- 🔄 **Auto-Updates** - Monitors auth files and updates UI in real-time
- 🎨 **Beautiful Icons** - Custom icons with dark mode support
- 💾 **Self-Contained** - Everything bundled inside the .app (server binary, config, static files)

<p align="center">
<br>
  <img src="screenshot.webp?v=1" width="600" height="380" alt="VibeProxy Screenshot">
</p>

> [!TIP]
> **Use VibeProxy with Factory AI!** 
> 
> Connect your Claude Code and ChatGPT subscriptions to [Factory Droids](https://factory.ai) to unlock powerful AI coding assistants without paying for separate API access. 
>
> 📖 Check out our [Factory Setup Guide](FACTORY_SETUP.md) for step-by-step instructions.

## Installation

### Build from Source

1. **Clone the repository**
   ```bash
   git clone git@github.com:automazeio/proxybar.git
   cd proxybar
   ```

2. **Build the app**
   ```bash
   ./create-app-bundle.sh
   ```

3. **Install**
   ```bash
   # Option 1: Move to Applications folder
   mv "VibeProxy.app" /Applications/

   # Option 2: Run from current directory
   open "VibeProxy.app"
   ```

## Usage

### First Launch

1. Launch VibeProxy - you'll see a menu bar icon
2. Click the icon and select "Open Settings"
3. The server will start automatically
4. Click "Connect" for Codex or Claude Code to authenticate

### Authentication

When you click "Connect":
1. Your browser opens with the OAuth page
2. Complete the authentication in the browser
3. VibeProxy automatically detects your credentials
4. Status updates to show you're connected

### Server Management

- **Toggle Server**: Click the status (Running/Stopped) to start/stop
- **Menu Bar Icon**: Shows active/inactive state
- **Launch at Login**: Toggle to start VibeProxy automatically

## Requirements

- macOS 13.0 (Ventura) or later
- Swift 5.9+
- [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) binary (auto-bundled during build)

## Building

### Build Commands

```bash
# Quick build and run
make run

# Build .app bundle
make app

# Clean build artifacts
make clean
```

## Development

### Project Structure

```
VibeProxy/
├── Sources/
│   ├── main.swift              # App entry point
│   ├── AppDelegate.swift       # Menu bar & window management
│   ├── ServerManager.swift     # Server process control & auth
│   ├── SettingsView.swift      # Main UI
│   ├── AuthStatus.swift        # Auth file monitoring
│   └── Resources/
│       ├── AppIcon.iconset     # App icon
│       ├── AppIcon.icns        # App icon
│       ├── cli-proxy-api       # CLIProxyAPI binary
│       ├── config.yaml         # CLIProxyAPI config
│       ├── icon-active.png     # Menu bar icon (active)
│       ├── icon-inactive.png   # Menu bar icon (inactive)
│       ├── icon-codex.png      # Codex service icon
│       └── icon-claude.png     # Clause service icon
├── Package.swift               # Swift Package Manager config
├── Info.plist                  # macOS app metadata
├── build.sh                    # Resource bundling script
├── create-app-bundle.sh        # App bundle creation script
└── Makefile                    # Build automation
```

### Key Components

- **AppDelegate**: Manages the menu bar item and settings window lifecycle
- **ServerManager**: Controls the cli-proxy-api server process and OAuth authentication
- **SettingsView**: SwiftUI interface with native macOS design
- **AuthStatus**: Monitors `~/.cli-proxy-api/` for authentication files
- **File Monitoring**: Real-time updates when auth files are added/removed

## Credits

VibeProxy is built on top of [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI), an excellent unified proxy server for AI services.

Special thanks to the CLIProxyAPI project for providing the core functionality that makes VibeProxy possible.

## License

MIT License - see LICENSE file for details

## Support

- **Report Issues**: [GitHub Issues](https://github.com/automazeio/proxybar/issues)
- **Website**: [automaze.io](https://automaze.io)

---

© 2025 [Automaze, Ltd.](https://automaze.io) All rights reserved.
