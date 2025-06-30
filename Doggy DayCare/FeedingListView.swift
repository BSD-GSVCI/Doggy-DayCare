import SwiftUI

struct FeedingListView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var authService = AuthenticationService.shared
    
    @State private var searchText = ""
    @State private var showingAddFeeding = false
    @State private var selectedDog: Dog?
    @State private var selectedFeedingType: FeedingRecord.FeedingType = .breakfast
    @State private var selectedFilter: FeedingFilter = .all
    
    enum FeedingFilter {
        case all
        case daycare
        case boarding
        case breakfast
        case lunch
        case dinner
        case snack
        case recentActivity
        case alphabetical
    }
    
    private var filteredDogs: [Dog] {
        let dogs = dataManager.dogs.filter { dog in
            if !searchText.isEmpty {
                return dog.name.localizedCaseInsensitiveContains(searchText)
            }
            return true
        }
        
        return dogs.filter { dog in
            dog.isCurrentlyPresent
        }
    }
    
    private func mostRecentFeedingTimestamp(for dog: Dog, type: FeedingRecord.FeedingType) -> Date? {
        let today = Calendar.current.startOfDay(for: Date())
        return dog.feedingRecords
            .filter { $0.type == type && Calendar.current.isDate($0.timestamp, inSameDayAs: today) }
            .map { $0.timestamp }
            .sorted(by: >)
            .first
    }

    private var daycareDogs: [Dog] {
        let dogs = filteredDogs.filter { $0.shouldBeTreatedAsDaycare }
        return selectedFilter == .recentActivity ? dogs.sorted { dog1, dog2 in
            let dog1Recent = dog1.feedingRecords.contains { record in
                record.timestamp > Date().addingTimeInterval(-3 * 3600) // 3 hours ago
            }
            let dog2Recent = dog2.feedingRecords.contains { record in
                record.timestamp > Date().addingTimeInterval(-3 * 3600) // 3 hours ago
            }
            return (dog1Recent ? 1 : 0, dog1.name) < (dog2Recent ? 1 : 0, dog2.name)
        } : dogs.sorted { dog1, dog2 in
            switch selectedFilter {
            case .breakfast:
                let t1 = mostRecentFeedingTimestamp(for: dog1, type: .breakfast)
                let t2 = mostRecentFeedingTimestamp(for: dog2, type: .breakfast)
                return (
                    t1 == nil ? 0 : 1,
                    t1 ?? Date.distantPast,
                    dog1.name
                ) < (
                    t2 == nil ? 0 : 1,
                    t2 ?? Date.distantPast,
                    dog2.name
                )
            case .lunch:
                let t1 = mostRecentFeedingTimestamp(for: dog1, type: .lunch)
                let t2 = mostRecentFeedingTimestamp(for: dog2, type: .lunch)
                return (
                    t1 == nil ? 0 : 1,
                    t1 ?? Date.distantPast,
                    dog1.name
                ) < (
                    t2 == nil ? 0 : 1,
                    t2 ?? Date.distantPast,
                    dog2.name
                )
            case .dinner:
                let t1 = mostRecentFeedingTimestamp(for: dog1, type: .dinner)
                let t2 = mostRecentFeedingTimestamp(for: dog2, type: .dinner)
                return (
                    t1 == nil ? 0 : 1,
                    t1 ?? Date.distantPast,
                    dog1.name
                ) < (
                    t2 == nil ? 0 : 1,
                    t2 ?? Date.distantPast,
                    dog2.name
                )
            case .snack:
                let t1 = mostRecentFeedingTimestamp(for: dog1, type: .snack)
                let t2 = mostRecentFeedingTimestamp(for: dog2, type: .snack)
                return (
                    t1 == nil ? 0 : 1,
                    t1 ?? Date.distantPast,
                    dog1.name
                ) < (
                    t2 == nil ? 0 : 1,
                    t2 ?? Date.distantPast,
                    dog2.name
                )
            default:
                return dog1.name.localizedCaseInsensitiveCompare(dog2.name) == .orderedAscending
            }
        }
    }
    
    private var boardingDogs: [Dog] {
        let dogs = filteredDogs.filter { !$0.shouldBeTreatedAsDaycare }
        return selectedFilter == .recentActivity ? dogs.sorted { dog1, dog2 in
            let dog1Recent = dog1.feedingRecords.contains { record in
                record.timestamp > Date().addingTimeInterval(-3 * 3600) // 3 hours ago
            }
            let dog2Recent = dog2.feedingRecords.contains { record in
                record.timestamp > Date().addingTimeInterval(-3 * 3600) // 3 hours ago
            }
            return (dog1Recent ? 1 : 0, dog1.name) < (dog2Recent ? 1 : 0, dog2.name)
        } : dogs.sorted { dog1, dog2 in
            switch selectedFilter {
            case .breakfast:
                let t1 = mostRecentFeedingTimestamp(for: dog1, type: .breakfast)
                let t2 = mostRecentFeedingTimestamp(for: dog2, type: .breakfast)
                return (
                    t1 == nil ? 0 : 1,
                    t1 ?? Date.distantPast,
                    dog1.name
                ) < (
                    t2 == nil ? 0 : 1,
                    t2 ?? Date.distantPast,
                    dog2.name
                )
            case .lunch:
                let t1 = mostRecentFeedingTimestamp(for: dog1, type: .lunch)
                let t2 = mostRecentFeedingTimestamp(for: dog2, type: .lunch)
                return (
                    t1 == nil ? 0 : 1,
                    t1 ?? Date.distantPast,
                    dog1.name
                ) < (
                    t2 == nil ? 0 : 1,
                    t2 ?? Date.distantPast,
                    dog2.name
                )
            case .dinner:
                let t1 = mostRecentFeedingTimestamp(for: dog1, type: .dinner)
                let t2 = mostRecentFeedingTimestamp(for: dog2, type: .dinner)
                return (
                    t1 == nil ? 0 : 1,
                    t1 ?? Date.distantPast,
                    dog1.name
                ) < (
                    t2 == nil ? 0 : 1,
                    t2 ?? Date.distantPast,
                    dog2.name
                )
            case .snack:
                let t1 = mostRecentFeedingTimestamp(for: dog1, type: .snack)
                let t2 = mostRecentFeedingTimestamp(for: dog2, type: .snack)
                return (
                    t1 == nil ? 0 : 1,
                    t1 ?? Date.distantPast,
                    dog1.name
                ) < (
                    t2 == nil ? 0 : 1,
                    t2 ?? Date.distantPast,
                    dog2.name
                )
            default:
                return dog1.name.localizedCaseInsensitiveCompare(dog2.name) == .orderedAscending
            }
        }
    }
    
    private var dogsNeedingFeeding: [Dog] {
        switch selectedFilter {
        case .all:
            return filteredDogs
        case .daycare:
            return daycareDogs
        case .boarding:
            return boardingDogs
        case .breakfast:
            return filteredDogs.filter { $0.breakfastCount == 0 }
        case .lunch:
            return filteredDogs.filter { $0.lunchCount == 0 }
        case .dinner:
            return filteredDogs.filter { $0.dinnerCount == 0 }
        case .snack:
            return filteredDogs.filter { $0.snackCount == 0 }
        case .recentActivity:
            return filteredDogs
        case .alphabetical:
            return filteredDogs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    if daycareDogs.isEmpty && boardingDogs.isEmpty {
                        ContentUnavailableView {
                            Label("No Dogs Present", systemImage: "fork.knife")
                        } description: {
                            Text("Dogs that are currently present will appear here.")
                        }
                    } else {
                        if !daycareDogs.isEmpty {
                            Section {
                                ForEach(daycareDogs) { dog in
                                    DogFeedingRow(dog: dog)
                                        .buttonStyle(PlainButtonStyle())
                                }
                            } header: {
                                Text("DAYCARE \(daycareDogs.count)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                            }
                            .listSectionSpacing(160)
                        }
                        
                        if !boardingDogs.isEmpty {
                            Section {
                                ForEach(boardingDogs) { dog in
                                    DogFeedingRow(dog: dog)
                                        .buttonStyle(PlainButtonStyle())
                                }
                            } header: {
                                Text("BOARDING \(boardingDogs.count)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                            }
                            .listSectionSpacing(160)
                        }
                    }
                }
            }
            .navigationTitle("Feeding List")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search dogs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            selectedFilter = .alphabetical
                        } label: {
                            Label("Alphabetical", systemImage: selectedFilter == .alphabetical ? "checkmark" : "")
                        }
                        Button {
                            selectedFilter = .breakfast
                        } label: {
                            Label("Breakfast", systemImage: selectedFilter == .breakfast ? "checkmark" : "")
                        }
                        Button {
                            selectedFilter = .lunch
                        } label: {
                            Label("Lunch", systemImage: selectedFilter == .lunch ? "checkmark" : "")
                        }
                        Button {
                            selectedFilter = .dinner
                        } label: {
                            Label("Dinner", systemImage: selectedFilter == .dinner ? "checkmark" : "")
                        }
                        Button {
                            selectedFilter = .snack
                        } label: {
                            Label("Snack", systemImage: selectedFilter == .snack ? "checkmark" : "")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddFeeding) {
                if let dog = selectedDog {
                    AddFeedingView(dog: dog, feedingType: selectedFeedingType)
                }
            }
        }
    }
}

struct FeedingFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct DogFeedingRow: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var authService = AuthenticationService.shared
    let dog: Dog
    @State private var showingDeleteAlert = false
    @State private var showingDeleteFeedingAlert = false
    @State private var feedingRecordToDelete: FeedingRecord?
    @State private var showingFeedingPopup = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(dog.name)
                        .font(.headline)
                    if let allergiesAndFeedingInstructions = dog.allergiesAndFeedingInstructions, !allergiesAndFeedingInstructions.isEmpty {
                        Text(allergiesAndFeedingInstructions)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Feeding counts
            HStack(spacing: 16) {
                let todaysFeedingRecords = dog.feedingRecords.filter { record in
                    Calendar.current.isDate(record.timestamp, inSameDayAs: Date())
                }
                
                let todaysBreakfastCount = todaysFeedingRecords.filter { $0.type == .breakfast }.count
                let todaysLunchCount = todaysFeedingRecords.filter { $0.type == .lunch }.count
                let todaysDinnerCount = todaysFeedingRecords.filter { $0.type == .dinner }.count
                let todaysSnackCount = todaysFeedingRecords.filter { $0.type == .snack }.count
                
                HStack {
                    Image(systemName: "sunrise.fill")
                        .foregroundStyle(.orange)
                    Text("\(todaysBreakfastCount)")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
                
                HStack {
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(.yellow)
                    Text("\(todaysLunchCount)")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
                
                HStack {
                    Image(systemName: "sunset.fill")
                        .foregroundStyle(.red)
                    Text("\(todaysDinnerCount)")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
                
                HStack {
                    Image(systemName: "pawprint.fill")
                        .foregroundStyle(.brown)
                    Text("\(todaysSnackCount)")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
                
                Spacer()
            }
            .font(.caption)
            
            // Individual feeding instances grid
            if !dog.feedingRecords.isEmpty {
                let todaysFeedingRecords = dog.feedingRecords.filter { record in
                    Calendar.current.isDate(record.timestamp, inSameDayAs: Date())
                }
                
                if !todaysFeedingRecords.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 4) {
                        ForEach(todaysFeedingRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.id) { record in
                            FeedingInstanceView(record: record) {
                                feedingRecordToDelete = record
                                showingDeleteFeedingAlert = true
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            showingFeedingPopup = true
        }
        .contextMenu {
            if !dog.feedingRecords.isEmpty {
                let todaysFeedingRecords = dog.feedingRecords.filter { record in
                    Calendar.current.isDate(record.timestamp, inSameDayAs: Date())
                }
                
                ForEach(todaysFeedingRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.id) { record in
                    Button("Delete \(record.type.rawValue) at \(record.timestamp.formatted(date: .omitted, time: .shortened))", role: .destructive) {
                        deleteFeedingRecord(record)
                    }
                }
            }
        }
        .sheet(isPresented: $showingFeedingPopup) {
            FeedingPopupView(dog: dog)
        }
        .alert("Delete Feeding Record", isPresented: $showingDeleteFeedingAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let record = feedingRecordToDelete {
                    deleteFeedingRecord(record)
                }
            }
        } message: {
            Text("Are you sure you want to delete this feeding record?")
        }
    }
    
    private func deleteFeedingRecord(_ record: FeedingRecord) {
        Task {
            await dataManager.deleteFeedingRecord(record, from: dog)
        }
    }
}

struct FeedingInstanceView: View {
    let record: FeedingRecord
    let onDelete: () -> Void
    @EnvironmentObject var dataManager: DataManager
    @State private var showingNoteAlert = false
    @State private var showingEditNote = false
    @State private var editedNotes = ""
    
    var body: some View {
        Button(action: {
            showingNoteAlert = true
        }) {
            HStack(spacing: 2) {
                // Feeding type icon
                Image(systemName: iconForFeedingType(record.type))
                    .foregroundStyle(colorForFeedingType(record.type))
                    .font(.caption)
                
                Spacer(minLength: 2)
                
                // Time
                Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Note icon if record has notes
                if let notes = record.notes, !notes.isEmpty {
                    Text("📝")
                        .font(.caption2)
                        .padding(1)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture {
            onDelete()
        }
        .alert("Feeding Record Notes", isPresented: $showingNoteAlert) {
            if let notes = record.notes, !notes.isEmpty {
                Button("Edit Note") {
                    editedNotes = notes
                    showingEditNote = true
                }
            } else {
                Button("Add Note") {
                    editedNotes = ""
                    showingEditNote = true
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let notes = record.notes, !notes.isEmpty {
                Text(notes)
            } else {
                Text("This record has no notes associated with it.")
            }
        }
        .alert("Edit Note", isPresented: $showingEditNote) {
            TextField("Notes", text: $editedNotes, axis: .vertical)
                .lineLimit(3...6)
            Button("Save") {
                Task {
                    await updateFeedingRecordNotes()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Edit notes for this feeding record")
        }
    }
    
    private func updateFeedingRecordNotes() async {
        // Find the dog that contains this record
        if let dog = dataManager.dogs.first(where: { dog in
            dog.feedingRecords.contains { $0.id == record.id }
        }) {
            await dataManager.updateFeedingRecordNotes(record, newNotes: editedNotes.isEmpty ? nil : editedNotes, in: dog)
        }
    }
    
    private func iconForFeedingType(_ type: FeedingRecord.FeedingType) -> String {
        switch type {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "sunset.fill"
        case .snack: return "pawprint.fill"
        }
    }
    
    private func colorForFeedingType(_ type: FeedingRecord.FeedingType) -> Color {
        switch type {
        case .breakfast: return .orange
        case .lunch: return .yellow
        case .dinner: return .red
        case .snack: return .brown
        }
    }
}

struct FeedingCountView: View {
    let type: String
    let count: Int
    
    var body: some View {
        VStack {
            Text("\(count)")
                .font(.headline)
                .foregroundStyle(.blue)
            Text(type)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct AddFeedingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    let dog: Dog
    let feedingType: FeedingRecord.FeedingType
    
    @State private var notes = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Dog: \(dog.name)")
                        .font(.headline)
                    
                    Text("Type: \(feedingType.rawValue.capitalized)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if let allergiesAndFeedingInstructions = dog.allergiesAndFeedingInstructions, !allergiesAndFeedingInstructions.isEmpty {
                        Text(allergiesAndFeedingInstructions)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Feeding Details") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Record Feeding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Record") {
                        Task {
                            await recordFeeding()
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .overlay {
                if isLoading {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Recording...")
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                }
            }
        }
    }
    
    private func recordFeeding() async {
        isLoading = true
        
        await dataManager.addFeedingRecord(to: dog, type: feedingType, notes: notes.isEmpty ? nil : notes, recordedBy: AuthenticationService.shared.currentUser?.name)
        
        isLoading = false
        dismiss()
    }
}

struct FeedingPopupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var authService = AuthenticationService.shared
    let dog: Dog
    
    @State private var notes = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(dog.name)
                        .font(.headline)
                    
                    if let allergiesAndFeedingInstructions = dog.allergiesAndFeedingInstructions, !allergiesAndFeedingInstructions.isEmpty {
                        Text(allergiesAndFeedingInstructions)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Notes (optional)") {
                    TextField("Add notes for this feeding", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Feeding Type") {
                    Button {
                        addFeedingRecord(.breakfast)
                    } label: {
                        HStack {
                            Image(systemName: "sunrise.fill")
                                .foregroundStyle(.orange)
                            Text("Breakfast")
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    Button {
                        addFeedingRecord(.lunch)
                    } label: {
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .foregroundStyle(.yellow)
                            Text("Lunch")
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    Button {
                        addFeedingRecord(.dinner)
                    } label: {
                        HStack {
                            Image(systemName: "sunset.fill")
                                .foregroundStyle(.red)
                            Text("Dinner")
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    Button {
                        addFeedingRecord(.snack)
                    } label: {
                        HStack {
                            Image(systemName: "pawprint.fill")
                                .foregroundStyle(.brown)
                            Text("Snack")
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Record Feeding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isLoading {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Recording...")
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                }
            }
        }
    }
    
    private func addFeedingRecord(_ type: FeedingRecord.FeedingType) {
        isLoading = true
        Task {
            await dataManager.addFeedingRecord(to: dog, type: type, notes: notes.isEmpty ? nil : notes, recordedBy: authService.currentUser?.name)
            isLoading = false
            dismiss()
        }
    }
}

#Preview {
    FeedingListView()
        .environmentObject(DataManager.shared)
} 