# Using Factory AI with VibeProxy

A simplified guide for using Factory CLI (Droid) with your personal Claude and ChatGPT subscriptions through VibeProxy.

> [!WARNING]
> **⚠️ IMPORTANT DISCLAIMER**
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

This guide shows you how to use [Factory CLI](https://app.factory.ai/r/FM8BJHFQ) with your personal Claude Code Pro/Max and ChatGPT Plus/Pro subscriptions instead of paying for separate API access. VibeProxy acts as a bridge that handles authentication and routing automatically.

**How it works:**

```
Factory CLI  →  VibeProxy  →  [OAuth Authentication]  →  Claude / ChatGPT APIs
```

VibeProxy manages OAuth tokens, auto-refreshes them, routes requests, and handles API format conversion — all automatically in the background.

## Prerequisites

- macOS 13.0+ (Ventura or later)
- Active **Claude Code Pro/Max** subscription for Anthropic access
- Active **ChatGPT Plus/Pro** subscription for OpenAI Codex access
- Factory CLI installed: `curl -fsSL https://app.factory.ai/cli | sh`

## Step 1: Install VibeProxy

1. **Download [VibeProxy.app](https://github.com/automazeio/vibeproxy)** from the releases page or build from source
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

Edit your Factory configuration file at `~/.factory/config.json` (if the file doesn't exist, create it):

```json
{
  "custom_models": [
    {
      "model": "claude-opus-4-1-20250805",
      "base_url": "http://localhost:8317",
      "api_key": "dummy-not-used",
      "provider": "anthropic"
    },
    {
      "model": "claude-sonnet-4-5-20250929",
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

### Claude Models
- `claude-opus-4-1-20250805` - Claude Opus 4.1 (Most powerful)
- `claude-sonnet-4-5-20250929` - Claude 4.5 Sonnet (Latest)

### OpenAI Models
- `gpt-5` - Standard GPT-5
- `gpt-5-minimal` / `low` / `medium` / `high` - Different reasoning effort levels
- `gpt-5-codex` - Optimized for coding
- `gpt-5-codex-low` / `medium` / `high` - Codex with different reasoning levels

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

### Verification Checklist

1. ✅ VibeProxy is running (menu bar icon shows green)
2. ✅ Both Claude and Codex show as "Connected" in settings
3. ✅ Factory CLI config has the custom models configured
4. ✅ `droid` can select your custom models
5. ✅ Test with a simple prompt: "what day is it?"

## Tips

- **Launch at Login**: Enable in VibeProxy settings to auto-start the server
- **Auth Folder**: Click "Open Folder" in settings to view authentication tokens
- **Server Control**: VibeProxy automatically stops the server and releases port 8317 when you quit

## Security

- All authentication tokens are stored locally in `~/.cli-proxy-api/`
- Token files are secured with proper permissions (0600)
- VibeProxy only binds to localhost (127.0.0.1)
- All upstream traffic uses HTTPS
- Tokens are auto-refreshed before expiration

---

## Acknowledgments

VibeProxy is built on top of [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI), an excellent unified proxy server for AI services. Without CLIProxyAPI's robust OAuth handling, token management, and API routing capabilities, this application would not be possible.

**Special thanks to the CLIProxyAPI project and its contributors for creating the foundation that makes VibeProxy work.**

## References

- **CLIProxyAPI**: [https://github.com/router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)
- **Factory CLI**: [https://docs.factory.ai/cli](https://docs.factory.ai/cli)
- **Original Setup Guide**: [https://gist.github.com/ben-vargas/9f1a14ac5f78d10eba56be437b7c76e5](https://gist.github.com/ben-vargas/9f1a14ac5f78d10eba56be437b7c76e5)

---

**Need Help?**
- Report issues: [GitHub Issues](https://github.com/automazeio/vibeproxy/issues)
- VibeProxy by [Automaze, Ltd.](https://automaze.io)
