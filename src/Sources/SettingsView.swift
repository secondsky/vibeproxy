import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var serverManager: ServerManager
    @StateObject private var authManager = AuthManager()
    @State private var launchAtLogin = false
    @State private var isAuthenticatingClaude = false
    @State private var isAuthenticatingCodex = false
    @State private var isAuthenticatingGemini = false
    @State private var isAuthenticatingQwen = false
    @State private var showingAuthResult = false
    @State private var authResultMessage = ""
    @State private var authResultSuccess = false
    @State private var fileMonitor: DispatchSourceFileSystemObject?
    @State private var showingQwenEmailPrompt = false
    @State private var qwenEmail = ""
    @State private var editingAccountId: String?
    @State private var editingNickname: String = ""
    @State private var editingProvider: String = ""
    @State private var showingNicknameEditor = false
    @State private var nicknameEditorError: String? = nil
    @State private var accountToDelete: (provider: String, accountId: String)?
    @State private var showingDeleteConfirmation = false
    @State private var accountToReplace: (provider: String, accountId: String)?
    @State private var showingReplaceAccountDialog = false
    
    private enum DisconnectTiming {
        static let serverRestartDelay: TimeInterval = 0.3
    }

    // Get app version from Info.plist
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return "v\(version)"
        }
        return ""
    }
    
    // Helper to render provider section with multi-account support
    @ViewBuilder
    private func providerSection(
        iconName: String,
        providerName: String,
        providerType: String,
        status: ProviderAuthStatus,
        isAuthenticating: Bool,
        connectAction: @escaping () -> Void,
        helpText: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Provider header
            HStack(spacing: 8) {
                if let nsImage = IconCatalog.shared.image(named: iconName, resizedTo: NSSize(width: 20, height: 20), template: true) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 20, height: 20)
                }
                Text(providerName)
                    .font(.headline)
                Spacer()
                if isAuthenticating {
                    ProgressView()
                        .controlSize(.small)
                } else if !status.hasAnyAccount {
                    Button("Connect") {
                        connectAction()
                    }
                }
            }
            
            // Account list
            if status.hasAnyAccount {
                ForEach(status.accounts) { account in
                    accountCard(
                        account: account,
                        providerType: providerType,
                        isActive: status.activeAccountId == account.id,
                        isAuthenticating: isAuthenticating
                    )
                }
                
                // Add another account button
                if !isAuthenticating {
                    Button(action: connectAction) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                            Text("Add Another Account")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .padding(.leading, 28)
                }
            }
        }
        .padding(.vertical, 4)
        .help(helpText ?? "")
    }
    
    // Individual account card
    @ViewBuilder
    private func accountCard(account: AuthAccount, providerType: String, isActive: Bool, isAuthenticating: Bool) -> some View {
        HStack(spacing: 12) {
            // Active indicator (radio button)
            Button(action: {
                authManager.setActiveAccount(provider: providerType, accountId: account.id)
            }) {
                Image(systemName: isActive ? "circle.inset.filled" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isActive ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(isAuthenticating)
            .help("Mark as primary account (Note: All accounts are used for automatic load balancing)")
            
            // Account info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(account.nickname)
                        .font(.subheadline)
                        .fontWeight(isActive ? .semibold : .regular)
                    
                    if account.isExpired {
                        Text("(expired)")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                
                if let email = account.email {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                if account.isExpired {
                    Button("Replace Account") {
                        accountToReplace = (provider: providerType, accountId: account.id)
                        showingReplaceAccountDialog = true
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .disabled(isAuthenticating)
                }
                
                Menu {
                    Button("Rename") {
                        startEditingNickname(provider: providerType, account: account)
                    }
                    Divider()
                    Button("Remove", role: .destructive) {
                        accountToDelete = (provider: providerType, accountId: account.id)
                        showingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .disabled(isAuthenticating)
            }
        }
        .padding(.leading, 28)
        .padding(.vertical, 4)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    HStack {
                        Text("Server status")
                        Spacer()
                        Button(action: {
                            if serverManager.isRunning {
                                serverManager.stop()
                            } else {
                                serverManager.start { _ in }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(serverManager.isRunning ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                Text(serverManager.isRunning ? "Running" : "Stopped")
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { newValue in
                            toggleLaunchAtLogin(newValue)
                        }

                    HStack {
                        Text("Auth files")
                        Spacer()
                        Button("Open Folder") {
                            openAuthFolder()
                        }
                    }
                }

                Section("Services") {
                    providerSection(
                        iconName: "icon-claude.png",
                        providerName: "Claude Code",
                        providerType: "claude",
                        status: authManager.claudeStatus,
                        isAuthenticating: isAuthenticatingClaude,
                        connectAction: connectClaudeCode
                    )
                    
                    Divider()
                    
                    providerSection(
                        iconName: "icon-codex.png",
                        providerName: "Codex",
                        providerType: "codex",
                        status: authManager.codexStatus,
                        isAuthenticating: isAuthenticatingCodex,
                        connectAction: connectCodex
                    )
                    
                    Divider()
                    
                    providerSection(
                        iconName: "icon-gemini.png",
                        providerName: "Gemini",
                        providerType: "gemini",
                        status: authManager.geminiStatus,
                        isAuthenticating: isAuthenticatingGemini,
                        connectAction: connectGemini,
                        helpText: "⚠️ Note: If you're an existing Gemini user with multiple projects, authentication will use your default project. Set your desired project as default in Google AI Studio before connecting."
                    )
                    
                    Divider()
                    
                    providerSection(
                        iconName: "icon-qwen.png",
                        providerName: "Qwen",
                        providerType: "qwen",
                        status: authManager.qwenStatus,
                        isAuthenticating: isAuthenticatingQwen,
                        connectAction: connectQwen
                    )
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(false)  // Allow scrolling when many accounts exist

            Spacer()
                .frame(height: 12)

            // Footer outside Form
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("VibeProxy \(appVersion) was made possible thanks to")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Link("CLIProxyAPI", destination: URL(string: "https://github.com/router-for-me/CLIProxyAPI")!)
                        .font(.caption)
                        .underline()
                        .foregroundColor(.secondary)
                        .onHover { inside in
                            if inside {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    Text("|")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("License: MIT")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Text("© 2025")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Link("Automaze, Ltd.", destination: URL(string: "https://automaze.io")!)
                        .font(.caption)
                        .underline()
                        .foregroundColor(.secondary)
                        .onHover { inside in
                            if inside {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    Text("All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Link("Report an issue", destination: URL(string: "https://github.com/automazeio/vibeproxy/issues")!)
                    .font(.caption)
                    .onHover { inside in
                        if inside {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
            }
            .padding(.bottom, 12)
        }
        .frame(width: 480, height: 490)
        .sheet(isPresented: $showingQwenEmailPrompt) {
            VStack(spacing: 16) {
                Text("Qwen Account Email")
                    .font(.headline)
                Text("Enter your Qwen account email address")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("your.email@example.com", text: $qwenEmail)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showingQwenEmailPrompt = false
                        qwenEmail = ""
                    }
                    Button("Continue") {
                        showingQwenEmailPrompt = false
                        startQwenAuth(email: qwenEmail)
                    }
                    .disabled(qwenEmail.isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 350)
        }
        .sheet(isPresented: $showingNicknameEditor) {
            VStack(spacing: 16) {
                Text("Rename Account")
                    .font(.headline)
                Text("Enter a new nickname for this account")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Account nickname", text: $editingNickname)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                    .onChange(of: editingNickname) { _ in
                        // Clear error when user starts typing
                        nicknameEditorError = nil
                    }
                
                // Show inline error if present
                if let error = nicknameEditorError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: 250)
                }
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showingNicknameEditor = false
                        nicknameEditorError = nil
                    }
                    Button("Save") {
                        saveNickname()
                    }
                    .disabled(editingNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 350)
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                accountToDelete = nil
            }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Are you sure you want to remove this account? This action cannot be undone.")
        }
        .alert("Replace Expired Account", isPresented: $showingReplaceAccountDialog) {
            Button("Cancel", role: .cancel) {
                accountToReplace = nil
            }
            Button("Just Remove", role: .destructive) {
                deleteAccountOnly()
            }
            Button("Remove & Add New") {
                replaceAccount()
            }
        } message: {
            Text("This will delete this expired account and optionally create a new one.\n\nExpired accounts are unusable. This action is safe.")
        }
        .onAppear {
            authManager.checkAuthStatus()
            checkLaunchAtLogin()
            startMonitoringAuthDirectory()
        }
        .onDisappear {
            stopMonitoringAuthDirectory()
        }
        .alert("Authentication Result", isPresented: $showingAuthResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authResultMessage)
        }
    }

    private func openAuthFolder() {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
        NSWorkspace.shared.open(authDir)
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to toggle launch at login: \(error)")
            }
        }
    }

    private func checkLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func connectClaudeCode() {
        isAuthenticatingClaude = true
        NSLog("[SettingsView] Starting Claude Code authentication")

        serverManager.runAuthCommand(.claudeLogin) { success, output in
            NSLog("[SettingsView] Auth completed - success: %d, output: %@", success, output)
            DispatchQueue.main.async {
                self.isAuthenticatingClaude = false

                if success {
                    self.authResultSuccess = true
                    self.authResultMessage = "✓ Claude Code authenticated successfully!\n\nPlease complete the authentication in your browser, then the app will automatically detect your credentials."
                    self.showingAuthResult = true
                    // File monitor will automatically update the status
                } else {
                    self.authResultSuccess = false
                    self.authResultMessage = "Authentication failed. Please check if the browser opened and try again.\n\nDetails: \(output.isEmpty ? "No output from authentication process" : output)"
                    self.showingAuthResult = true
                }
            }
        }
    }

    private func disconnectClaudeCode() {
        isAuthenticatingClaude = true
        performDisconnect(for: "claude", serviceName: "Claude Code") { success, message in
            self.isAuthenticatingClaude = false
            self.authResultSuccess = success
            self.authResultMessage = message
            self.showingAuthResult = true
        }
    }

    private func connectCodex() {
        isAuthenticatingCodex = true
        NSLog("[SettingsView] Starting Codex authentication")

        serverManager.runAuthCommand(.codexLogin) { success, output in
            NSLog("[SettingsView] Auth completed - success: %d, output: %@", success, output)
            DispatchQueue.main.async {
                self.isAuthenticatingCodex = false

                if success {
                    self.authResultSuccess = true
                    self.authResultMessage = "✓ Codex authenticated successfully!\n\nPlease complete the authentication in your browser, then the app will automatically detect your credentials."
                    self.showingAuthResult = true
                    // File monitor will automatically update the status
                } else {
                    self.authResultSuccess = false
                    self.authResultMessage = "Authentication failed. Please check if the browser opened and try again.\n\nDetails: \(output.isEmpty ? "No output from authentication process" : output)"
                    self.showingAuthResult = true
                }
            }
        }
    }

    private func disconnectCodex() {
        isAuthenticatingCodex = true
        performDisconnect(for: "codex", serviceName: "Codex") { success, message in
            self.isAuthenticatingCodex = false
            self.authResultSuccess = success
            self.authResultMessage = message
            self.showingAuthResult = true
        }
    }

    private func connectGemini() {
        isAuthenticatingGemini = true
        NSLog("[SettingsView] Starting Gemini authentication")

        serverManager.runAuthCommand(.geminiLogin) { success, output in
            NSLog("[SettingsView] Auth completed - success: %d, output: %@", success, output)
            DispatchQueue.main.async {
                self.isAuthenticatingGemini = false

                if success {
                    self.authResultSuccess = true
                    self.authResultMessage = "✓ Gemini authenticated successfully!\n\nPlease complete the authentication in your browser, then the app will automatically detect your credentials.\n\n⚠️ Note: If you have multiple Gemini projects, the default project will be used. You can change your default project in Google AI Studio if needed."
                    self.showingAuthResult = true
                    // File monitor will automatically update the status
                } else {
                    self.authResultSuccess = false
                    self.authResultMessage = "Authentication failed. Please check if the browser opened and try again.\n\nDetails: \(output.isEmpty ? "No output from authentication process" : output)"
                    self.showingAuthResult = true
                }
            }
        }
    }

    private func disconnectGemini() {
        isAuthenticatingGemini = true
        performDisconnect(for: "gemini", serviceName: "Gemini") { success, message in
            self.isAuthenticatingGemini = false
            self.authResultSuccess = success
            self.authResultMessage = message
            self.showingAuthResult = true
        }
    }

    private func connectQwen() {
        showingQwenEmailPrompt = true
    }

    private func startQwenAuth(email: String) {
        isAuthenticatingQwen = true
        NSLog("[SettingsView] Starting Qwen authentication with email: %@", email)

        serverManager.runAuthCommand(.qwenLogin(email: email)) { success, output in
            NSLog("[SettingsView] Auth completed - success: %d, output: %@", success, output)
            DispatchQueue.main.async {
                self.isAuthenticatingQwen = false

                if success {
                    self.authResultSuccess = true
                    self.authResultMessage = "✓ Qwen authenticated successfully!\n\nPlease complete the authentication in your browser, then the app will automatically submit your email and detect your credentials."
                    self.showingAuthResult = true
                    // File monitor will automatically update the status
                } else {
                    self.authResultSuccess = false
                    self.authResultMessage = "Authentication failed. Please check if the browser opened and try again.\n\nDetails: \(output.isEmpty ? "No output from authentication process" : output)"
                    self.showingAuthResult = true
                }
            }
        }
    }

    private func disconnectQwen() {
        isAuthenticatingQwen = true
        performDisconnect(for: "qwen", serviceName: "Qwen") { success, message in
            self.isAuthenticatingQwen = false
            self.authResultSuccess = success
            self.authResultMessage = message
            self.showingAuthResult = true
        }
    }

    // Delete account only (without adding new one)
    private func deleteAccountOnly() {
        guard let account = accountToReplace else { return }
        
        authManager.deleteAccount(provider: account.provider, accountId: account.accountId) { success, message in
            DispatchQueue.main.async {
                self.accountToReplace = nil
                
                if !success {
                    self.authResultSuccess = false
                    self.authResultMessage = message
                    self.showingAuthResult = true
                }
            }
        }
    }
    
    // Replace expired account (delete then add new)
    private func replaceAccount() {
        guard let account = accountToReplace else { return }
        
        authManager.deleteAccount(provider: account.provider, accountId: account.accountId) { success, message in
            DispatchQueue.main.async {
                self.accountToReplace = nil
                
                if success {
                    // Trigger OAuth for new account
                    switch account.provider.lowercased() {
                    case "claude":
                        self.connectClaudeCode()
                    case "codex":
                        self.connectCodex()
                    case "gemini":
                        self.connectGemini()
                    case "qwen":
                        self.connectQwen()
                    default:
                        break
                    }
                } else {
                    self.authResultSuccess = false
                    self.authResultMessage = message
                    self.showingAuthResult = true
                }
            }
        }
    }
    
    // Start editing account nickname
    private func startEditingNickname(provider: String, account: AuthAccount) {
        editingProvider = provider
        editingAccountId = account.id
        editingNickname = account.nickname
        showingNicknameEditor = true
    }
    
    // Save edited nickname
    private func saveNickname() {
        guard let accountId = editingAccountId else { return }
        
        let trimmedNickname = editingNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNickname.isEmpty else {
            nicknameEditorError = "Nickname cannot be empty"
            return
        }
        
        // Clear any previous errors
        nicknameEditorError = nil
        
        authManager.updateAccountNickname(
            provider: editingProvider,
            accountId: accountId,
            nickname: trimmedNickname
        ) { success, message in
            DispatchQueue.main.async {
                if success {
                    self.showingNicknameEditor = false
                } else {
                    // Show error inline in the sheet
                    self.nicknameEditorError = message
                }
            }
        }
    }
    
    // Perform account deletion
    private func deleteAccount() {
        guard let accountInfo = accountToDelete else { return }
        
        authManager.deleteAccount(
            provider: accountInfo.provider,
            accountId: accountInfo.accountId
        ) { success, message in
            DispatchQueue.main.async {
                self.accountToDelete = nil
                self.authResultSuccess = success
                self.authResultMessage = message
                self.showingAuthResult = true
            }
        }
    }

    private func startMonitoringAuthDirectory() {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: authDir, withIntermediateDirectories: true)

        let fileDescriptor = open(authDir.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.main
        )

        let manager = authManager
        source.setEventHandler {
            // Refresh auth status when directory changes
            NSLog("[FileMonitor] Auth directory changed - refreshing status")
            manager.checkAuthStatus()
        }

        source.setCancelHandler {
            close(fileDescriptor)
        }

        source.resume()
        fileMonitor = source
    }

    private func stopMonitoringAuthDirectory() {
        fileMonitor?.cancel()
        fileMonitor = nil
    }

    private func performDisconnect(for serviceType: String, serviceName: String, completion: @escaping (Bool, String) -> Void) {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
        let wasRunning = serverManager.isRunning
        let manager = serverManager

        let cleanupWork: () -> Void = {
            DispatchQueue.global(qos: .userInitiated).async {
                var disconnectResult: (Bool, String)
                
                do {
                    if let enumerator = FileManager.default.enumerator(
                        at: authDir,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles]
                    ) {
                        var targetURL: URL?
                        
                        for case let fileURL as URL in enumerator {
                            guard fileURL.pathExtension == "json" else { continue }
                            
                            let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
                            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                  let type = json["type"] as? String,
                                  type.lowercased() == serviceType.lowercased() else {
                                continue
                            }
                            
                            targetURL = fileURL
                            break
                        }
                        
                        if let targetURL = targetURL {
                            try FileManager.default.removeItem(at: targetURL)
                            NSLog("[Disconnect] Deleted auth file: %@", targetURL.path)
                            disconnectResult = (true, "\(serviceName) disconnected successfully")
                        } else {
                            disconnectResult = (false, "No \(serviceName) credentials were found.")
                        }
                    } else {
                        disconnectResult = (false, "Unable to access credentials directory.")
                    }
                } catch {
                    disconnectResult = (false, "Failed to disconnect \(serviceName): \(error.localizedDescription)")
                }
                
                DispatchQueue.main.async {
                    completion(disconnectResult.0, disconnectResult.1)
                    if wasRunning {
                        DispatchQueue.main.asyncAfter(deadline: .now() + DisconnectTiming.serverRestartDelay) {
                            manager.start { _ in }
                        }
                    }
                }
            }
        }

        if wasRunning {
            serverManager.stop {
                cleanupWork()
            }
        } else {
            cleanupWork()
        }
    }
}

// Make managers observable
extension ServerManager: ObservableObject {}
