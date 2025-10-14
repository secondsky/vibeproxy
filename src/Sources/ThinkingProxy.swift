import Foundation
import Network

/**
 A lightweight HTTP proxy that intercepts requests to add extended thinking parameters
 for Claude models based on model name suffixes.
 
 Model name patterns:
 - `*-thinking-low` → 2,000 token budget
 - `*-thinking-medium` → 4,000 token budget
 - `*-thinking-high` → 8,000 token budget
 
 The proxy strips the suffix and adds the `thinking` parameter to the request body
 before forwarding to CLIProxyAPI.
 */
class ThinkingProxy {
    private var listener: NWListener?
    private let proxyPort: UInt16 = 8317
    private let targetPort: UInt16 = 8318
    private let targetHost = "127.0.0.1"
    private var isRunning = false
    
    /// Token budget mappings for thinking levels
    private let thinkingBudgets: [String: Int] = [
        "thinking-low": 2000,
        "thinking-medium": 4000,
        "thinking-high": 8000
    ]
    
    /**
     Starts the thinking proxy server on port 8317
     */
    func start() {
        guard !isRunning else {
            NSLog("[ThinkingProxy] Already running")
            return
        }
        
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: proxyPort)!)
            
            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.isRunning = true
                    NSLog("[ThinkingProxy] Listening on port \(self?.proxyPort ?? 0)")
                case .failed(let error):
                    NSLog("[ThinkingProxy] Failed: \(error)")
                    self?.isRunning = false
                case .cancelled:
                    NSLog("[ThinkingProxy] Cancelled")
                    self?.isRunning = false
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
            
        } catch {
            NSLog("[ThinkingProxy] Failed to start: \(error)")
        }
    }
    
    /**
     Stops the thinking proxy server
     */
    func stop() {
        guard isRunning else { return }
        
        listener?.cancel()
        listener = nil
        isRunning = false
        NSLog("[ThinkingProxy] Stopped")
    }
    
    /**
     Handles an incoming connection from a client
     */
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        receiveRequest(from: connection)
    }
    
    /**
     Receives the HTTP request from the client
     */
    private func receiveRequest(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                NSLog("[ThinkingProxy] Receive error: \(error)")
                connection.cancel()
                return
            }
            
            guard let data = data, !data.isEmpty else {
                if isComplete {
                    connection.cancel()
                }
                return
            }
            
            // Parse and process the request
            self.processRequest(data: data, connection: connection)
        }
    }
    
    /**
     Processes the HTTP request, modifies it if needed, and forwards to CLIProxyAPI
     */
    private func processRequest(data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendError(to: connection, statusCode: 400, message: "Invalid request")
            return
        }
        
        // Parse HTTP request
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendError(to: connection, statusCode: 400, message: "Invalid request line")
            return
        }
        
        // Extract method, path, and HTTP version
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 3 else {
            sendError(to: connection, statusCode: 400, message: "Invalid request format")
            return
        }
        
        let method = parts[0]
        let path = parts[1]
        
        // Find the body start
        guard let bodyStartRange = requestString.range(of: "\r\n\r\n") else {
            NSLog("[ThinkingProxy] Error: Could not find body separator in request")
            sendError(to: connection, statusCode: 400, message: "Invalid request format - no body separator")
            return
        }
        
        let bodyStart = requestString.distance(from: requestString.startIndex, to: bodyStartRange.upperBound)
        let bodyString = String(requestString[requestString.index(requestString.startIndex, offsetBy: bodyStart)...])
        
        NSLog("[ThinkingProxy] Parsed request: method=\(method), path=\(path), bodyLength=\(bodyString.count)")
        
        // Try to parse and modify JSON body for POST requests
        var modifiedBody = bodyString
        if method == "POST" && !bodyString.isEmpty {
            if let modifiedJSON = processThinkingParameter(jsonString: bodyString) {
                modifiedBody = modifiedJSON
            }
        }
        
        // Forward to CLIProxyAPI
        forwardRequest(method: method, path: path, headers: lines, body: modifiedBody, originalConnection: connection)
    }
    
    /**
     Processes the JSON body to add thinking parameter if model name has a thinking suffix
     */
    private func processThinkingParameter(jsonString: String) -> String? {
        guard let jsonData = jsonString.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let model = json["model"] as? String else {
            return nil
        }
        
        // Check for thinking suffix
        for (suffix, budget) in thinkingBudgets {
            if model.hasSuffix("-\(suffix)") {
                // Strip the suffix from model name
                let cleanModel = String(model.dropLast(suffix.count + 1))
                json["model"] = cleanModel
                
                // Add thinking parameter
                json["thinking"] = [
                    "type": "enabled",
                    "budget_tokens": budget
                ]
                
                // Ensure max_tokens is greater than thinking budget
                // Claude requires: max_tokens > thinking.budget_tokens
                if let currentMaxTokens = json["max_tokens"] as? Int {
                    if currentMaxTokens <= budget {
                        // Add 50% more tokens on top of the thinking budget
                        let newMaxTokens = budget + (budget / 2)
                        json["max_tokens"] = newMaxTokens
                        NSLog("[ThinkingProxy] Increased max_tokens from \(currentMaxTokens) to \(newMaxTokens) (must be > thinking budget)")
                    }
                }
                
                NSLog("[ThinkingProxy] Transformed model '\(model)' → '\(cleanModel)' with budget \(budget)")
                
                // Convert back to JSON
                if let modifiedData = try? JSONSerialization.data(withJSONObject: json),
                   let modifiedString = String(data: modifiedData, encoding: .utf8) {
                    return modifiedString
                }
            }
        }
        
        return nil
    }
    
    /**
     Forwards the request to CLIProxyAPI on port 8318
     */
    private func forwardRequest(method: String, path: String, headers: [String], body: String, originalConnection: NWConnection) {
        // Create connection to CLIProxyAPI
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(targetHost), port: NWEndpoint.Port(rawValue: targetPort)!)
        let parameters = NWParameters.tcp
        let targetConnection = NWConnection(to: endpoint, using: parameters)
        
        targetConnection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                // Build the forwarded request
                var forwardedRequest = "\(method) \(path) HTTP/1.1\r\n"
                
                // Copy relevant headers (skip the request line, Host, and Content-Length)
                for header in headers.dropFirst() {
                    let lowercaseHeader = header.lowercased()
                    if !header.isEmpty && 
                       !lowercaseHeader.starts(with: "host:") && 
                       !lowercaseHeader.starts(with: "content-length:") {
                        forwardedRequest += "\(header)\r\n"
                    }
                }
                
                // Add correct Host header
                forwardedRequest += "Host: \(self.targetHost):\(self.targetPort)\r\n"
                
                // Add correct Content-Length for the (potentially modified) body
                if !body.isEmpty {
                    let contentLength = body.utf8.count
                    forwardedRequest += "Content-Length: \(contentLength)\r\n"
                }
                
                forwardedRequest += "\r\n\(body)"
                
                // Debug logging
                NSLog("[ThinkingProxy] Forwarding request to CLIProxyAPI:")
                NSLog("[ThinkingProxy] Method: \(method), Path: \(path)")
                NSLog("[ThinkingProxy] Body length: \(body.utf8.count)")
                NSLog("[ThinkingProxy] Body preview: \(String(body.prefix(200)))")
                
                // Send to CLIProxyAPI
                if let requestData = forwardedRequest.data(using: .utf8) {
                    targetConnection.send(content: requestData, completion: .contentProcessed({ error in
                        if let error = error {
                            NSLog("[ThinkingProxy] Send error: \(error)")
                            targetConnection.cancel()
                            originalConnection.cancel()
                        } else {
                            // Receive response from CLIProxyAPI
                            self.receiveResponse(from: targetConnection, originalConnection: originalConnection)
                        }
                    }))
                }
                
            case .failed(let error):
                NSLog("[ThinkingProxy] Target connection failed: \(error)")
                self.sendError(to: originalConnection, statusCode: 502, message: "Bad Gateway")
                targetConnection.cancel()
                
            default:
                break
            }
        }
        
        targetConnection.start(queue: .global(qos: .userInitiated))
    }
    
    /**
     Receives response from CLIProxyAPI
     */
    private func receiveResponse(from targetConnection: NWConnection, originalConnection: NWConnection) {
        targetConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                NSLog("[ThinkingProxy] Receive response error: \(error)")
                targetConnection.cancel()
                originalConnection.cancel()
                return
            }
            
            if let data = data, !data.isEmpty {
                // Forward response to original client
                originalConnection.send(content: data, completion: .contentProcessed({ sendError in
                    if let sendError = sendError {
                        NSLog("[ThinkingProxy] Send response error: \(sendError)")
                    }
                    
                    if isComplete {
                        targetConnection.cancel()
                        originalConnection.cancel()
                    } else {
                        // Continue receiving
                        self.receiveResponse(from: targetConnection, originalConnection: originalConnection)
                    }
                }))
            } else if isComplete {
                targetConnection.cancel()
                originalConnection.cancel()
            }
        }
    }
    
    /**
     Sends an error response to the client
     */
    private func sendError(to connection: NWConnection, statusCode: Int, message: String) {
        let response = """
        HTTP/1.1 \(statusCode) \(message)
        Content-Type: text/plain
        Content-Length: \(message.count)
        Connection: close
        
        \(message)
        """
        
        if let responseData = response.data(using: .utf8) {
            connection.send(content: responseData, completion: .contentProcessed({ _ in
                connection.cancel()
            }))
        }
    }
}
