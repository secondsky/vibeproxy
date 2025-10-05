# Installing VibeProxy

## Download Options

### Option 1: Pre-built Release (Recommended)

1. Go to the [Releases page](https://github.com/automazeio/proxybar/releases)
2. Download the latest `VibeProxy.zip`
3. Extract the ZIP file
4. Drag `VibeProxy.app` to your `/Applications` folder

### Option 2: Build from Source

See the [README.md](README.md) for build instructions.

## First Launch

Since VibeProxy is currently ad-hoc signed (free, open-source distribution), macOS Gatekeeper will show a warning on first launch:

### Method 1: Right-Click Method (Recommended)

1. **Locate** `VibeProxy.app` in your `/Applications` folder
2. **Right-click** (or Control-click) on `VibeProxy.app`
3. Select **"Open"** from the menu
4. In the dialog that appears, click **"Open"** again
5. ✅ The app will now launch and be trusted for future launches

### Method 2: System Settings

1. Try to open VibeProxy normally (double-click)
2. When blocked, open **System Settings** → **Privacy & Security**
3. Scroll down to the "Security" section
4. Click **"Open Anyway"** next to the VibeProxy message
5. Confirm by clicking **"Open"** in the dialog

## Why the Warning?

VibeProxy is currently distributed with **ad-hoc signing** rather than Apple Developer ID signing. This means:

- ✅ The app is **safe** - you can verify the source code on GitHub
- ✅ **Free and open-source** - no $99/year Apple Developer fee
- ⚠️ Requires **one extra step** on first launch (Right-click → Open)
- ⚠️ Shows as an "unidentified developer"

This is a common approach for open-source macOS apps distributed outside the Mac App Store.

## Verifying Authenticity

Before opening any downloaded app, you can verify it's from the official repository:

1. **Check the source**: Download only from the official [GitHub Releases](https://github.com/automazeio/proxybar/releases)
2. **Verify the checksum** (optional):
   ```bash
   shasum -a 256 VibeProxy.zip
   ```
   Compare with the checksum listed on the release page

3. **Inspect the code**: All source code is available in this repository

## Troubleshooting

### "App is damaged and can't be opened"

This can happen if the app's quarantine attributes aren't cleared properly:

```bash
xattr -cr /Applications/VibeProxy.app
```

Then try opening again with Right-click → Open.

### Still Having Issues?

- **Check System Requirements**: macOS 13.0 (Ventura) or later
- **Report an Issue**: [GitHub Issues](https://github.com/automazeio/proxybar/issues)

## Future: Notarized Releases

We're considering Apple Developer ID signing and notarization for future releases, which would eliminate the Gatekeeper warning entirely. This requires:

- Apple Developer Program membership ($99/year)
- App notarization process
- Possibly passing the cost to users or seeking sponsorship

If you'd like to support notarized releases, consider:
- ⭐ Starring the repository
- 💰 [Sponsoring the project](https://github.com/sponsors/automazeio) (if available)
- 🗣️ Spreading the word about VibeProxy

---

**Questions?** Open an [issue](https://github.com/automazeio/proxybar/issues) or check the [README](README.md).
