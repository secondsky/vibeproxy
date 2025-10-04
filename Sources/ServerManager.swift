import Foundation
import Combine

class ServerManager {
    private var process: Process?
    @Published private(set) var isRunning = false
    private(set) var port = 8317
    private var logBuffer: [String] = []
    private let maxLogLines = 1000
    
    var onLogUpdate: (([String]) -> Void)?
    
    func start(completion: @escaping (Bool) -> Void) {
        guard !isRunning else {
            completion(true)
            return
        }
        
        // Use bundled binary from app bundle
        guard let resourcePath = Bundle.main.resourcePath else {
            addLog("❌ Error: Could not find resource path")
            completion(false)
            return
        }
        
        let bundledPath = (resourcePath as NSString).appendingPathComponent("Resources/cli-proxy-api")
        guard FileManager.default.fileExists(atPath: bundledPath) else {
            addLog("❌ Error: cli-proxy-api binary not found at \(bundledPath)")
            completion(false)
            return
        }
        
        // Use bundled config
        let configPath = (resourcePath as NSString).appendingPathComponent("Resources/config.yaml")
        guard FileManager.default.fileExists(atPath: configPath) else {
            addLog("❌ Error: config.yaml not found at \(configPath)")
            completion(false)
            return
        }
        
        process = Process()
        process?.executableURL = URL(fileURLWithPath: bundledPath)
        process?.arguments = ["--config", configPath]
        
        // Setup pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process?.standardOutput = outputPipe
        process?.standardError = errorPipe
        
        // Handle output
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                self?.addLog(output)
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                self?.addLog("⚠️ \(output)")
            }
        }
        
        // Handle termination
        process?.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.addLog("Server stopped with code: \(process.terminationStatus)")
                NotificationCenter.default.post(name: NSNotification.Name("ServerStatusChanged"), object: nil)
            }
        }
        
        do {
            try process?.run()
            DispatchQueue.main.async {
                self.isRunning = true
            }
            addLog("✓ Server started on port \(port)")
            
            // Wait a bit to ensure it started successfully
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NotificationCenter.default.post(name: NSNotification.Name("ServerStatusChanged"), object: nil)
                completion(true)
            }
        } catch {
            addLog("❌ Failed to start server: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    func stop() {
        guard isRunning else { return }
        
        process?.terminate()
        process = nil
        DispatchQueue.main.async {
            self.isRunning = false
        }
        addLog("Server stopped")
        
        NotificationCenter.default.post(name: NSNotification.Name("ServerStatusChanged"), object: nil)
    }
    
    func runAuthCommand(_ command: AuthCommand, completion: @escaping (Bool, String) -> Void) {
        // Use bundled binary from app bundle
        guard let resourcePath = Bundle.main.resourcePath else {
            completion(false, "Could not find resource path")
            return
        }
        
        let bundledPath = (resourcePath as NSString).appendingPathComponent("Resources/cli-proxy-api")
        guard FileManager.default.fileExists(atPath: bundledPath) else {
            completion(false, "Binary not found at \(bundledPath)")
            return
        }
        
        let authProcess = Process()
        authProcess.executableURL = URL(fileURLWithPath: bundledPath)
        
        // Get the config path
        let configPath = (resourcePath as NSString).appendingPathComponent("Resources/config.yaml")
        
        switch command {
        case .claudeLogin:
            authProcess.arguments = ["-config", configPath, "-claude-login"]
        case .codexLogin:
            authProcess.arguments = ["-config", configPath, "-codex-login"]
        }
        
        // Create pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()
        authProcess.standardOutput = outputPipe
        authProcess.standardError = errorPipe
        authProcess.standardInput = inputPipe
        
        // Set environment to inherit from parent
        authProcess.environment = ProcessInfo.processInfo.environment
        
        do {
            NSLog("[Auth] Starting process: %@ with args: %@", bundledPath, authProcess.arguments?.joined(separator: " ") ?? "none")
            try authProcess.run()
            addLog("✓ Authentication process started (PID: \(authProcess.processIdentifier)) - browser should open shortly")
            NSLog("[Auth] Process started with PID: %d", authProcess.processIdentifier)
            
            // Wait briefly to check if process crashes immediately
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.0) {
                if authProcess.isRunning {
                    // Process is still running after 1 second - browser likely opened
                    NSLog("[Auth] Process running after 1s, returning success")
                    completion(true, "🌐 Browser opened for authentication.\n\nPlease complete the login in your browser.\n\nThe app will automatically detect when you're authenticated.")
                } else {
                    // Process died quickly - check for error
                    let outputData = try? outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = try? errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let output = String(data: outputData ?? Data(), encoding: .utf8) ?? ""
                    let error = String(data: errorData ?? Data(), encoding: .utf8) ?? ""
                    
                    NSLog("[Auth] Process died quickly - output: %@", output.isEmpty ? "(empty)" : String(output.prefix(200)))
                    
                    if output.contains("Opening browser") || output.contains("Attempting to open URL") {
                        // Browser opened but process finished (probably success)
                        NSLog("[Auth] Browser opened, process completed")
                        completion(true, "🌐 Browser opened for authentication.\n\nPlease complete the login in your browser.\n\nThe app will automatically detect when you're authenticated.")
                    } else {
                        // Real error
                        NSLog("[Auth] Process failed")
                        let message = error.isEmpty ? (output.isEmpty ? "Authentication process failed unexpectedly" : output) : error
                        completion(false, message)
                    }
                }
            }
        } catch {
            NSLog("[Auth] Failed to start: %@", error.localizedDescription)
            completion(false, "Failed to start auth process: \(error.localizedDescription)")
        }
    }
    
    private func addLog(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            let logLine = "[\(timestamp)] \(message)"
            
            self.logBuffer.append(logLine)
            
            // Keep only last N lines
            if self.logBuffer.count > self.maxLogLines {
                self.logBuffer.removeFirst(self.logBuffer.count - self.maxLogLines)
            }
            
            self.onLogUpdate?(self.logBuffer)
        }
    }
    
    func getLogs() -> [String] {
        return logBuffer
    }
}

enum AuthCommand {
    case claudeLogin
    case codexLogin
}
