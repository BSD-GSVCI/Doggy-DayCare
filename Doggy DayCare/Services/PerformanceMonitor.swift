import Foundation
import SwiftUI

@MainActor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published var syncTimes: [String: TimeInterval] = [:]
    @Published var lastSyncTime: Date?
    @Published var isSyncing = false
    @Published var syncProgress: Double = 0.0
    @Published var currentOperation: String = ""
    
    private var operationStartTimes: [String: Date] = [:]
    private var performanceMetrics: [String: [TimeInterval]] = [:]
    
    private init() {}
    
    // MARK: - Performance Tracking
    
    func startOperation(_ operation: String) {
        operationStartTimes[operation] = Date()
        currentOperation = operation
        isSyncing = true
        syncProgress = 0.0
        #if DEBUG
        print("⏱️ Started operation: \(operation)")
        #endif
    }
    
    func updateProgress(_ progress: Double) {
        syncProgress = progress
        #if DEBUG
        print("📊 Progress: \(Int(progress * 100))%")
        #endif
    }
    
    func completeOperation(_ operation: String) {
        guard let startTime = operationStartTimes[operation] else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        syncTimes[operation] = duration
        lastSyncTime = Date()
        isSyncing = false
        syncProgress = 1.0
        currentOperation = ""
        
        // Store metric for analysis
        if performanceMetrics[operation] == nil {
            performanceMetrics[operation] = []
        }
        performanceMetrics[operation]?.append(duration)
        
        #if DEBUG
        print("✅ Completed \(operation) in \(String(format: "%.2f", duration))s")
        #endif
        
        // Clean up
        operationStartTimes.removeValue(forKey: operation)
    }
    
    func failOperation(_ operation: String, error: Error) {
        isSyncing = false
        syncProgress = 0.0
        currentOperation = ""
        operationStartTimes.removeValue(forKey: operation)
        
        #if DEBUG
        print("❌ Failed \(operation): \(error.localizedDescription)")
        #endif
    }
    
    // MARK: - Performance Analysis
    
    func getAverageTime(for operation: String) -> TimeInterval? {
        guard let times = performanceMetrics[operation], !times.isEmpty else { return nil }
        return times.reduce(0, +) / Double(times.count)
    }
    
    func getSlowestOperations(limit: Int = 5) -> [(String, TimeInterval)] {
        let averages = performanceMetrics.compactMap { (operation, times) -> (String, TimeInterval)? in
            guard let avg = getAverageTime(for: operation) else { return nil }
            return (operation, avg)
        }
        
        return averages.sorted { $0.1 > $1.1 }.prefix(limit).map { $0 }
    }
    
    func getPerformanceMetrics(for operation: String) -> (count: Int, averageTime: TimeInterval)? {
        guard let times = performanceMetrics[operation], !times.isEmpty else { return nil }
        let averageTime = times.reduce(0, +) / Double(times.count)
        return (times.count, averageTime)
    }
    
    func getPerformanceReport() -> String {
        var report = "📊 Performance Report\n"
        report += "Last sync: \(lastSyncTime?.formatted() ?? "Never")\n\n"
        
        let slowest = getSlowestOperations()
        if !slowest.isEmpty {
            report += "Slowest operations:\n"
            for (operation, time) in slowest {
                report += "• \(operation): \(String(format: "%.2f", time))s\n"
            }
        }
        
        return report
    }
    
    // MARK: - Cache Management
    
    func clearMetrics() {
        performanceMetrics.removeAll()
        syncTimes.removeAll()
        #if DEBUG
        print("🧹 Performance metrics cleared")
        #endif
    }
}

// MARK: - View Extensions

extension View {
    func trackPerformance(_ operation: String, action: @escaping () async throws -> Void) async throws {
        PerformanceMonitor.shared.startOperation(operation)
        
        do {
            try await action()
            PerformanceMonitor.shared.completeOperation(operation)
        } catch {
            PerformanceMonitor.shared.failOperation(operation, error: error)
            throw error
        }
    }
} 