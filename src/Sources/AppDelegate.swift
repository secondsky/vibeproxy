import Cocoa
import SwiftUI
import WebKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var settingsWindow: NSWindow?
    var serverManager: ServerManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup menu bar
        setupMenuBar()

        // Initialize managers
        serverManager = ServerManager()

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

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Load custom icon from bundle
            if let resourcePath = Bundle.main.resourcePath {
                let iconPath = (resourcePath as NSString).appendingPathComponent("icon-inactive.png")
                if let icon = NSImage(contentsOfFile: iconPath) {
                    icon.isTemplate = true
                    // Resize to proper menu bar size (18x18 points for menu bar)
                    icon.size = NSSize(width: 18, height: 18)
                    button.image = icon
                } else {
                    NSLog("[MenuBar] Failed to load icon from: %@", iconPath)
                    // Fallback to system icon
                    button.image = NSImage(systemSymbolName: "network.slash", accessibilityDescription: "VibeProxy")
                    button.image?.isTemplate = true
                }
            } else {
                // Fallback to system icon
                button.image = NSImage(systemSymbolName: "network.slash", accessibilityDescription: "VibeProxy")
                button.image?.isTemplate = true
            }
        }

        menu = NSMenu()

        // Server Status
        menu.addItem(NSMenuItem(title: "Server: Stopped", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Main Actions
        menu.addItem(NSMenuItem(title: "Open Settings", action: #selector(openSettings), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())

        // Server Control
        let startStopItem = NSMenuItem(title: "Start Server", action: #selector(toggleServer), keyEquivalent: "")
        startStopItem.tag = 100
        menu.addItem(startStopItem)

        menu.addItem(NSMenuItem.separator())

        // Copy URL
        let copyURLItem = NSMenuItem(title: "Copy Server URL", action: #selector(copyServerURL), keyEquivalent: "c")
        copyURLItem.isEnabled = false
        copyURLItem.tag = 102
        menu.addItem(copyURLItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

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
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VibeProxy"
        window.center()

        let contentView = SettingsView(serverManager: serverManager)
        window.contentView = NSHostingView(rootView: contentView)

        settingsWindow = window
    }

    @objc func toggleServer() {
        if serverManager.isRunning {
            stopServer()
        } else {
            startServer()
        }
    }

    func startServer() {
        serverManager.start { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.updateMenuBarStatus()
                    self?.showNotification(title: "Server Started", body: "VibeProxy is now running on port \(self?.serverManager.port ?? 8317)")
                } else {
                    self?.showNotification(title: "Server Failed", body: "Could not start the server")
                }
            }
        }
    }

    func stopServer() {
        serverManager.stop()
        updateMenuBarStatus()
    }

    @objc func copyServerURL() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("http://localhost:\(serverManager.port)", forType: .string)
        showNotification(title: "Copied", body: "Server URL copied to clipboard")
    }

    @objc func updateMenuBarStatus() {
        // Update status items
        if let serverStatus = menu.item(at: 0) {
            serverStatus.title = serverManager.isRunning ? "Server: Running (\(serverManager.port))" : "Server: Stopped"
        }

        // Update button states
        if let startStopItem = menu.item(withTag: 100) {
            startStopItem.title = serverManager.isRunning ? "Stop Server" : "Start Server"
        }

        if let copyURLItem = menu.item(withTag: 102) {
            copyURLItem.isEnabled = serverManager.isRunning
        }

        // Update icon based on server status
        if let button = statusItem.button, let resourcePath = Bundle.main.resourcePath {
            if serverManager.isRunning {
                // Load active icon
                let iconPath = (resourcePath as NSString).appendingPathComponent("icon-active.png")
                if let icon = NSImage(contentsOfFile: iconPath) {
                    icon.isTemplate = true
                    // Resize to proper menu bar size (18x18 points for menu bar)
                    icon.size = NSSize(width: 18, height: 18)
                    button.image = icon
                    NSLog("[MenuBar] Loaded active icon from: %@", iconPath)
                } else {
                    NSLog("[MenuBar] Failed to load active icon from: %@", iconPath)
                    button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Running")
                }
            } else {
                // Load inactive icon
                let iconPath = (resourcePath as NSString).appendingPathComponent("icon-inactive.png")
                if let icon = NSImage(contentsOfFile: iconPath) {
                    icon.isTemplate = true
                    // Resize to proper menu bar size (18x18 points for menu bar)
                    icon.size = NSSize(width: 18, height: 18)
                    button.image = icon
                    NSLog("[MenuBar] Loaded inactive icon from: %@", iconPath)
                } else {
                    NSLog("[MenuBar] Failed to load inactive icon from: %@", iconPath)
                    button.image = NSImage(systemSymbolName: "network.slash", accessibilityDescription: "Stopped")
                }
            }
        }
    }

    func showNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }

    @objc func quit() {
        // Stop server and wait for cleanup before quitting
        if serverManager.isRunning {
            serverManager.stop()
        }
        // Give a moment for cleanup to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Final cleanup - stop server if still running
        if serverManager.isRunning {
            serverManager.stop()
        }
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // If server is running, stop it first
        if serverManager.isRunning {
            serverManager.stop()
            // Give server time to stop (up to 3 seconds total with the improved stop method)
            return .terminateNow
        }
        return .terminateNow
    }
}
