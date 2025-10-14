import Foundation

struct AuthStatus {
    var isAuthenticated: Bool
    var email: String?
    var type: String
    var expired: Date?
    
    var isExpired: Bool {
        guard let expired = expired else { return false }
        return expired < Date()
    }
    
    var statusText: String {
        if !isAuthenticated {
            return "Not Connected"
        } else if isExpired {
            return "Expired - Reconnect Required"
        } else if let email = email {
            return "Connected as \(email)"
        } else {
            return "Connected"
        }
    }
}

class AuthManager: ObservableObject {
    @Published var claudeStatus = AuthStatus(isAuthenticated: false, type: "claude")
    @Published var codexStatus = AuthStatus(isAuthenticated: false, type: "codex")
    @Published var geminiStatus = AuthStatus(isAuthenticated: false, type: "gemini")
    
    func checkAuthStatus() {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
        
        // Reset statuses first
        var foundClaude = false
        var foundCodex = false
        var foundGemini = false
        
        // Check for auth files
        do {
            let files = try FileManager.default.contentsOfDirectory(at: authDir, includingPropertiesForKeys: nil)
            
            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let type = json["type"] as? String {
                    
                    let email = json["email"] as? String
                    var expiredDate: Date?
                    
                    if let expiredStr = json["expired"] as? String {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        expiredDate = formatter.date(from: expiredStr)
                    }
                    
                    let status = AuthStatus(
                        isAuthenticated: true,
                        email: email,
                        type: type,
                        expired: expiredDate
                    )
                    
                    DispatchQueue.main.async {
                        switch type.lowercased() {
                        case "claude":
                            foundClaude = true
                            self.claudeStatus = status
                            NSLog("[AuthStatus] Found Claude auth: %@", email ?? "unknown")
                        case "codex":
                            foundCodex = true
                            self.codexStatus = status
                            NSLog("[AuthStatus] Found Codex auth: %@", email ?? "unknown")
                        case "gemini":
                            foundGemini = true
                            self.geminiStatus = status
                            NSLog("[AuthStatus] Found Gemini auth: %@", email ?? "unknown")
                        default:
                            break
                        }
                    }
                }
            }
            
            // Reset statuses for services without auth files
            DispatchQueue.main.async {
                if !foundClaude {
                    NSLog("[AuthStatus] No Claude auth file found - resetting status")
                    self.claudeStatus = AuthStatus(isAuthenticated: false, type: "claude")
                }
                if !foundCodex {
                    NSLog("[AuthStatus] No Codex auth file found - resetting status")
                    self.codexStatus = AuthStatus(isAuthenticated: false, type: "codex")
                }
                if !foundGemini {
                    NSLog("[AuthStatus] No Gemini auth file found - resetting status")
                    self.geminiStatus = AuthStatus(isAuthenticated: false, type: "gemini")
                }
            }
        } catch {
            NSLog("[AuthStatus] Error checking auth status: %@", error.localizedDescription)
            // Reset all on error
            DispatchQueue.main.async {
                self.claudeStatus = AuthStatus(isAuthenticated: false, type: "claude")
                self.codexStatus = AuthStatus(isAuthenticated: false, type: "codex")
                self.geminiStatus = AuthStatus(isAuthenticated: false, type: "gemini")
            }
        }
    }
}
