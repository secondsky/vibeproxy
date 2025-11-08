# CLIProxyAPI: Multi-Account + VibeProxy Integration Spec

This document describes the changes required in this CLIProxyAPI fork so it behaves exactly as expected by the current VibeProxy menubar app.

Goals:
- Support multiple authenticated accounts per provider (Claude, Codex, Gemini, Qwen, etc.).
- Let VibeProxy choose the active account per provider via files under `~/.cli-proxy-api`.
- Preserve backward compatibility with existing single-account setups.

## 1. Auth Storage Model

Each authenticated account must be stored as its own JSON file:

- Directory: `~/.cli-proxy-api/`
- Filename pattern: `provider-accountId.json`
  - `provider`: lowercase provider key (`claude`, `codex`, `gemini`, `qwen`, etc.).
  - `accountId`: stable identifier for the account (see below).

Each per-account JSON must contain at least:

- `type`: string
  - Provider identifier used elsewhere (e.g. `"claude"`, `"codex"`, `"gemini"`, `"qwen"`).
- `accountId`: string
  - Required for new files.
  - Unique/stable ID for this account.
- `accountNickname`: string (optional)
  - For UI display; VibeProxy modifies this.
- `email`: string (optional)
  - Used by VibeProxy for status text.
- `expired`: ISO8601 datetime with fractional seconds (optional)
  - Used to compute `isExpired` in VibeProxy.
- `createdAt`: ISO8601 datetime with fractional seconds (optional)
  - Used for ordering / display.
- Provider-specific tokens/refresh tokens/etc.

Behavioral requirements:

- On successful auth:
  - DO NOT rely solely on a single global `provider.json` being overwritten.
  - Create or update a specific `provider-accountId.json` file for that account.
- Support multiple `provider-*.json` files co-existing per provider.

## 2. Account ID and Filename Conventions

VibeProxy’s `AuthStatus.swift` reconstructs accounts based on JSON plus filename; CLIProxyAPI must align.

Rules:

1. Preferred format for new files:
   - `provider-accountId.json`
   - Write `accountId` into the JSON body.

2. When loading:

   - Strip `.json` → `baseName`.
   - If JSON has `accountId`, use it.
   - Else, infer:
     - If `baseName` starts with `"{provider}-"`, use the suffix as `accountId`.
     - Otherwise, use `baseName` itself (for legacy UUID-style or old files).

3. Always include `type` in JSON so VibeProxy can group by provider.

This matches the extraction logic already used by VibeProxy.

## 3. Active Account Selection via `active-accounts.json`

VibeProxy selects accounts by writing a control file:

- Path: `~/.cli-proxy-api/active-accounts.json`
- Format: flat object mapping provider → selected identifier.

Example:

```json
{
  "claude": "claude-abc123",
  "codex": "work@example.com",
  "gemini": "gemini-sandbox",
  "qwen": "another@example.com"
}
```

VibeProxy writes:

- A value derived from the chosen `accountId`, possibly including or derived from:
  - `provider-accountId`
  - bare `accountId`
  - email-like strings (see below)

CLIProxyAPI must:

1. On each request (or on suitable cache/refresh):

   - Enumerate all `~/.cli-proxy-api/*.json` files.
   - Parse each into an internal `Account` model.
   - Group accounts by their `type` (provider).

2. Load `active-accounts.json` if it exists.

3. For the provider handling the current request, resolve the active account:

   Matching strategy (in order):

   - Exact match against `account.accountId`.
   - If the configured value looks like `provider-*`:
     - Strip `provider-` and match suffix to `accountId`.
   - Compare against email when present.
   - Compare against filename-derived id (same rules VibeProxy uses):
     - Base name without `.json`
     - Optionally without `provider-` prefix.

4. If a matching account is found and not expired:
   - Use that account’s credentials for the upstream call.

5. If no valid match:
   - Fallback to:
     - First non-expired account for that provider, or
     - Existing single-account behavior.
   - Never hard-fail solely due to a bad `active-accounts.json`.

6. If `active-accounts.json` is missing/malformed:
   - Ignore and use default account selection.

## 4. Multiple-Account Semantics

Per provider:

- All `provider-*.json` files represent distinct accounts.
- VibeProxy:
  - Scans `~/.cli-proxy-api/*.json`.
  - Reads `type`, `email`, `expired`, `accountId`, etc.
  - Lets the user pick an account; writes choice into `active-accounts.json`.
  - Updates `accountNickname` and may delete account files.
- CLIProxyAPI:
  - Must treat these files as canonical.
  - Must respect `active-accounts.json` for which account to use.
  - Must tolerate UI edits:
    - `accountNickname` changes.
    - Account file deletion (treat missing file as account removed).

No new HTTP endpoints are required for VibeProxy; everything is via filesystem contract.

## 5. Expiry Handling

VibeProxy uses:

- `expired` field → `isExpired = expired < now`.

CLIProxyAPI should:

- Populate or update `expired` when tokens are issued/refreshed/invalidated.
- Avoid automatically selecting expired accounts when valid ones exist.
- On fallback:
  - Prefer non-expired accounts.
- If `expired` is absent:
  - Treat account as non-expired.

## 6. Nickname Handling

VibeProxy writes `accountNickname` into the same per-account JSON file.

CLIProxyAPI must:

- Preserve `accountNickname` and unknown fields when updating files:
  - Read existing JSON → merge new values → write back.
- Never depend on `accountNickname` as an identifier.
- Never wipe metadata like `accountNickname`, `createdAt` unless intentionally migrating.

## 7. Backward Compatibility

Requirements:

- Existing installs with a single credentials file must keep working.

Recommended behavior:

- On startup / auth loading:
  - Support legacy files (e.g. `claude.json` or single JSON).
  - Treat them as one account for that provider.
  - Optionally expose them in the same `Account` model (`accountId` from filename).
- When adding new accounts:
  - Use the new per-account pattern and include `accountId` in JSON.
- When updating logic:
  - Prefer non-breaking migrations (no forced renames unless explicitly implemented).

## 8. Implementation Checklist (for this repo)

When applying changes in this fork, ensure at least:

1. Internal model:

   - [ ] Introduce `Account`/`ProviderAccount` structure:
     - `type`, `accountId`, `email`, `accountNickname`, `expired`, `createdAt`, token fields.
   - [ ] Add helpers:
     - Scan `~/.cli-proxy-api`.
     - Parse and group accounts by provider.
     - Derive `accountId` from filename when missing.

2. Auth flows:

   - [ ] On successful OAuth/auth:
     - Create/maintain `provider-accountId.json`.
     - Include `type` and `accountId`.
     - Do not assume a single global file per provider.

3. Active account resolution:

   - [ ] Implement loader for `active-accounts.json`.
   - [ ] For each request:
     - Resolve active account per provider using matching rules above.
     - Fallback gracefully if no match/expired/invalid.

4. Request routing:

   - [ ] Wherever CLIProxyAPI selects credentials/tokens:
     - Use the resolved active `Account` for that provider.
   - [ ] Ensure all provider integrations (Claude, etc.) honor this.

5. File I/O robustness:

   - [ ] Ignore malformed JSON files instead of crashing.
   - [ ] Ignore malformed `active-accounts.json` and continue with defaults.
   - [ ] Preserve unknown fields on write.

6. Testing scenarios:

   - [ ] Single-account, no `active-accounts.json` → unchanged behavior.
   - [ ] Two+ accounts for same provider:
     - Changing `active-accounts.json` switches which credentials are used.
   - [ ] Expired active account:
     - Fallback to valid account (if any).
   - [ ] Account JSON deleted externally:
     - No crash; no longer selectable/used.
   - [ ] `accountNickname` edited externally:
     - No effect on routing; only UI.

Summary: this spec reconstructs the contract implied by VibeProxy’s `AuthManager` and menu integration so your CLIProxyAPI fork can be updated independently while remaining fully compatible with the existing multi-account UI and selection behavior.