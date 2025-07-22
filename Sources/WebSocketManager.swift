import Foundation

class WebSocketManager: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var requestCallbacks: [String: (Result<Any, Error>) -> Void] = [:]
    private var messageIdCounter = 0
    
    func connect(url: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: url) else {
            completion(false)
            return
        }
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveMessage()
        completion(true)
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        requestCallbacks.removeAll()
    }
    
    func sendRequest(method: String, params: [Any], completion: @escaping (Result<Any, Error>) -> Void) {
        messageIdCounter += 1
        let id = "\(messageIdCounter)"
        let request: [String: Any] = [
            "id": id,
            "method": method,
            "params": params,
            "jsonrpc": "2.0"
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: request) else {
            completion(.failure(NSError(domain: "JSONError", code: 0)))
            return
        }
        
        requestCallbacks[id] = completion
        webSocketTask?.send(.data(data)) { error in
            if let error = error {
                completion(.failure(error))
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self?.handleReceivedData(data)
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        self?.handleReceivedData(data)
                    }
                @unknown default:
                    break
                }
                self?.receiveMessage()  // Continue listening
            case .failure(let error):
                print("WebSocket receive error: \(error)")
            }
        }
    }
    
    private func handleReceivedData(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String else {
            return
        }
        
        if let callback = requestCallbacks[id] {
            if let error = json["error"] as? [String: Any] {
                let errorMessage = error["message"] as? String ?? "Unknown error"
                callback(.failure(NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
            } else if let result = json["result"] {
                callback(.success(result))
            }
            requestCallbacks.removeValue(forKey: id)
        }
    }
}
