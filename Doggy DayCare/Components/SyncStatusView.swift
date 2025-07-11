import SwiftUI

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
                        Text(performanceMonitor.currentOperation)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("\(Int(performanceMonitor.syncProgress * 100))% complete")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        showingPerformanceReport = true
                    } label: {
                        Image(systemName: "speedometer")
                            .font(.caption)
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
                        .font(.caption)
                    
                    Text("Last sync: \(lastSync.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        showingPerformanceReport = true
                    } label: {
                        Image(systemName: "speedometer")
                            .font(.caption)
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
    @StateObject private var advancedCache = AdvancedCache.shared
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
                    
                    ForEach(Array(performanceMonitor.syncTimes.keys.sorted()), id: \.self) { operation in
                        if let time = performanceMonitor.syncTimes[operation] {
                            HStack {
                                Text(operation)
                                Spacer()
                                Text(String(format: "%.2fs", time))
                                    .foregroundStyle(.secondary)
                            }
                        }
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
                            HStack {
                                Text(operation)
                                Spacer()
                                Text(String(format: "%.2fs avg", time))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("No performance data available")
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
                cacheStats = await advancedCache.getCacheStats()
            }
        }
    }
}

#Preview {
    SyncStatusView()
} 