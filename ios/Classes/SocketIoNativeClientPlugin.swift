import Flutter
import UIKit
import SocketIO

public class SocketIoNativeClientPlugin: NSObject, FlutterPlugin {
    
    private var commandChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private let streamHandler = SocketStreamHandler()
    
    // Socket.IO properties
    private var socketManager: SocketManager?
    private var socket: SocketIOClient?
    private var activeListeners: [String: UUID] = [:]
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SocketIoNativeClientPlugin()
        instance.setupChannels(with: registrar.messenger())
    }
    
    private func setupChannels(with messenger: FlutterBinaryMessenger) {
        commandChannel = FlutterMethodChannel(name: "devarsh/command", binaryMessenger: messenger)
        eventChannel = FlutterEventChannel(name: "devarsh/events", binaryMessenger: messenger)
        
        commandChannel?.setMethodCallHandler(handle)
        eventChannel?.setStreamHandler(streamHandler)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        do {
            switch call.method {
            case "connect":
                guard let args = call.arguments as? [String: Any],
                      let urlString = args["url"] as? String else {
                    result(FlutterError(code: "INVALID_URL", message: "URL not provided or invalid", details: nil))
                    return
                }
                
                if urlString.isEmpty {
                    result(FlutterError(code: "INVALID_URL", message: "URL cannot be empty", details: nil))
                    return
                }
                
                let options = args["options"] as? [String: Any]
                connectSocket(urlString: urlString, options: options, result: result)
                
            case "disconnect":
                disconnectSocket(result: result)
                
            case "emit":
                guard let args = call.arguments as? [String: Any],
                      let event = args["event"] as? String else {
                    result(FlutterError(code: "EVENT_ERROR", message: "Event name not provided", details: nil))
                    return
                }
                
                if event.isEmpty {
                    result(FlutterError(code: "EVENT_ERROR", message: "Event name cannot be empty", details: nil))
                    return
                }
                
                let data = args["data"]
                emitEvent(event: event, data: data, result: result)
                
            case "listen":
                guard let args = call.arguments as? [String: Any],
                      let event = args["event"] as? String else {
                    result(FlutterError(code: "EVENT_ERROR", message: "Event name not provided", details: nil))
                    return
                }
                
                if event.isEmpty {
                    result(FlutterError(code: "EVENT_ERROR", message: "Event name cannot be empty", details: nil))
                    return
                }
                
                listenToEvent(event: event, result: result)
                
            case "unlisten":
                guard let args = call.arguments as? [String: Any],
                      let event = args["event"] as? String else {
                    result(FlutterError(code: "EVENT_ERROR", message: "Event name not provided", details: nil))
                    return
                }
                
                if event.isEmpty {
                    result(FlutterError(code: "EVENT_ERROR", message: "Event name cannot be empty", details: nil))
                    return
                }
                
                unlistenFromEvent(event: event, result: result)
                
            default:
                result(FlutterMethodNotImplemented)
            }
        } catch {
            result(FlutterError(code: "UNEXPECTED_ERROR", message: "An unexpected error occurred: \(error.localizedDescription)", details: error.localizedDescription))
        }
    }
    
    private func connectSocket(urlString: String, options: [String: Any]?, result: @escaping FlutterResult) {
        do {
            guard let url = URL(string: urlString) else {
                streamHandler.sendEvent(type: "status", payload: ["status": "error", "reason": "Invalid URL format"])
                result(FlutterError(code: "INVALID_URL", message: "The provided URL is invalid", details: urlString))
                return
            }
            
            // Disconnect existing socket if any
            if socket != nil {
                socket?.disconnect()
                socket = nil
                socketManager = nil
                activeListeners.removeAll()
            }
            
            streamHandler.sendEvent(type: "status", payload: ["status": "connecting"])
            
            var config: SocketIOClientConfiguration = []
            var connectParams: [String: Any] = [:]
            
            if let options = options {
                // Handle query and auth parameters
                if let query = options["query"] as? [String: Any] {
                    connectParams.merge(query) { (current, _) in current }
                }
                if let auth = options["auth"] as? [String: Any] {
                    connectParams["auth"] = auth
                }
                if !connectParams.isEmpty {
                    config.insert(.connectParams(connectParams))
                }
                
                // --- Common Properties ---
                if let path = options["path"] as? String { 
                    config.insert(.path(path)) 
                }
                if let reconnect = options["reconnection"] as? Bool { 
                    config.insert(.reconnects(reconnect)) 
                }
                if let attempts = options["reconnectionAttempts"] as? Int { 
                    config.insert(.reconnectAttempts(attempts)) 
                }
                if let secure = options["secure"] as? Bool { 
                    config.insert(.secure(secure)) 
                }
                if let forceNew = options["forceNew"] as? Bool { 
                    config.insert(.forceNew(forceNew)) 
                }
                
                // Time values conversion from milliseconds to seconds
                if let delay = options["reconnectionDelay"] as? Double { 
                    config.insert(.reconnectWait(Int(delay / 1000.0))) 
                }
                if let delayMax = options["reconnectionDelayMax"] as? Double { 
                    config.insert(.reconnectWaitMax(Int(delayMax / 1000.0))) 
                }
                if let jitter = options["randomizationFactor"] as? Double { 
                    config.insert(.randomizationFactor(jitter)) 
                }
                
                // --- iOS-Specific Properties ---
                if let iosConfig = options["extraIOSConfig"] as? [String: Any] {
                    if let log = iosConfig["log"] as? Bool { 
                        config.insert(.log(log)) 
                    }
                    if let headers = iosConfig["extraHeaders"] as? [String: String] { 
                        config.insert(.extraHeaders(headers)) 
                    }
                    if let compress = iosConfig["compress"] as? Bool, compress == true { 
                        config.insert(.compress) 
                    }
                    if let forcePolling = iosConfig["forcePolling"] as? Bool, forcePolling == true { 
                        config.insert(.forcePolling(true)) 
                    }
                    if let forceWebsockets = iosConfig["forceWebsockets"] as? Bool, forceWebsockets == true { 
                        config.insert(.forceWebsockets(true)) 
                    }
                }
            }
            
            socketManager = SocketManager(socketURL: url, config: config)
            socket = socketManager?.defaultSocket
            
            guard let socket = socket else {
                result(FlutterError(code: "CONNECTION_FAILED", message: "Failed to create socket instance", details: nil))
                return
            }
            
            // Set up event handlers
            socket.on(clientEvent: .connect) { [weak self] _, _ in
                let socketId = self?.socket?.sid ?? ""
                self?.streamHandler.sendEvent(type: "status", payload: ["status": "connected", "socketId": socketId])
            }
            
            socket.on(clientEvent: .error) { [weak self] data, _ in
                let errorMessage = String(describing: data.first ?? "Connection error")
                self?.streamHandler.sendEvent(type: "status", payload: ["status": "error", "reason": errorMessage])
            }
            
            socket.on(clientEvent: .disconnect) { [weak self] _, _ in
                self?.streamHandler.sendEvent(type: "status", payload: ["status": "disconnected"])
            }
            
            socket.on(clientEvent: .reconnect) { [weak self] _, _ in
                let socketId = self?.socket?.sid ?? ""
                self?.streamHandler.sendEvent(type: "status", payload: ["status": "connected", "socketId": socketId])
            }
            
            socket.on(clientEvent: .reconnectAttempt) { [weak self] _, _ in
                self?.streamHandler.sendEvent(type: "status", payload: ["status": "connecting"])
            }
            
            // Connect with timeout
            let timeoutValue = options?["timeout"] as? Double ?? 0
            socket.connect(timeoutAfter: timeoutValue > 0 ? timeoutValue / 1000.0 : 0) { [weak self] in
                // This completion handler is called if the connection times out.
                self?.streamHandler.sendEvent(type: "status", payload: ["status": "error", "reason": "Connection timeout"])
            }
            
            result(nil)
            
        } catch {
            streamHandler.sendEvent(type: "status", payload: ["status": "error", "reason": error.localizedDescription])
            result(FlutterError(code: "CONNECTION_FAILED", message: "Connection failed: \(error.localizedDescription)", details: error.localizedDescription))
        }
    }
    
    private func disconnectSocket(result: @escaping FlutterResult) {
        do {
            socket?.disconnect()
            socket = nil
            socketManager = nil
            activeListeners.removeAll()
            result(nil)
        } catch {
            result(FlutterError(code: "DISCONNECTION_FAILED", message: "Failed to disconnect: \(error.localizedDescription)", details: error.localizedDescription))
        }
    }
    
    private func emitEvent(event: String, data: Any?, result: @escaping FlutterResult) {
        do {
            guard let socket = socket, socket.status == .connected else {
                result(FlutterError(code: "NOT_CONNECTED", message: "Socket is not connected", details: nil))
                return
            }
            
            if let data = data as? SocketData {
                socket.emit(event, data)
            } else if data == nil {
                socket.emit(event)
            } else {
               // Convert data to SocketData compatible format
               if let dictData = data as? [String: Any] {
                   socket.emit(event, dictData)
               } else if let arrayData = data as? [Any] {
                   socket.emit(event, arrayData)
               } else if let stringData = data as? String {
                   socket.emit(event, stringData)
               } else if let numberData = data as? NSNumber {
                   // Convert NSNumber to appropriate primitive type
                   if CFNumberIsFloatType(numberData) {
                       socket.emit(event, numberData.doubleValue)
                   } else {
                       socket.emit(event, numberData.intValue)
                   }
               } else if let boolData = data as? Bool {
                   socket.emit(event, boolData)
               } else if let intData = data as? Int {
                   socket.emit(event, intData)
               } else if let doubleData = data as? Double {
                   socket.emit(event, doubleData)
               } else {
                   socket.emit(event, String(describing: data))
               }
            }
            
            result(nil)
        } catch {
            result(FlutterError(code: "EMISSION_FAILED", message: "Failed to emit event '\(event)': \(error.localizedDescription)", details: error.localizedDescription))
        }
    }
    
    private func listenToEvent(event: String, result: @escaping FlutterResult) {
        do {
            guard let socket = socket, socket.status == .connected else {
                result(FlutterError(code: "NOT_CONNECTED", message: "Socket is not connected", details: nil))
                return
            }
            
            let listenerId = socket.on(event) { [weak self] dataArray, ack in
                do {
                    let payload: [String: Any] = ["event": event, "data": dataArray.first ?? NSNull()]
                    self?.streamHandler.sendEvent(type: "socket_event", payload: payload)
                } catch {
                    print("Error processing event '\(event)': \(error.localizedDescription)")
                }
            }
            
            activeListeners[event] = listenerId
            result(nil)
            
        } catch {
            result(FlutterError(code: "EVENT_ERROR", message: "Failed to listen to event '\(event)': \(error.localizedDescription)", details: error.localizedDescription))
        }
    }
    
    private func unlistenFromEvent(event: String, result: @escaping FlutterResult) {
        do {
            if let listenerId = activeListeners[event] {
                socket?.off(id: listenerId)
                activeListeners.removeValue(forKey: event)
            }
            result(nil)
        } catch {
            result(FlutterError(code: "EVENT_ERROR", message: "Failed to unlisten from event '\(event)': \(error.localizedDescription)", details: error.localizedDescription))
        }
    }
}

// MARK: - Stream Handler
class SocketStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    func sendEvent(type: String, payload: Any) {
        guard let sink = self.eventSink else { return }
        do {
            let event: [String: Any] = ["type": type, "payload": payload]
            sink(event)
        } catch {
            print("Error sending event: \(error.localizedDescription)")
        }
    }
} 