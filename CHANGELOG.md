# Changelog

All notable changes to VibeProxy will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2025-10-06

### Fixed
- Service icons (Codex and Claude Code) now display correctly in Settings view
- All resource paths corrected to work with bundled app structure

### Documentation
- Added Apple Silicon (M1/M2/M3/M4) requirement to README and installation guide
- Clarified that Intel Macs are not supported

## [1.0.0] - 2025-10-05

Initial release of VibeProxy - a native macOS menu bar application for managing CLIProxyAPI.

### Features

- **Native macOS Experience** - Clean SwiftUI interface with menu bar integration
- **One-Click Server Management** - Start/stop the proxy server from your menu bar
- **OAuth Integration** - Authenticate with Claude Code and Codex directly from the app
- **Real-Time Status** - Live connection status and automatic credential detection
- **Auto-Updates** - Monitors auth files and updates UI in real-time
- **Beautiful Icons** - Custom icons with dark mode support
- **Self-Contained** - Everything bundled inside the .app (server binary, config, static files)
- **Launch at Login** - Optional auto-start on macOS login
- **Factory AI Integration** - Easy setup guide for Factory Droids

### Technical

- Built on [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)
- Code signed with Apple Developer ID
- Notarized for seamless installation
- Automated version injection from git tags
- Automated GitHub Actions release workflow

### Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon (M1/M2/M3/M4) - Intel Macs are not supported

---

## Future Releases

All future changes will be documented here before release.

---

[1.0.1]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.1
[1.0.0]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.0
