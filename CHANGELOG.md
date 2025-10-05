# Changelog

All notable changes to VibeProxy will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Factory AI integration guide
- Automated GitHub Actions workflow for releases
- Installation guide for users

### Changed
- Rebranded from ProxyBar to VibeProxy
- Improved process cleanup to properly release ports
- Restructured project with src/ directory

### Fixed
- Server process not properly terminating on app quit
- Port 8317 sometimes remaining in use after quit

## [1.0.0] - TBD

### Added
- Native macOS menu bar application
- One-click server management
- OAuth integration for Claude Code and Codex
- Real-time status monitoring
- Auto-refresh of authentication tokens
- Custom icons with dark mode support
- Self-contained app bundle
- Built on top of CLIProxyAPI

### Features
- Start/stop proxy server from menu bar
- Browser-based OAuth authentication
- Automatic credential detection
- Launch at login option
- Auth folder quick access
- Server URL copying

### Requirements
- macOS 13.0 (Ventura) or later
- Swift 5.9+
- CLIProxyAPI binary (bundled)

---

[Unreleased]: https://github.com/automazeio/proxybar/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/automazeio/proxybar/releases/tag/v1.0.0
