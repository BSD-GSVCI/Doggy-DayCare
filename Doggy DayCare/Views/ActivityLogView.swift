import SwiftUI
import CloudKit

struct ActivityLogView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var logs: [ActivityLogRecord] = []
    @State private var isLoading = false
    @State private var lastSyncTime: Date = Date.distantPast
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var showingDatePicker = false
    
    private var availableDates: [Date] {
        let dates = Set(logs.map { Calendar.current.startOfDay(for: $0.timestamp) })
        return Array(dates).sorted(by: >)
    }
    
    private var filteredLogs: [ActivityLogRecord] {
        logs.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: selectedDate) }
            .sorted { $0.timestamp > $1.timestamp }
    }
    
    var body: some View {
        VStack {
            // Title and refresh at the very top
            HStack {
                Text("Activity Logs")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    Task {
                        isLoading = true
                        let newLogs = (try? await CloudKitService.shared.fetchActivityLogsIncremental(since: lastSyncTime)) ?? []
                        if !newLogs.isEmpty {
                            logs.append(contentsOf: newLogs)
                            logs = Array(Set(logs)).sorted { $0.timestamp > $1.timestamp }
                        }
                        lastSyncTime = Date()
                        isLoading = false
                    }
                } label: {
                    if isLoading {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 4)
            // Date picker button
            Button {
                showingDatePicker = true
            } label: {
                HStack {
                    Image(systemName: "calendar")
                    Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)
                    Spacer()
                    // Removed the chevron icon
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .sheet(isPresented: $showingDatePicker) {
                VStack {
                    DatePicker(
                        "Select Date",
                        selection: $selectedDate,
                        in: availableDates.min()!...availableDates.max()!,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding()
                    Button("Done") {
                        showingDatePicker = false
                    }
                    .padding(.bottom)
                }
                .presentationDetents([.medium, .large])
            }
            // Days recorded label
            if !availableDates.isEmpty {
                Text("\(availableDates.count) days recorded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            // Log list
            if isLoading && logs.isEmpty {
                ProgressView("Loading activity logs...")
            } else if filteredLogs.isEmpty {
                ContentUnavailableView {
                    Label("No Activity Logs", systemImage: "tray.full")
                } description: {
                    Text("No activity logs recorded for this date.")
                }
            } else {
                List(filteredLogs) { log in
                    VStack(alignment: .leading) {
                        Text("\(log.action) by \(log.userName)")
                            .font(.headline)
                        if let dogName = log.dogName {
                            Text("Dog: \(dogName)")
                                .font(.subheadline)
                        }
                        if let details = log.details {
                            Text(details)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            Task {
                isLoading = true
                await CloudKitService.shared.loadActivityLogCacheFromDisk()
                logs = CloudKitService.shared.getCachedActivityLogs().sorted { $0.timestamp > $1.timestamp }
                lastSyncTime = logs.first?.timestamp ?? Date.distantPast
                // Default to today if available, else most recent date
                let today = Calendar.current.startOfDay(for: Date())
                let available = Set(logs.map { Calendar.current.startOfDay(for: $0.timestamp) })
                if !available.isEmpty && !available.contains(today) {
                    selectedDate = available.sorted(by: >).first ?? today
                }
                // Trigger background incremental sync
                let newLogs = (try? await CloudKitService.shared.fetchActivityLogsIncremental(since: lastSyncTime)) ?? []
                if !newLogs.isEmpty {
                    logs.append(contentsOf: newLogs)
                    logs = Array(Set(logs)).sorted { $0.timestamp > $1.timestamp }
                    lastSyncTime = logs.first?.timestamp ?? lastSyncTime
                }
                isLoading = false
            }
        }
    }
}

#Preview {
    ActivityLogView()
        .environmentObject(DataManager.shared)
} 