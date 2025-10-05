# Using Factory AI with VibeProxy

A simplified guide for using Factory CLI (Droid) with your personal Claude and ChatGPT subscriptions through VibeProxy.

---

> ## ⚠️ IMPORTANT DISCLAIMER
>
> **This guide describes a proof-of-concept configuration for educational and experimental purposes only.**
>
> **By using this method, you acknowledge and accept the following:**
>
> - **Terms of Service Risk**: This approach may violate the Terms of Service of AI model providers (Anthropic, OpenAI, etc.). You are solely responsible for ensuring compliance with all applicable terms and policies.
>
> - **Account Risk**: Model providers may detect this usage pattern and take punitive action, including but not limited to account suspension, permanent ban, or loss of access to paid subscriptions.
>
> - **No Guarantees**: Providers may change their APIs, authentication mechanisms, or policies at any time, rendering this method inoperable without notice.
>
> - **Assumption of Risk**: By proceeding, you assume all legal, financial, and technical risks. The authors and contributors of this guide and CLIProxyAPI bear no responsibility for any consequences arising from your use of this method.
>
> **Use at your own risk. Proceed only if you understand and accept these risks.**

---

## What is This?

This guide shows you how to use Factory CLI with your personal Claude Code Max and ChatGPT Plus/Pro subscriptions instead of paying for separate API access. VibeProxy acts as a bridge that handles the authentication and routing for you.

## Architecture Overview

```
Factory CLI  →  VibeProxy  →  [OAuth Authentication]  →  Claude / ChatGPT APIs
```

VibeProxy automatically:
- Manages OAuth tokens for both services
- Auto-refreshes expired tokens
- Routes requests to the correct service
- Handles API format conversion

## Prerequisites

- macOS 13.0+ (Ventura or later)
- Active **Claude Code Max** (or Claude Pro) subscription for Anthropic access
- Active **ChatGPT Plus/Pro** subscription for OpenAI Codex access
- Factory CLI installed: `curl -fsSL https://app.factory.ai/cli | sh`

## Step 1: Install VibeProxy

1. **Download VibeProxy.app** from the releases page or build from source
2. **Install**: Drag `VibeProxy.app` to your `/Applications` folder
3. **Launch**: Open VibeProxy from Applications
   - If macOS blocks it: Right-click → Open, then click "Open" in the dialog

## Step 2: Connect Your Accounts

Once VibeProxy is running:

1. Click the **VibeProxy menu bar icon**
2. Select **"Open Settings"**
3. Click **"Connect"** next to Claude Code
   - Your browser will open for authentication
   - Complete the login process
   - VibeProxy will automatically detect when you're authenticated
4. Click **"Connect"** next to Codex
   - Follow the same browser authentication process
   - Wait for VibeProxy to confirm the connection

✅ The server starts automatically and runs on port **8317**

## Step 3: Configure Factory CLI

Edit your Factory configuration file at `~/.factory/config.json`:

```json
{
  "custom_models": [
    {
      "model": "claude-sonnet-4-5-20250929",
      "base_url": "http://localhost:8317",
      "api_key": "dummy-not-used",
      "provider": "anthropic"
    },
    {
      "model": "claude-opus-4-1-20250805",
      "base_url": "http://localhost:8317",
      "api_key": "dummy-not-used",
      "provider": "anthropic"
    },
    {
      "model": "claude-sonnet-4-20250514",
      "base_url": "http://localhost:8317",
      "api_key": "dummy-not-used",
      "provider": "anthropic"
    },
    {
      "model": "gpt-5",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model": "gpt-5-minimal",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model": "gpt-5-low",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model": "gpt-5-medium",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model": "gpt-5-high",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model": "gpt-5-codex",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model": "gpt-5-codex-low",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model": "gpt-5-codex-medium",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    },
    {
      "model": "gpt-5-codex-high",
      "base_url": "http://localhost:8317/v1",
      "api_key": "dummy-not-used",
      "provider": "openai"
    }
  ]
}
```

**Note about `/v1`**: 
- For Anthropic models, use just `http://localhost:8317` 
- For OpenAI models, use `http://localhost:8317/v1`

This is because Factory appends `/messages` for Anthropic and `/responses` for OpenAI automatically.

## Step 4: Use Factory CLI

1. **Launch Factory CLI**:
   ```bash
   droid
   ```

2. **Select your model**:
   ```
   /model
   ```
   Then choose from:
   - `claude-sonnet-4-5-20250929` (Claude 4.5 Sonnet)
   - `claude-opus-4-1-20250805`
   - `gpt-5`, `gpt-5-codex`, etc.

3. **Start coding!** Factory will now route all requests through VibeProxy, which handles authentication automatically.

## Available Models

### Claude Models (via Claude Code Max/Pro)
- `claude-sonnet-4-5-20250929` - Claude 4.5 Sonnet (Latest)
- `claude-opus-4-1-20250805` - Claude Opus 4.1
- `claude-sonnet-4-20250514` - Claude Sonnet 4

### OpenAI Models (via ChatGPT Plus/Pro)
- `gpt-5` - Standard GPT-5
- `gpt-5-minimal`, `gpt-5-low`, `gpt-5-medium`, `gpt-5-high` - Different reasoning levels
- `gpt-5-codex`, `gpt-5-codex-low`, `gpt-5-codex-medium`, `gpt-5-codex-high` - Codex variants

## Troubleshooting

### VibeProxy Menu Bar Status
- **Green dot**: Server is running
- **Red dot**: Server is stopped
- **Click the status** to toggle the server on/off

### Connection Issues

| Problem | Solution |
|---------|----------|
| Can't connect to Claude/Codex | Re-click "Connect" in VibeProxy settings |
| Factory shows 404 errors | Make sure VibeProxy server is running (check menu bar) |
| Authentication expired | Disconnect and reconnect the service in VibeProxy |
| Port 8317 already in use | Quit any other instances of VibeProxy or CLIProxyAPI |

### Enable Debug Mode

Open VibeProxy settings to view server logs and connection status. The app automatically monitors your `~/.cli-proxy-api/` directory for auth files.

### Verification Checklist

1. ✅ VibeProxy is running (menu bar shows status)
2. ✅ Both Claude and Codex show as "Connected" in settings
3. ✅ Factory CLI config has the custom models configured
4. ✅ `droid` command can select custom models
5. ✅ Test with a simple prompt: "what day is it?"

## Tips

- **Launch at Login**: Enable in VibeProxy settings to auto-start the server
- **Server URL**: Copy `http://localhost:8317` from the menu (right-click the status)
- **Auth Folder**: Click "Open Folder" in settings to view your authentication files
- **Quit Safely**: VibeProxy automatically stops the server and releases port 8317

## Security Notes

- All authentication tokens are stored locally in `~/.cli-proxy-api/`
- Token files are secured with proper permissions (0600)
- VibeProxy only binds to localhost (127.0.0.1)
- All upstream traffic uses HTTPS
- Tokens are auto-refreshed before expiration

## References

- **VibeProxy**: This application
- **CLIProxyAPI**: [https://github.com/router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)
- **Factory CLI**: [https://docs.factory.ai/cli](https://docs.factory.ai/cli)
- **Original Setup Guide**: [https://gist.github.com/ben-vargas/9f1a14ac5f78d10eba56be437b7c76e5](https://gist.github.com/ben-vargas/9f1a14ac5f78d10eba56be437b7c76e5)

---

**Need Help?** 
- Report issues: [GitHub Issues](https://github.com/automazeio/proxybar/issues)
- VibeProxy by [Automaze, Ltd.](https://automaze.io)
