import SwiftUI

struct HistoryView: View {
    @ObservedObject private var cloudKitHistoryService = CloudKitHistoryService.shared
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedDate = Date()
    @State private var searchText = ""
    @State private var selectedFilter: HistoryFilter = .all
    @State private var showingDatePicker = false
    @State private var showingExportSheet = false
    @State private var availableDates: [Date] = []
    @State private var filteredRecords: [DogHistoryRecord] = []
    @State private var isLoading = false
    
    enum HistoryFilter {
        case all
        case daycare
        case boarding
        case departed
    }
    
    private func loadHistoryData() async {
        // isLoading is already set to true when task starts
        
        availableDates = await cloudKitHistoryService.getAvailableDates()
        let records = await cloudKitHistoryService.getHistoryForDate(selectedDate)
        #if DEBUG
        print("[HistoryView] Loaded \(records.count) records for \(selectedDate): \(records.map { $0.dogName })")
        #endif
        
        // Break down the complex filter logic
        let filtered = records.filter { record in
            if searchText.isEmpty {
                return true
            }
            
            let dogNameMatch = record.dogName.localizedCaseInsensitiveContains(searchText)
            let ownerNameMatch = record.ownerName?.localizedCaseInsensitiveContains(searchText) ?? false
            
            return dogNameMatch || ownerNameMatch
        }
        
        switch selectedFilter {
        case .all:
            filteredRecords = filtered
        case .daycare:
            filteredRecords = filtered.filter { !$0.isBoarding }
        case .boarding:
            filteredRecords = filtered.filter { $0.isBoarding }
        case .departed:
            filteredRecords = filtered.filter { record in
                guard let departureDate = record.departureDate else { return false }
                let isSameDay = Calendar.current.isDate(departureDate, inSameDayAs: selectedDate)
                return isSameDay
            }
        }
        
        isLoading = false
    }
    
    private func loadHistoryDataFromCloud() async {
        // Always force a full sync from CloudKit
        let records = await cloudKitHistoryService.updateCacheForDate(selectedDate)
        #if DEBUG
        print("[HistoryView] Forced CloudKit sync: loaded \(records.count) records for \(selectedDate)")
        #endif
        // Apply the same filtering logic as loadHistoryData
        let filtered = records.filter { record in
            if searchText.isEmpty {
                return true
            }
            let dogNameMatch = record.dogName.localizedCaseInsensitiveContains(searchText)
            let ownerNameMatch = record.ownerName?.localizedCaseInsensitiveContains(searchText) ?? false
            return dogNameMatch || ownerNameMatch
        }
        switch selectedFilter {
        case .all:
            filteredRecords = filtered
        case .daycare:
            filteredRecords = filtered.filter { !$0.isBoarding }
        case .boarding:
            filteredRecords = filtered.filter { $0.isBoarding }
        case .departed:
            filteredRecords = filtered.filter { record in
                guard let departureDate = record.departureDate else { return false }
                let isSameDay = Calendar.current.isDate(departureDate, inSameDayAs: selectedDate)
                return isSameDay
            }
        }
    }
    
    private var presentRecords: [DogHistoryRecord] {
        filteredRecords.filter { $0.isCurrentlyPresent }
    }
    
    private var departedRecords: [DogHistoryRecord] {
        filteredRecords.filter { record in
            guard let departureDate = record.departureDate else { return false }
            let isSameDay = Calendar.current.isDate(departureDate, inSameDayAs: selectedDate)
            return isSameDay
        }
    }
    
    private var boardingRecords: [DogHistoryRecord] {
        filteredRecords.filter { $0.isBoarding }
    }
    
    private var daycareRecords: [DogHistoryRecord] {
        filteredRecords.filter { !$0.isBoarding }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date selector
                VStack(spacing: 4) {
                    HStack {
                        Button {
                            showingDatePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "calendar")
                                let dateText = selectedDate.formatted(date: .abbreviated, time: .omitted)
                                Text(dateText)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(.blue)
                        }
                        
                        Spacer()
                        
                        Button {
                            DispatchQueue.main.async {
                                isLoading = true
                            }
                            Task {
                                // Take a new snapshot for the selected date using the current main page dogs
                                await cloudKitHistoryService.recordSnapshot(for: selectedDate, dogs: dataManager.dogs)
                                // Reload history data for the selected date
                                await loadHistoryData()
                                isLoading = false
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Full Refresh")
                                }
                                .foregroundStyle(.blue)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if !availableDates.isEmpty {
                        Text("\(availableDates.count) days recorded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Filter buttons
                HStack(spacing: 12) {
                    ContentFilterButton(title: "All", isSelected: selectedFilter == .all) {
                        selectedFilter = .all
                    }
                    
                    ContentFilterButton(title: "Daycare", isSelected: selectedFilter == .daycare) {
                        selectedFilter = .daycare
                    }
                    
                    ContentFilterButton(title: "Boarding", isSelected: selectedFilter == .boarding) {
                        selectedFilter = .boarding
                    }
                    
                    ContentFilterButton(title: "Departed", isSelected: selectedFilter == .departed) {
                        selectedFilter = .departed
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Records list
                if isLoading || cloudKitHistoryService.isLoading {
                    VStack(spacing: 16) {
                        ProgressView("Loading history data...")
                            .scaleEffect(1.2)
                        
                        if cloudKitHistoryService.isLoading {
                            Text("Syncing with CloudKit...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if isLoading {
                            Text("Processing data...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredRecords.isEmpty {
                    let dateString = selectedDate.formatted(date: .abbreviated, time: .omitted)
                    ContentUnavailableView {
                        Label("No Records Found", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("No dog records found for \(dateString).")
                    }
                } else {
                    List {
                        if !presentRecords.isEmpty {
                            Section {
                                ForEach(presentRecords) { record in
                                    HistoryDogRow(record: record)
                                }
                            } header: {
                                Text("PRESENT \(presentRecords.count)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                            }
                        }
                        
                        if !departedRecords.isEmpty {
                            Section {
                                ForEach(departedRecords) { record in
                                    HistoryDogRow(record: record)
                                }
                            } header: {
                                Text("DEPARTED \(departedRecords.count)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                            }
                        }
                        
                        if !boardingRecords.isEmpty && selectedFilter == .boarding {
                            Section {
                                ForEach(boardingRecords) { record in
                                    HistoryDogRow(record: record)
                                }
                            } header: {
                                Text("BOARDING \(boardingRecords.count)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                            }
                        }
                        
                        if !daycareRecords.isEmpty && selectedFilter == .daycare {
                            Section {
                                ForEach(daycareRecords) { record in
                                    HistoryDogRow(record: record)
                                }
                            } header: {
                                Text("DAYCARE \(daycareRecords.count)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search dogs by name or owner")
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Load from cache only, no spinner, no forced sync
                Task {
                    await loadHistoryData()
                }
            }
            .onChange(of: selectedDate) {
                Task {
                    isLoading = true
                    await loadHistoryData()
                    isLoading = false
                }
            }
            .onChange(of: searchText) {
                Task {
                    isLoading = true
                    await loadHistoryData()
                    isLoading = false
                }
            }
            .onChange(of: selectedFilter) {
                Task {
                    isLoading = true
                    await loadHistoryData()
                    isLoading = false
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingExportSheet = true
                        } label: {
                            Label("Export History", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(role: .destructive) {
                            Task {
                                await cloudKitHistoryService.cleanupOldRecords()
                                await loadHistoryData()
                            }
                        } label: {
                            Label("Cleanup Old Records", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationStack {
                    DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .navigationTitle("Select Date")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    showingDatePicker = false
                                }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showingDatePicker = false
                                }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingExportSheet) {
                NavigationStack {
                    ExportHistoryView()
                }
            }
        }
    }
}

struct HistoryDogRow: View {
    let record: DogHistoryRecord
    @State private var showingDetail = false
    
    private let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy"
        return formatter
    }()
    
    private let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        Button {
            showingDetail = true
        } label: {
            HStack {
                // Profile picture
                if let profilePictureData = record.profilePictureData,
                   let uiImage = UIImage(data: profilePictureData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "dog.fill")
                        .font(.title2)
                        .foregroundStyle(.gray)
                        .frame(width: 50, height: 50)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(record.dogName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        if record.needsWalking {
                            Image(systemName: "figure.walk")
                                .foregroundStyle(.blue)
                                .font(.caption)
                        }
                        
                        if !record.medications.isEmpty {
                            Image(systemName: "pills")
                                .foregroundStyle(.purple)
                                .font(.caption)
                        }
                    }
                    
                    if let ownerName = record.ownerName {
                        Text(ownerName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Service type and status
                    HStack(spacing: 4) {
                        Text(record.serviceType)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(record.isBoarding ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                            .foregroundStyle(record.isBoarding ? .blue : .green)
                            .clipShape(Capsule())
                        
                        Text(record.statusDescription)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(record.isCurrentlyPresent ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                            .foregroundStyle(record.isCurrentlyPresent ? .green : .red)
                            .clipShape(Capsule())
                    }
                    
                    // Times
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Arrival: \(shortDateFormatter.string(from: record.arrivalDate)) \(shortTimeFormatter.string(from: record.arrivalDate))")
                            .font(.caption)
                            .foregroundStyle(.green)
                        
                        if let departureDate = record.departureDate {
                            Text("Departure: \(shortDateFormatter.string(from: departureDate)) \(shortTimeFormatter.string(from: departureDate))")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        
                        if record.isBoarding, let boardingEndDate = record.boardingEndDate {
                            Text("Until: \(shortDateFormatter.string(from: boardingEndDate))")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            NavigationStack {
                HistoryDogDetailView(record: record)
            }
        }
    }
}

struct HistoryDogDetailView: View {
    let record: DogHistoryRecord
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section("Basic Information") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(record.dogName)
                        .foregroundStyle(.secondary)
                }
                
                if let ownerName = record.ownerName {
                    HStack {
                        Text("Owner")
                        Spacer()
                        Text(ownerName)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack {
                    Text("Service Type")
                    Spacer()
                    Text(record.serviceType)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Status")
                    Spacer()
                    Text(record.statusDescription)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Schedule") {
                HStack {
                    Text("Arrival Date")
                    Spacer()
                    Text(record.formattedArrivalTime)
                        .foregroundStyle(.secondary)
                }
                
                if record.departureDate != nil {
                    HStack {
                        Text("Departure Date")
                        Spacer()
                        Text(record.formattedDepartureTime!)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if record.isBoarding, let boardingEndDate = record.boardingEndDate {
                    HStack {
                        Text("Boarding End Date")
                        Spacer()
                        Text(boardingEndDate.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if !record.medications.isEmpty {
                Section("Medical Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(record.medications) { medication in
                            HStack {
                                Image(systemName: medication.type == .daily ? "pills.fill" : "clock.fill")
                                    .foregroundStyle(medication.type == .daily ? .purple : .orange)
                                Text(medication.name)
                                    .font(.subheadline)
                                if let notes = medication.notes, !notes.isEmpty {
                                    Text("📝")
                                        .font(.caption)
                                }
                                Spacer()
                                Text(medication.type.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            
            if let specialInstructions = record.specialInstructions, !specialInstructions.isEmpty {
                Section("Special Instructions") {
                    Text(specialInstructions)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let allergiesAndFeedingInstructions = record.allergiesAndFeedingInstructions, !allergiesAndFeedingInstructions.isEmpty {
                Section("Allergies & Feeding") {
                    Text(allergiesAndFeedingInstructions)
                        .foregroundStyle(.secondary)
                }
            }
            
            if record.needsWalking {
                Section("Walking") {
                    HStack {
                        Text("Needs Walking")
                        Spacer()
                        Text("Yes")
                            .foregroundStyle(.secondary)
                    }
                    
                    if let walkingNotes = record.walkingNotes, !walkingNotes.isEmpty {
                        Text(walkingNotes)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if let notes = record.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let age = record.age {
                Section("Additional Information") {
                    HStack {
                        Text("Age")
                        Spacer()
                        Text("\(age) years")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if let gender = record.gender {
                Section("Additional Information") {
                    HStack {
                        Text("Gender")
                        Spacer()
                        Text(gender.displayName)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(record.dogName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

struct ExportHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cloudKitHistoryService = CloudKitHistoryService.shared
    @State private var csvData: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Export History")
                .font(.headline)
                .padding(.top)
            
            Text("Export all historical dog records as a CSV file.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Export includes:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Dog names and owner information")
                    Text("• Service type (boarding/daycare)")
                    Text("• Arrival and departure times")
                    Text("• Medical information and special instructions")
                    Text("• Historical data from all recorded dates")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Spacer()
            
            Button {
                Task {
                    csvData = await cloudKitHistoryService.exportHistoryRecords()
                    let activityVC = UIActivityViewController(activityItems: [csvData], applicationActivities: nil)
                
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController?.present(activityVC, animated: true)
                    }
                    
                    dismiss()
                }
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export CSV")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal)
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    HistoryView()
        .environmentObject(DataManager.shared)
} 