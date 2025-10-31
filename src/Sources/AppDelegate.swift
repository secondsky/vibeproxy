import Cocoa
import SwiftUI
import WebKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    weak var settingsWindow: NSWindow?
    var serverManager: ServerManager!
    var thinkingProxy: ThinkingProxy!
    var authManager: AuthManager!
    private let notificationCenter = UNUserNotificationCenter.current()
    private var notificationPermissionGranted = false
    private var authDirMonitor: DispatchSourceFileSystemObject?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize managers
        serverManager = ServerManager()
        thinkingProxy = ThinkingProxy()
        authManager = AuthManager()
        authManager.checkAuthStatus()
        
        // Warm commonly used icons to avoid first-use disk hits
        preloadIcons()
        
        configureNotifications()

        // Start watching auth directory for live updates
        startMonitoringAuthDirectory()

        // Setup menu bar (after managers exist)
        setupMenuBar()

        // Start server automatically
        startServer()

        // Register for notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuBarStatus),
            name: NSNotification.Name("ServerStatusChanged"),
            object: nil
        )
    }
    
    private func preloadIcons() {
        let statusIconSize = NSSize(width: 18, height: 18)
        let serviceIconSize = NSSize(width: 20, height: 20)
        
        let iconsToPreload = [
            ("icon-active.png", statusIconSize),
            ("icon-inactive.png", statusIconSize),
            ("icon-codex.png", serviceIconSize),
            ("icon-claude.png", serviceIconSize),
            ("icon-gemini.png", serviceIconSize),
            ("icon-qwen.png", serviceIconSize)
        ]
        
        for (name, size) in iconsToPreload {
            if IconCatalog.shared.image(named: name, resizedTo: size, template: true) == nil {
                NSLog("[IconPreload] Warning: Failed to preload icon '%@'", name)
            }
        }
    }
    
    private func configureNotifications() {
        notificationCenter.delegate = self
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            if let error = error {
                NSLog("[Notifications] Authorization failed: %@", error.localizedDescription)
            }
            DispatchQueue.main.async {
                self?.notificationPermissionGranted = granted
                if !granted {
                    NSLog("[Notifications] Authorization not granted; notifications will be suppressed")
                }
            }
        }
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            if let icon = IconCatalog.shared.image(named: "icon-inactive.png", resizedTo: NSSize(width: 18, height: 18), template: true) {
                button.image = icon
            } else {
                let fallback = NSImage(systemSymbolName: "network.slash", accessibilityDescription: "VibeProxy")
                fallback?.isTemplate = true
                button.image = fallback
                NSLog("[MenuBar] Failed to load inactive icon from bundle; using fallback system icon")
            }
        }

        menu = NSMenu()
        menu.delegate = self
        rebuildMenu()
        statusItem.menu = menu
    }



    @objc func openSettings() {
        if settingsWindow == nil {
            createSettingsWindow()
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func createSettingsWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VibeProxy"
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false

        let contentView = SettingsView(serverManager: serverManager)
        window.contentView = NSHostingView(rootView: contentView)

        settingsWindow = window
    }

    func windowDidClose(_ notification: Notification) {
        if notification.object as? NSWindow === settingsWindow {
            settingsWindow = nil
        }
    }

    @objc func toggleServer() {
        if serverManager.isRunning {
            stopServer()
        } else {
            startServer()
        }
    }

    func startServer() {
        // Start the thinking proxy first (port 8317)
        thinkingProxy.start()
        
        // Poll for thinking proxy readiness with timeout
        pollForProxyReadiness(attempts: 0, maxAttempts: 60, intervalMs: 50)
    }
    
    private func pollForProxyReadiness(attempts: Int, maxAttempts: Int, intervalMs: Int) {
        // Check if proxy is running
        if thinkingProxy.isRunning {
            // Success - proceed to start backend
            serverManager.start { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        self?.updateMenuBarStatus()
                        // User always connects to 8317 (thinking proxy)
                        self?.showNotification(title: "Server Started", body: "VibeProxy is now running")
                    } else {
                        // Backend failed - stop the proxy to keep state consistent
                        self?.thinkingProxy.stop()
                        self?.showNotification(title: "Server Failed", body: "Could not start backend server on port 8318")
                    }
                }
            }
            return
        }
        
        // Check if we've exceeded timeout
        if attempts >= maxAttempts {
            DispatchQueue.main.async { [weak self] in
                // Clean up partially initialized proxy
                self?.thinkingProxy.stop()
                self?.showNotification(title: "Server Failed", body: "Could not start thinking proxy on port 8317 (timeout)")
            }
            return
        }
        
        // Schedule next poll
        let interval = Double(intervalMs) / 1000.0
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.pollForProxyReadiness(attempts: attempts + 1, maxAttempts: maxAttempts, intervalMs: intervalMs)
        }
    }

    func stopServer() {
        // Stop the thinking proxy first to stop accepting new requests
        thinkingProxy.stop()
        
        // Then stop CLIProxyAPI backend
        serverManager.stop()
        
        updateMenuBarStatus()
    }

    @objc func copyServerURL() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("http://localhost:\(thinkingProxy.proxyPort)", forType: .string)
        showNotification(title: "Copied", body: "Server URL copied to clipboard")
    }

    @objc func updateMenuBarStatus() {
        // Rebuild the menu so titles and icons reflect current state
        rebuildMenu()

        // Update status bar icon based on server status
        if let button = statusItem.button {
            let iconName = serverManager.isRunning ? "icon-active.png" : "icon-inactive.png"
            let fallbackSymbol = serverManager.isRunning ? "network" : "network.slash"
            
            if let icon = IconCatalog.shared.image(named: iconName, resizedTo: NSSize(width: 18, height: 18), template: true) {
                button.image = icon
                NSLog("[MenuBar] Loaded %@ icon from cache", serverManager.isRunning ? "active" : "inactive")
            } else {
                let fallback = NSImage(systemSymbolName: fallbackSymbol, accessibilityDescription: serverManager.isRunning ? "Running" : "Stopped")
                fallback?.isTemplate = true
                button.image = fallback
                NSLog("[MenuBar] Failed to load %@ icon; using fallback", serverManager.isRunning ? "active" : "inactive")
            }
        }
    }

    func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "io.automaze.vibeproxy.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                NSLog("[Notifications] Failed to deliver notification '%@': %@", title, error.localizedDescription)
            }
        }
    }

    @objc func quit() {
        // Stop server and wait for cleanup before quitting
        if serverManager.isRunning {
            thinkingProxy.stop()
            serverManager.stop()
        }
        // Give a moment for cleanup to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ServerStatusChanged"), object: nil)
        // Final cleanup - stop server if still running
        if serverManager.isRunning {
            thinkingProxy.stop()
            serverManager.stop()
        }
        stopMonitoringAuthDirectory()
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // If server is running, stop it first
        if serverManager.isRunning {
            thinkingProxy.stop()
            serverManager.stop()
            // Give server time to stop (up to 3 seconds total with the improved stop method)
            return .terminateNow
        }
        return .terminateNow
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // MARK: - NSMenuDelegate
    func menuWillOpen(_ menu: NSMenu) {
        // Refresh auth statuses and rebuild right before showing
        authManager.checkAuthStatus()
        rebuildMenu()
    }

    // MARK: - Menu construction & helpers
    private func rebuildMenu() {
        menu.removeAllItems()

        // Server status row
        let statusTitle = serverManager.isRunning ? "Server: Running (port \(thinkingProxy.proxyPort))" : "Server: Stopped"
        let serverStatusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        serverStatusItem.image = symbolImage(serverManager.isRunning ? "antenna.radiowaves.left.and.right" : "wifi.slash", size: 16)
        menu.addItem(serverStatusItem)
        menu.addItem(NSMenuItem.separator())

        // Accounts section (flat in main menu; only providers with accounts)
        if appendAccountsSection() {
            menu.addItem(NSMenuItem.separator())
        }

        // Open Settings
        let settingsItem = NSMenuItem(title: "Open Settings", action: #selector(openSettings), keyEquivalent: "s")
        settingsItem.image = symbolImage("gearshape", size: 16)
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())

        // Start/Stop
        let startStopTitle = serverManager.isRunning ? "Stop Server" : "Start Server"
        let startStopSymbol = serverManager.isRunning ? "stop.circle" : "play.circle"
        let startStopItem = NSMenuItem(title: startStopTitle, action: #selector(toggleServer), keyEquivalent: "")
        startStopItem.tag = 100
        startStopItem.image = symbolImage(startStopSymbol, size: 16)
        menu.addItem(startStopItem)
        menu.addItem(NSMenuItem.separator())

        // Copy URL
        let copyURLItem = NSMenuItem(title: "Copy Server URL", action: #selector(copyServerURL), keyEquivalent: "c")
        copyURLItem.isEnabled = serverManager.isRunning
        copyURLItem.tag = 102
        copyURLItem.image = symbolImage("doc.on.doc", size: 16)
        menu.addItem(copyURLItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.image = symbolImage("xmark.circle", size: 16)
        menu.addItem(quitItem)
    }

    private func appendAccountsSection() -> Bool {
        // Providers with configured accounts; hide providers with zero accounts
        let providers: [(display: String, key: String, icon: String, status: ProviderAuthStatus)] = [
            ("Claude Code", "claude", "icon-claude.png", authManager.claudeStatus),
            ("Codex", "codex", "icon-codex.png", authManager.codexStatus),
            ("Gemini", "gemini", "icon-gemini.png", authManager.geminiStatus),
            ("Qwen", "qwen", "icon-qwen.png", authManager.qwenStatus)
        ].filter { $0.status.hasAnyAccount }

        guard !providers.isEmpty else { return false }

        // Section header
        let header = NSMenuItem(title: "Accounts", action: nil, keyEquivalent: "")
        header.image = symbolImage("person.2", size: 16)
        header.isEnabled = false
        menu.addItem(header)

        // Provider groups
        for (idx, provider) in providers.enumerated() {
            let providerLabel = NSMenuItem(title: provider.display, action: nil, keyEquivalent: "")
            if let pIcon = IconCatalog.shared.image(named: provider.icon, resizedTo: NSSize(width: 16, height: 16), template: true) {
                providerLabel.image = pIcon
            }
            providerLabel.indentationLevel = 0
            providerLabel.isEnabled = false
            menu.addItem(providerLabel)

            for account in provider.status.accounts {
                let item = NSMenuItem(title: account.nickname, action: #selector(selectAccount(_:)), keyEquivalent: "")
                item.state = (provider.status.activeAccount?.id == account.id) ? .on : .off
                item.representedObject = ["provider": provider.key, "accountId": account.id]
                item.indentationLevel = 0
                // Ensure consistent state column spacing across providers
                item.offStateImage = transparentStatePlaceholder
                // Occupy the image column to avoid extra gap after the checkmark
                if let aIcon = IconCatalog.shared.image(named: provider.icon, resizedTo: NSSize(width: 16, height: 16), template: true) {
                    item.image = aIcon
                }
                menu.addItem(item)
            }

            // Thin separation between providers
            if idx < providers.count - 1 {
                menu.addItem(NSMenuItem.separator())
            }
        }

        return true
    }

    // Transparent placeholder image to normalize state column width
    private lazy var transparentStatePlaceholder: NSImage = {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }()

    private func symbolImage(_ name: String, size: CGFloat = 16, weight: NSFont.Weight = .regular) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
        let img = NSImage(systemSymbolName: name, accessibilityDescription: name)?.withSymbolConfiguration(config)
        img?.isTemplate = true
        return img
    }

    @objc private func selectAccount(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? [String: String],
              let provider = payload["provider"],
              let accountId = payload["accountId"] else { return }
        authManager.setActiveAccount(provider: provider, accountId: accountId)
        rebuildMenu()
        showNotification(title: "Active Account Changed", body: "\(provider.capitalized) → \(sender.title)")
    }

    // MARK: - Auth directory monitoring
    private func startMonitoringAuthDirectory() {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
        try? FileManager.default.createDirectory(at: authDir, withIntermediateDirectories: true)

        let fd = open(authDir.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .delete, .rename], queue: DispatchQueue.main)
        source.setEventHandler { [weak self] in
            self?.authManager.checkAuthStatus()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        authDirMonitor = source
    }

    private func stopMonitoringAuthDirectory() {
        authDirMonitor?.cancel()
        authDirMonitor = nil
    }
}
