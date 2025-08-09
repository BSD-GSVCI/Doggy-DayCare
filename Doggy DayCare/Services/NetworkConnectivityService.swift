import Foundation
import Network
import SwiftUI

@MainActor
class NetworkConnectivityService: ObservableObject {
    static let shared = NetworkConnectivityService()
    
    @Published var isConnected = false
    @Published var connectionType: ConnectionType = .unknown
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkConnectivityMonitor")
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
        
        var displayName: String {
            switch self {
            case .wifi:
                return "Wi-Fi"
            case .cellular:
                return "Cellular"
            case .ethernet:
                return "Ethernet"
            case .unknown:
                return "Unknown"
            }
        }
    }
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateConnectionStatus(path: path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func updateConnectionStatus(path: NWPath) {
        isConnected = path.status == .satisfied
        
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
        
        #if DEBUG
        print("🌐 Network status: \(isConnected ? "Connected" : "Disconnected") via \(connectionType.displayName)")
        #endif
    }
    
    nonisolated func stopMonitoring() {
        monitor.cancel()
    }
    
    deinit {
        stopMonitoring()
    }
} 