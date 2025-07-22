import SwiftUI

struct ContentView: View {
    @State private var serverURL: String = "wss://your-truenas-server-ip/websocket" // Default; user edits
    @State private var apiKey: String = ""
    @State private var isConnected: Bool = false
    @State private var responseText: String = "Not connected."
    @State private var webSocketTask: URLSessionWebSocketTask?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Server WebSocket URL", text: $serverURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button("Connect & Authenticate") {
                    connectAndAuthenticate()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                if isConnected {
                    VStack {
                        Button("Fetch System Info") { sendAPIRequest(method: "system.info", params: []) }
                        Button("Fetch Pools") { sendAPIRequest(method: "pool.query", params: []) }
                        Button("Fetch Datasets") { sendAPIRequest(method: "pool.dataset.query", params: []) }
                        Button("Fetch Users") { sendAPIRequest(method: "user.query", params: []) }
                        Button("Fetch SMB Shares") { sendAPIRequest(method: "sharing.smb.query", params: []) }
                    }
                    .padding()
                }
                
                ScrollView {
                    Text(responseText)
                        .padding()
                }
            }
            .navigationTitle("TrueNAS Admin")
        }
    }
    
    private func connectAndAuthenticate() {
        guard let url = URL(string: serverURL) else {
            responseText = "Invalid URL."
            return
        }
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Send connect message
        sendMessage(["msg": "connect", "version": "1", "support": ["1"]])
        
        // Listen for responses
        receiveMessage()
        
        // Authenticate after connect
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { // Delay to allow connect response
            let authID = UUID().uuidString
            let authMessage: [String: Any] = [
                "id": authID,
                "msg": "method",
                "method": "auth.login_with_api_key",
                "params": [apiKey]
            ]
            sendMessage(authMessage)
        }
    }
    
    private func sendAPIRequest(method: String, params: [Any]) {
        let requestID = UUID().uuidString
        let message: [String: Any] = [
            "id": requestID,
            "msg": "method",
            "method": method,
            "params": params
        ]
        sendMessage(message)
    }
    
    private func sendMessage(_ message: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            webSocketTask?.send(.data(data)) { error in
                if let error = error {
                    responseText = "Send error: \(error.localizedDescription)"
                }
            }
        } catch {
            responseText = "JSON error: \(error.localizedDescription)"
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { result in
            switch result {
            case .failure(let error):
                responseText = "Receive error: \(error.localizedDescription)"
                isConnected = false
            case .success(let message):
                switch message {
                case .data(let data):
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let msg = json["msg"] as? String {
                            if msg == "connected" {
                                isConnected = true
                                responseText = "Connected successfully."
                            } else if msg == "result" {
                                responseText = "Response: \(json)"
                            } else if msg == "error" {
                                responseText = "Error: \(json["error"] ?? "Unknown")"
                            }
                        }
                    }
                case .string(let text):
                    responseText = "Received string: \(text)"
                @unknown default:
                    break
                }
                receiveMessage() // Continue listening
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
