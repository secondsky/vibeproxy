import Foundation
import Network

/**
 A lightweight HTTP proxy that intercepts requests to add extended thinking parameters
 for Claude models based on model name suffixes.
 
 Model name pattern:
 - `*-thinking-NUMBER` → Custom token budget (e.g., claude-sonnet-4-5-20250929-thinking-5000)
 
 The proxy strips the suffix and adds the `thinking` parameter to the request body
 before forwarding to CLIProxyAPI.
 
 Examples:
 - claude-sonnet-4-5-20250929-thinking-2000 → 2,000 token budget
 - claude-sonnet-4-5-20250929-thinking-8000 → 8,000 token budget
 */
class ThinkingProxy {
    private var listener: NWListener?
    private let proxyPort: UInt16 = 8317
    private let targetPort: UInt16 = 8318
    private let targetHost = "127.0.0.1"
    private var isRunning = false
    
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
        
        // Try to parse and modify JSON body for POST requests
        var modifiedBody = bodyString
        
        if method == "POST" && !bodyString.isEmpty {
            if let result = processThinkingParameter(jsonString: bodyString) {
                modifiedBody = result.0
                // result.1 indicates if transformation happened, but we forward all requests via URLSession now
            }
        }
        
        // Use URLSession for all requests (works reliably for both transformed and pass-through)
        forwardWithURLSession(method: method, path: path, body: modifiedBody, originalConnection: connection)
    }
    
    /**
     Processes the JSON body to add thinking parameter if model name has a thinking suffix
     Returns tuple of (modifiedJSON, needsTransformation)
     */
    private func processThinkingParameter(jsonString: String) -> (String, Bool)? {
        guard let jsonData = jsonString.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let model = json["model"] as? String else {
            return nil
        }
        
        // Only process Claude models with thinking suffix
        guard model.starts(with: "claude-") else {
            return (jsonString, false)  // Not Claude, pass through
        }
        
        // Check for thinking suffix pattern: -thinking-NUMBER
        let thinkingPrefix = "-thinking-"
        if let thinkingRange = model.range(of: thinkingPrefix, options: .backwards),
           thinkingRange.upperBound < model.endIndex {
            
            // Extract the number after "-thinking-"
            let budgetString = String(model[thinkingRange.upperBound...])
            
            // Validate it's a number
            guard let budget = Int(budgetString), budget > 0 else {
                return (jsonString, false)  // Invalid number, pass through
            }
            
            // Strip the thinking suffix from model name
            let cleanModel = String(model[..<thinkingRange.lowerBound])
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
                    // Add 50% more tokens on top of the thinking budget (Claude requires max_tokens > budget)
                    let newMaxTokens = budget + (budget / 2)
                    json["max_tokens"] = newMaxTokens
                }
            }
            
            NSLog("[ThinkingProxy] Transformed model '\(model)' → '\(cleanModel)' with thinking budget \(budget)")
            
            // Convert back to JSON
            if let modifiedData = try? JSONSerialization.data(withJSONObject: json),
               let modifiedString = String(data: modifiedData, encoding: .utf8) {
                return (modifiedString, true)
            }
        }
        
        return (jsonString, false)  // No transformation needed
    }
    
    /**
     Forwards Claude thinking requests using URLSession (simpler and more reliable)
     */
    private func forwardWithURLSession(method: String, path: String, body: String, originalConnection: NWConnection) {
        let urlString = "http://\(targetHost):\(targetPort)\(path)"
        guard let url = URL(string: urlString) else {
            NSLog("[ThinkingProxy] Invalid URL: \(urlString)")
            sendError(to: originalConnection, statusCode: 500, message: "Invalid target URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)
        
        // Use custom session that preserves gzip encoding
        let config = URLSessionConfiguration.ephemeral
        config.httpAdditionalHeaders = ["Accept-Encoding": "gzip"]  // Accept gzip
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                NSLog("[ThinkingProxy] URLSession error: \(error)")
                self.sendError(to: originalConnection, statusCode: 502, message: "Bad Gateway")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                NSLog("[ThinkingProxy] Invalid response from CLIProxyAPI")
                self.sendError(to: originalConnection, statusCode: 502, message: "Bad Gateway")
                return
            }
            
            // Build complete HTTP response with proper headers and body
            var responseString = "HTTP/1.1 \(httpResponse.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))\r\n"
            
            // Copy all response headers from CLIProxyAPI
            for (key, value) in httpResponse.allHeaderFields {
                responseString += "\(key): \(value)\r\n"
            }
            
            responseString += "\r\n"
            
            // Combine headers and body in one send
            var fullResponse = Data()
            if let headerData = responseString.data(using: .utf8) {
                fullResponse.append(headerData)
            }
            if let bodyData = data {
                fullResponse.append(bodyData)
            }
            
            // Send complete response as-is (including gzip if present)
            originalConnection.send(content: fullResponse, completion: .contentProcessed({ _ in
                originalConnection.cancel()
            }))
        }
        
        task.resume()
    }
    
    /**
     Forwards the request to CLIProxyAPI on port 8318 (pass-through for non-thinking requests)
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
