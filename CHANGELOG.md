# Changelog

All notable changes to VibeProxy will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Multi-Account Support** - Manage multiple accounts per provider with intelligent switching
  - Add unlimited accounts for each AI service provider (Claude Code, Codex, Gemini, Qwen)
  - **Auto-Switching**: Automatically switches accounts on rate limits (429 responses) using round-robin load balancing
  - **Manual Account Selection**: Choose primary/active account via radio buttons in settings
  - **Visual Account Cards**: See all accounts with nicknames, email addresses, and connection status
  - **Account Management**: Rename accounts, remove expired accounts, add new accounts
  - **Seamless Migration**: Automatically detects existing single accounts and creates account management UI
  - **Backend Integration**: CLIProxyAPI automatically load-balances across all authenticated accounts
  - **No Server Restart**: Add/remove accounts without stopping the proxy server
  - **Persistent Preferences**: Your account preferences are saved and restored between app launches

### Added
- **Unsigned App Building** - Build VibeProxy without Apple Developer account for personal use
  - `build-unsigned.sh` script creates unsigned .app bundles for personal distribution
  - Output to `/Users/eddie/Downloads/` with automatic zip packaging (12MB vs 21MB)
  - No code signing required - works for personal apps and internal distribution
  - First launch requires right-click "Open" or Security preferences adjustment
  - Perfect for users without Apple Developer Program subscription

## [1.0.6] - 2025-10-15

### Added
- **Qwen Support** - Full integration with Qwen AI via OAuth authentication
  - Browser-based Qwen OAuth flow with automatic email submission
  - Pre-authentication email collection dialog for seamless UX
  - Automatic credential file creation with type: "qwen"
  - Connection status display with email and expiration tracking
  - Qwen added to end of service providers list

### Improved
- **Settings Window** - Increased height from 440px to 490px to accommodate Qwen service section

## [1.0.5] - 2025-10-14

### Added
- **Claude Thinking Proxy** - Transform Claude model requests with `-thinking-N` suffixes into Anthropic extended thinking calls
  - Dynamic budget parsing with suffix stripping and safe defaults for invalid values
  - Automatic token headroom management that respects Anthropic limits

### Fixed
- **Factory CLI Compatibility** - Forward all headers and honor connection lifecycle to prevent hangs and connection errors
- **Large Request Handling** - Preserve gzip responses and support payloads beyond 64KB without truncation

## [1.0.4] - 2025-10-14

### Added
- **Gemini Support** - Full integration with Google's Gemini AI via OAuth authentication
  - Browser-based Google OAuth flow for secure authentication
  - Automatic credential file creation (`{email}-{project}.json` with type: "gemini")
  - Project selection during authentication (auto-accepts default after 3 seconds)
  - Support for multiple Google Cloud projects
  - Connection status display with email and expiration tracking
  - Help tooltip explaining project selection behavior

- **Authentication Status System** - Unified credential monitoring for all services
  - `AuthManager` scans `~/.cli-proxy-api/` directory for credential files
  - Real-time file system monitoring for credential changes
  - Support for Claude Code, Codex, and Gemini with type-based detection
  - Expiration date tracking with visual indicators (green/red status)
  - Debug logging for troubleshooting authentication issues

### Improved
- **Settings Window** - Increased height from 380px to 440px
  - All three service sections now visible without scrolling
  - Better spacing and readability
  - Services displayed in alphabetical order: Claude Code, Codex, Gemini

- **Authentication Flow** - More reliable completion detection
  - Process termination handler triggers automatic credential refresh
  - Auto-send newline to stdin for non-interactive project selection
  - Better handling of OAuth callback completion
  - Prevents process hanging during project selection prompt

### Fixed
- **Gemini Authentication** - Resolved credential file creation issues
  - Correctly uses `-login` command for OAuth (vs `-gemini-web-auth` for cookies)
  - Credential files properly detected regardless of filename pattern
  - Authentication completion properly triggers UI refresh
  - Browser opens reliably for OAuth flow

## [1.0.3] - 2025-10-14

### Added
- **Icon Caching System** - New `IconCatalog` singleton for thread-safe icon caching
  - Eliminates redundant disk I/O for frequently accessed icons
  - Icons are preloaded on app launch to reduce first-use latency
  - Cached by name, size, and template flag for optimal reuse

- **Modern Notification System** - Migrated from deprecated `NSUserNotification` to `UNUserNotificationCenter`
  - Proper permission handling with user consent
  - Notifications display with banner and sound, including when app is in foreground
  - Permission state checked before sending notifications

### Improved
- **Server Lifecycle Management** - Enhanced reliability and async handling
  - Dedicated process queue for serialized server operations
  - Graceful shutdown with timeout and force-kill fallback
  - Readiness check after startup to verify server is operational
  - Async `stop()` method with optional completion callback

- **Service Disconnect Flow** - Streamlined and more reliable
  - Generic `performDisconnect()` method eliminates code duplication
  - Automatic server restart after credential removal
  - Better error messages for missing credentials

- **Log Buffer Performance** - Replaced array with O(1) ring buffer
  - Fixed-size circular buffer maintains constant memory footprint
  - Optimal for 1000-line log history

### Fixed
- **Menu Bar Icons** - More consistent sizing and reliable fallbacks to system icons
- Improved status updates and icon changes reflecting server state accurately

## [1.0.2] - 2025-10-06

### Fixed
- **Orphaned Process Cleanup** - App now automatically kills any orphaned server processes on startup
  - Prevents "port already in use" errors after app crashes
  - Detects and logs PIDs of orphaned processes before cleanup
  - Ensures clean server restart after unexpected app termination

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

[1.0.6]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.6
[1.0.5]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.5
[1.0.4]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.4
[1.0.3]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.3
[1.0.2]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.2
[1.0.1]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.1
[1.0.0]: https://github.com/automazeio/vibeproxy/releases/tag/v1.0.0
