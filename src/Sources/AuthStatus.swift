import Foundation

// Individual account within a provider
struct AuthAccount: Identifiable, Codable, Equatable {
    let id: String  // Unique account ID (e.g., UUID or user-chosen)
    var nickname: String  // User-friendly name
    var email: String?
    var expired: Date?
    var filePath: URL
    var createdAt: Date?
    
    var isExpired: Bool {
        guard let expired = expired else { return false }
        return expired < Date()
    }
    
    var statusText: String {
        if isExpired {
            return "Expired - Reconnect Required"
        } else if let email = email {
            return email
        } else {
            return "Connected"
        }
    }
    
    static func == (lhs: AuthAccount, rhs: AuthAccount) -> Bool {
        return lhs.id == rhs.id
    }
}

// Provider-level authentication status supporting multiple accounts
struct ProviderAuthStatus {
    let providerType: String  // "claude", "codex", "gemini", "qwen"
    var accounts: [AuthAccount]
    var activeAccountId: String?  // Which account is "primary" (UI preference only)
    
    var hasAnyAccount: Bool { !accounts.isEmpty }
    
    var activeAccount: AuthAccount? {
        guard let activeId = activeAccountId else {
            return accounts.first  // Default to first if none set
        }
        return accounts.first { $0.id == activeId } ?? accounts.first
    }
    
    // Legacy compatibility: single account view
    var isAuthenticated: Bool { hasAnyAccount }
    var email: String? { activeAccount?.email }
    var isExpired: Bool { activeAccount?.isExpired ?? false }
}

class AuthManager: ObservableObject {
    @Published var claudeStatus = ProviderAuthStatus(providerType: "claude", accounts: [], activeAccountId: nil)
    @Published var codexStatus = ProviderAuthStatus(providerType: "codex", accounts: [], activeAccountId: nil)
    @Published var geminiStatus = ProviderAuthStatus(providerType: "gemini", accounts: [], activeAccountId: nil)
    @Published var qwenStatus = ProviderAuthStatus(providerType: "qwen", accounts: [], activeAccountId: nil)
    
    private let userDefaults = UserDefaults.standard
    
    private func activeAccountKey(for provider: String) -> String {
        return "activeAccount.\(provider)"
    }
    
    func checkAuthStatus() {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
        
        // Temporary storage for accounts by provider
        var claudeAccounts: [AuthAccount] = []
        var codexAccounts: [AuthAccount] = []
        var geminiAccounts: [AuthAccount] = []
        var qwenAccounts: [AuthAccount] = []
        
        // Check for auth files
        do {
            let files = try FileManager.default.contentsOfDirectory(at: authDir, includingPropertiesForKeys: nil)
            NSLog("[AuthStatus] Scanning %d files in auth directory", files.count)
            
            for file in files where file.pathExtension == "json" {
                NSLog("[AuthStatus] Checking file: %@", file.lastPathComponent)
                if let data = try? Data(contentsOf: file),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let type = json["type"] as? String {
                    NSLog("[AuthStatus] Found type '%@' in %@", type, file.lastPathComponent)
                    
                    let email = json["email"] as? String
                    var expiredDate: Date?
                    
                    if let expiredStr = json["expired"] as? String {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        expiredDate = formatter.date(from: expiredStr)
                    }
                    
                    // Extract account metadata
                    let accountId = json["accountId"] as? String ?? extractAccountIdFromFilename(file.lastPathComponent, type: type)
                    let nickname = json["accountNickname"] as? String ?? generateDefaultNickname(email: email)
                    
                    var createdAt: Date?
                    if let createdAtStr = json["createdAt"] as? String {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        createdAt = formatter.date(from: createdAtStr)
                    }
                    
                    let account = AuthAccount(
                        id: accountId,
                        nickname: nickname,
                        email: email,
                        expired: expiredDate,
                        filePath: file,
                        createdAt: createdAt
                    )
                    
                    // Group by provider type
                    switch type.lowercased() {
                    case "claude":
                        claudeAccounts.append(account)
                        NSLog("[AuthStatus] Found Claude account: %@ (%@)", email ?? "unknown", nickname)
                    case "codex":
                        codexAccounts.append(account)
                        NSLog("[AuthStatus] Found Codex account: %@ (%@)", email ?? "unknown", nickname)
                    case "gemini":
                        geminiAccounts.append(account)
                        NSLog("[AuthStatus] Found Gemini account: %@ (%@)", email ?? "unknown", nickname)
                    case "qwen":
                        qwenAccounts.append(account)
                        NSLog("[AuthStatus] Found Qwen account: %@ (%@)", email ?? "unknown", nickname)
                    default:
                        break
                    }
                }
            }
            
            // Update statuses on main thread
            DispatchQueue.main.async {
                // Load active account preferences
                let claudeActiveId = self.userDefaults.string(forKey: self.activeAccountKey(for: "claude"))
                let codexActiveId = self.userDefaults.string(forKey: self.activeAccountKey(for: "codex"))
                let geminiActiveId = self.userDefaults.string(forKey: self.activeAccountKey(for: "gemini"))
                let qwenActiveId = self.userDefaults.string(forKey: self.activeAccountKey(for: "qwen"))
                
                self.claudeStatus = ProviderAuthStatus(
                    providerType: "claude",
                    accounts: claudeAccounts,
                    activeAccountId: claudeActiveId
                )
                self.codexStatus = ProviderAuthStatus(
                    providerType: "codex",
                    accounts: codexAccounts,
                    activeAccountId: codexActiveId
                )
                self.geminiStatus = ProviderAuthStatus(
                    providerType: "gemini",
                    accounts: geminiAccounts,
                    activeAccountId: geminiActiveId
                )
                self.qwenStatus = ProviderAuthStatus(
                    providerType: "qwen",
                    accounts: qwenAccounts,
                    activeAccountId: qwenActiveId
                )
                
                NSLog("[AuthStatus] Updated statuses - Claude: %d, Codex: %d, Gemini: %d, Qwen: %d",
                      claudeAccounts.count, codexAccounts.count, geminiAccounts.count, qwenAccounts.count)
            }
        } catch {
            NSLog("[AuthStatus] Error checking auth status: %@", error.localizedDescription)
            // Reset all on error
            DispatchQueue.main.async {
                self.claudeStatus = ProviderAuthStatus(providerType: "claude", accounts: [], activeAccountId: nil)
                self.codexStatus = ProviderAuthStatus(providerType: "codex", accounts: [], activeAccountId: nil)
                self.geminiStatus = ProviderAuthStatus(providerType: "gemini", accounts: [], activeAccountId: nil)
                self.qwenStatus = ProviderAuthStatus(providerType: "qwen", accounts: [], activeAccountId: nil)
            }
        }
    }
    
    // Extract account ID from filename (supports both old and new formats)
    private func extractAccountIdFromFilename(_ filename: String, type: String) -> String {
        let baseName = filename.replacingOccurrences(of: ".json", with: "")
        
        // New format: provider-accountId.json (e.g., "claude-abc123.json")
        if baseName.hasPrefix("\(type)-") {
            let accountId = baseName.replacingOccurrences(of: "\(type)-", with: "")
            return accountId.isEmpty ? UUID().uuidString : accountId
        }
        
        // Old format: random UUID.json - use as-is for migration
        return baseName.isEmpty ? UUID().uuidString : baseName
    }
    
    // Generate a default nickname from email or use a timestamp
    private func generateDefaultNickname(email: String?) -> String {
        if let email = email {
            // Use part before @ as default nickname
            let username = email.components(separatedBy: "@").first ?? "Account"
            return username
        }
        return "Account"
    }
    
    // Set the active account for a provider
    func setActiveAccount(provider: String, accountId: String) {
        userDefaults.set(accountId, forKey: activeAccountKey(for: provider))
        
        DispatchQueue.main.async {
            switch provider.lowercased() {
            case "claude":
                var status = self.claudeStatus
                status.activeAccountId = accountId
                self.claudeStatus = status
            case "codex":
                var status = self.codexStatus
                status.activeAccountId = accountId
                self.codexStatus = status
            case "gemini":
                var status = self.geminiStatus
                status.activeAccountId = accountId
                self.geminiStatus = status
            case "qwen":
                var status = self.qwenStatus
                status.activeAccountId = accountId
                self.qwenStatus = status
            default:
                break
            }
        }
        
        NSLog("[AuthManager] Set active account for %@: %@", provider, accountId)
    }
    
    // Delete a specific account
    func deleteAccount(provider: String, accountId: String, completion: @escaping (Bool, String) -> Void) {
        var accounts: [AuthAccount] = []
        
        switch provider.lowercased() {
        case "claude":
            accounts = claudeStatus.accounts
        case "codex":
            accounts = codexStatus.accounts
        case "gemini":
            accounts = geminiStatus.accounts
        case "qwen":
            accounts = qwenStatus.accounts
        default:
            completion(false, "Unknown provider: \(provider)")
            return
        }
        
        guard let account = accounts.first(where: { $0.id == accountId }) else {
            completion(false, "Account not found")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try FileManager.default.removeItem(at: account.filePath)
                NSLog("[AuthManager] Deleted account file: %@", account.filePath.path)
                
                // If this was the active account, clear the preference
                if self.userDefaults.string(forKey: self.activeAccountKey(for: provider)) == accountId {
                    self.userDefaults.removeObject(forKey: self.activeAccountKey(for: provider))
                }
                
                DispatchQueue.main.async {
                    self.checkAuthStatus()
                    completion(true, "Account deleted successfully")
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, "Failed to delete account: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Update account nickname
    func updateAccountNickname(provider: String, accountId: String, nickname: String, completion: @escaping (Bool, String) -> Void) {
        var accounts: [AuthAccount] = []
        
        switch provider.lowercased() {
        case "claude":
            accounts = claudeStatus.accounts
        case "codex":
            accounts = codexStatus.accounts
        case "gemini":
            accounts = geminiStatus.accounts
        case "qwen":
            accounts = qwenStatus.accounts
        default:
            completion(false, "Unknown provider: \(provider)")
            return
        }
        
        guard let account = accounts.first(where: { $0.id == accountId }) else {
            completion(false, "Account not found")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Read existing JSON
                let data = try Data(contentsOf: account.filePath)
                var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                
                // Update nickname
                json["accountNickname"] = nickname
                
                // Write back
                let updatedData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
                try updatedData.write(to: account.filePath)
                
                NSLog("[AuthManager] Updated nickname for account %@ to: %@", accountId, nickname)
                
                DispatchQueue.main.async {
                    self.checkAuthStatus()
                    completion(true, "Nickname updated successfully")
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, "Failed to update nickname: \(error.localizedDescription)")
                }
            }
        }
    }
}
