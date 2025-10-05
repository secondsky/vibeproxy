# Release Guide for VibeProxy

This document explains how to create and publish releases for VibeProxy.

## Current Setup: Ad-hoc Signing

VibeProxy uses **ad-hoc signing** (free) for distribution. This means:

✅ **Pros:**
- Free (no Apple Developer account needed)
- Open source friendly
- Users can verify code on GitHub
- Works well for technical users

⚠️ **Cons:**
- Users see "unidentified developer" warning on first launch
- Requires Right-click → Open to bypass Gatekeeper
- Not as polished as notarized apps

## How to Create a Release

### Method 1: Automated (Recommended)

GitHub Actions automatically builds and releases when you push a version tag:

```bash
# Create and push a version tag
git tag v1.0.0
git push origin v1.0.0
```

The workflow will:
1. Build the app on macOS 13 (Ventura)
2. Create both ZIP and DMG files
3. Create a GitHub release with installation instructions
4. Attach the artifacts to the release

### Method 2: Manual Release

Use the local script for testing or manual releases:

```bash
# Create a release locally
./scripts/create-release.sh 1.0.0

# This creates:
# - VibeProxy.app (for local testing)
# - VibeProxy-1.0.0.zip (for distribution)
# - SHA-256 checksum

# Test the app locally first
open VibeProxy.app

# Then create GitHub release manually
gh release create v1.0.0 VibeProxy-1.0.0.zip --generate-notes
```

## Version Numbering

Follow [Semantic Versioning](https://semver.org/):

- **Major** (v1.0.0 → v2.0.0): Breaking changes
- **Minor** (v1.0.0 → v1.1.0): New features, backward compatible
- **Patch** (v1.0.0 → v1.0.1): Bug fixes

## Pre-Release Checklist

Before creating a release:

- [ ] Update `CHANGELOG.md` with changes
- [ ] Test the app thoroughly
- [ ] Verify all authentication flows work
- [ ] Test server start/stop/quit
- [ ] Check menu bar icons
- [ ] Verify Factory AI integration (if applicable)
- [ ] Update README if needed
- [ ] Commit all changes

## Post-Release Checklist

After releasing:

- [ ] Test download and installation from GitHub
- [ ] Verify Gatekeeper bypass instructions work
- [ ] Update any documentation links
- [ ] Announce on relevant channels
- [ ] Update CHANGELOG.md `[Unreleased]` section

## Future: Developer ID Signing

To eliminate the Gatekeeper warning and provide a better user experience, we could implement:

### Option 1: Apple Developer ID ($99/year)

**Benefits:**
- No "unidentified developer" warning
- Users can double-click to open
- More professional distribution

**Process:**
1. Enroll in Apple Developer Program
2. Create Developer ID Application certificate
3. Update `create-app-bundle.sh` to sign with certificate:
   ```bash
   codesign --force --deep --sign "Developer ID Application: Your Name" "$APP_DIR"
   ```
4. Optionally notarize for seamless installation

### Option 2: Notarization (Best UX)

**Benefits:**
- Zero warnings or friction
- Seamless installation
- Professional distribution
- Automatic Gatekeeper approval

**Process:**
1. Sign with Developer ID (from Option 1)
2. Submit to Apple for notarization:
   ```bash
   xcrun notarytool submit VibeProxy.zip \
     --apple-id your@email.com \
     --team-id TEAMID \
     --password app-specific-password \
     --wait
   ```
3. Staple the notarization ticket:
   ```bash
   xcrun stapler staple VibeProxy.app
   ```

**Cost Considerations:**
- $99/year for Apple Developer Program
- Time for notarization (automated, ~5-10 minutes)
- Potential sponsorship or pass cost to users

## Files Overview

- `.github/workflows/release.yml` - Automated release workflow
- `scripts/create-release.sh` - Manual release creation
- `INSTALLATION.md` - User installation guide
- `CHANGELOG.md` - Version history
- `RELEASING.md` - This file

## Troubleshooting

### Build fails in GitHub Actions

- Check the Actions tab for error logs
- Verify Swift version compatibility
- Ensure all dependencies are available

### Users can't open the app

- Direct them to `INSTALLATION.md`
- Most common fix: Right-click → Open
- Alternative: `xattr -cr /Applications/VibeProxy.app`

### Checksum doesn't match

- Re-download the file
- Check if GitHub corrupted the ZIP
- Rebuild and re-upload

## Resources

- [Apple Developer Program](https://developer.apple.com/programs/)
- [Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [GitHub Actions for macOS](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners#supported-runners-and-hardware-resources)

---

**Questions?** Open an [issue](https://github.com/automazeio/vibeproxy/issues).
