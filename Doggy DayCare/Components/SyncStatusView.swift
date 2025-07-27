import SwiftUI

private func getUserFriendlyOperationName(_ operation: String) -> String {
    switch operation {
    case "fetchDogs":
        return "Load Dogs from Cloud"
    case "fetchUsers":
        return "Load Staff from Cloud"
    case "fetchDogsForBackup":
        return "Backup Dogs Data"
    case "fetchDogsForImport":
        return "Import Dogs Data"
    case "fetchDogWithRecords":
        return "Load Dog Details"
    case "addDog":
        return "Add New Dog"
    case "updateDog":
        return "Update Dog Info"
    case "deleteDog":
        return "Delete Dog"
    case "addFeedingRecord":
        return "Add Feeding Record"
    case "addMedicationRecord":
        return "Add Medication Record"
    case "addPottyRecord":
        return "Add Potty Record"
    default:
        return operation.capitalized
    }
}

struct SyncStatusView: View {
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @State private var showingPerformanceReport = false
    
    var body: some View {
        VStack(spacing: 8) {
            if performanceMonitor.isSyncing {
                // Active sync indicator
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(getUserFriendlyOperationName(performanceMonitor.currentOperation))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("\(Int(performanceMonitor.syncProgress * 100))% complete")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        showingPerformanceReport = true
                    } label: {
                        Image(systemName: "speedometer")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let lastSync = performanceMonitor.lastSyncTime {
                // Last sync info - show this when not actively syncing
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                    
                    Text("Last sync: \(lastSync.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        showingPerformanceReport = true
                    } label: {
                        Image(systemName: "speedometer")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .sheet(isPresented: $showingPerformanceReport) {
            PerformanceReportView()
        }
    }
}

struct PerformanceReportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @StateObject private var dataManager = DataManager.shared
    @State private var cacheStats: (memoryCount: Int, diskSize: String) = (0, "0 KB")
    
    var body: some View {
        NavigationStack {
            List {
                Section("Sync Performance") {
                    if let lastSync = performanceMonitor.lastSyncTime {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(lastSync.formatted())
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Show recent sync operations (excluding the ones that will appear in Performance Analysis)
                    let recentOperations = performanceMonitor.syncTimes.filter { operation, _ in
                        !["fetchDogs", "fetchUsers", "fetchDogsForBackup", "fetchDogsForImport"].contains(operation)
                    }
                    
                    ForEach(Array(recentOperations.keys.sorted()), id: \.self) { operation in
                        if let time = performanceMonitor.syncTimes[operation] {
                            HStack {
                                Text(getUserFriendlyOperationName(operation))
                                Spacer()
                                Text(String(format: "%.2fs", time))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if recentOperations.isEmpty {
                        Text("No recent sync operations")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Cache Statistics") {
                    HStack {
                        Text("Memory Cache")
                        Spacer()
                        Text("\(cacheStats.memoryCount) items")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Disk Cache")
                        Spacer()
                        Text(cacheStats.diskSize)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Performance Analysis") {
                    let slowest = performanceMonitor.getSlowestOperations()
                    if !slowest.isEmpty {
                        ForEach(slowest, id: \.0) { operation, time in
                            PerformanceAnalysisRow(operation: operation, time: time)
                        }
                    } else {
                        Text("No performance data available")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("System Information") {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Build Number")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Device")
                        Spacer()
                        Text(UIDevice.current.model)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("iOS Version")
                        Spacer()
                        Text(UIDevice.current.systemVersion)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section {
                    Button("Clear Performance Data", role: .destructive) {
                        performanceMonitor.clearMetrics()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Performance Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await updateCacheStats()
            }
        }
    }
    
    private func updateCacheStats() async {
        // Get the actual cache statistics from DataManager
        let stats = dataManager.getCacheStats()
        
        await MainActor.run {
            cacheStats = stats
        }
    }
}

struct PerformanceAnalysisRow: View {
    let operation: String
    let time: TimeInterval
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(getUserFriendlyOperationName(operation))
                
                if let metrics = performanceMonitor.getPerformanceMetrics(for: operation) {
                    Text("\(metrics.count) runs, avg: \(String(format: "%.2fs", metrics.averageTime))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(String(format: "%.2fs avg", time))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SyncStatusView()
} 