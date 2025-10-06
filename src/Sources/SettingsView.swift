import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var serverManager: ServerManager
    @StateObject private var authManager = AuthManager()
    @State private var launchAtLogin = false
    @State private var isAuthenticatingClaude = false
    @State private var isAuthenticatingCodex = false
    @State private var showingAuthResult = false
    @State private var authResultMessage = ""
    @State private var authResultSuccess = false
    @State private var fileMonitor: DispatchSourceFileSystemObject?

    // Get app version from Info.plist
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return "v\(version)"
        }
        return ""
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
                HStack {
                    if let resourcePath = Bundle.main.resourcePath {
                        let imagePath = (resourcePath as NSString).appendingPathComponent("icon-codex.png")
                        if let nsImage = NSImage(contentsOfFile: imagePath) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .renderingMode(.template)
                                .frame(width: 20, height: 20)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Codex")
                        if authManager.codexStatus.isAuthenticated {
                            Text(authManager.codexStatus.email ?? "Connected")
                                .font(.caption2)
                                .foregroundColor(authManager.codexStatus.isExpired ? .red : .green)
                            if authManager.codexStatus.isExpired {
                                Text("(expired)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    Spacer()
                    if isAuthenticatingCodex {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        if authManager.codexStatus.isAuthenticated {
                            if authManager.codexStatus.isExpired {
                                Button("Reconnect") {
                                    connectCodex()
                                }
                            } else {
                                Button("Disconnect") {
                                    disconnectCodex()
                                }
                            }
                        } else {
                            Button("Connect") {
                                connectCodex()
                            }
                        }
                    }
                }

                HStack {
                    if let resourcePath = Bundle.main.resourcePath {
                        let imagePath = (resourcePath as NSString).appendingPathComponent("icon-claude.png")
                        if let nsImage = NSImage(contentsOfFile: imagePath) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .renderingMode(.template)
                                .frame(width: 20, height: 20)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Claude Code")
                        if authManager.claudeStatus.isAuthenticated {
                            Text(authManager.claudeStatus.email ?? "Connected")
                                .font(.caption2)
                                .foregroundColor(authManager.claudeStatus.isExpired ? .red : .green)
                            if authManager.claudeStatus.isExpired {
                                Text("(expired)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    Spacer()
                    if isAuthenticatingClaude {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        if authManager.claudeStatus.isAuthenticated {
                            if authManager.claudeStatus.isExpired {
                                Button("Reconnect") {
                                    connectClaudeCode()
                                }
                            } else {
                                Button("Disconnect") {
                                    disconnectClaudeCode()
                                }
                            }
                        } else {
                            Button("Connect") {
                                connectClaudeCode()
                            }
                        }
                    }
                }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

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
        .frame(width: 480, height: 380)
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
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")

        // Stop server before modifying auth files
        let wasRunning = serverManager.isRunning
        if wasRunning {
            serverManager.stop()
            Thread.sleep(forTimeInterval: 0.5)
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: authDir, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let type = json["type"] as? String,
                   type.lowercased() == "claude" {
                    // Actually delete the file (not rename)
                    try FileManager.default.removeItem(at: file)
                    NSLog("[Disconnect] Deleted auth file: %@", file.path)

                    // Restart server if it was running
                    if wasRunning {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            serverManager.start { _ in }
                        }
                    }

                    authResultMessage = "Claude Code disconnected successfully"
                    showingAuthResult = true
                    break
                }
            }
        } catch {
            authResultMessage = "Failed to disconnect: \(error.localizedDescription)"
            showingAuthResult = true

            // Restart server if it was running
            if wasRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    serverManager.start { _ in }
                }
            }
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
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")

        // Stop server before modifying auth files
        let wasRunning = serverManager.isRunning
        if wasRunning {
            serverManager.stop()
            Thread.sleep(forTimeInterval: 0.5)
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: authDir, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let type = json["type"] as? String,
                   type.lowercased() == "codex" {
                    // Actually delete the file (not rename)
                    try FileManager.default.removeItem(at: file)
                    NSLog("[Disconnect] Deleted auth file: %@", file.path)

                    // Restart server if it was running
                    if wasRunning {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            serverManager.start { _ in }
                        }
                    }

                    authResultMessage = "Codex disconnected successfully"
                    showingAuthResult = true
                    break
                }
            }
        } catch {
            authResultMessage = "Failed to disconnect: \(error.localizedDescription)"
            showingAuthResult = true

            // Restart server if it was running
            if wasRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    serverManager.start { _ in }
                }
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
}

// Make managers observable
extension ServerManager: ObservableObject {}
