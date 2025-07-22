import SwiftUI

struct ContentView: View {
    @StateObject private var wsManager = WebSocketManager()
    @State private var serverURL: String = "ws://your-truenas-ip/websocket"  // Use wss:// for secure
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var apiKey: String = ""
    @State private var useAPIKey: Bool = false
    @State private var isConnected: Bool = false
    @State private var systemInfo: String = ""
    @State private var pools: [String] = []
    @State private var errorMessage: String = ""

    var body: some View {
        NavigationStack {
            if !isConnected {
                VStack(spacing: 20) {
                    Text("TrueNAS Admin Login")
                        .font(.title)
                    
                    TextField("Server URL (e.g., ws://192.168.1.100/websocket)", text: $serverURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Toggle("Use API Key", isOn: $useAPIKey)
                    
                    if !useAPIKey {
                        TextField("Username", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        SecureField("API Key", text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Button("Connect") {
                        wsManager.connect(url: serverURL) { success in
                            if success {
                                authenticate()
                            } else {
                                errorMessage = "Connection failed"
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                .padding()
            } else {
                List {
                    Section(header: Text("System Info")) {
                        Text(systemInfo)
                    }
                    Section(header: Text("Storage Pools")) {
                        ForEach(pools, id: \.self) { pool in
                            Text(pool)
                        }
                    }
                }
                .navigationTitle("TrueNAS Admin")
                .toolbar {
                    Button("Disconnect") {
                        wsManager.disconnect()
                        isConnected = false
                    }
                }
                .onAppear {
                    fetchSystemInfo()
                    fetchPools()
                }
            }
        }
    }
    
    private func authenticate() {
        let method = useAPIKey ? "auth.login_with_api_key" : "auth.login"
        let params = useAPIKey ? [apiKey] : [username, password]
        wsManager.sendRequest(method: method, params: params) { result in
            switch result {
            case .success(let response):
                if let success = response as? Bool, success {
                    isConnected = true
                    errorMessage = ""
                } else {
                    errorMessage = "Authentication failed"
                    wsManager.disconnect()
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
                wsManager.disconnect()
            }
        }
    }
    
    private func fetchSystemInfo() {
        wsManager.sendRequest(method: "system.info", params: []) { result in
            switch result {
            case .success(let response):
                if let info = response as? [String: Any] {
                    systemInfo = info.map { "\($0): \($1)" }.joined(separator: "\n")
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func fetchPools() {
        wsManager.sendRequest(method: "pool.query", params: []) { result in
            switch result {
            case .success(let response):
                if let poolArray = response as? [[String: Any]] {
                    pools = poolArray.compactMap { $0["name"] as? String }
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ContentView()
}
