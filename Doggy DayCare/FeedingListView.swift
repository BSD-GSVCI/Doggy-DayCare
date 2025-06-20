import SwiftUI
import SwiftData

struct FeedingListView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = AuthenticationService.shared
    @Query(sort: \Dog.name) private var allDogs: [Dog]
    @State private var searchText = ""
    @State private var selectedFilter: FeedingFilter = .alphabetical
    
    enum FeedingFilter {
        case alphabetical
        case breakfast
        case lunch
        case dinner
        case snack
        
        var title: String {
            switch self {
            case .alphabetical: return "Alphabetical"
            case .breakfast: return "Breakfast"
            case .lunch: return "Lunch"
            case .dinner: return "Dinner"
            case .snack: return "Snack"
            }
        }
    }
    
    private var filteredDogs: [Dog] {
        if searchText.isEmpty {
            return allDogs
        } else {
            return allDogs.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var feedingDogs: [Dog] {
        let presentDogs = filteredDogs.filter { dog in
            let isPresent = dog.isCurrentlyPresent
            let isArrivingToday = Calendar.current.isDateInToday(dog.arrivalDate)
            let hasArrived = Calendar.current.dateComponents([.hour, .minute], from: dog.arrivalDate).hour != 0 ||
                            Calendar.current.dateComponents([.hour, .minute], from: dog.arrivalDate).minute != 0
            let isFutureBooking = Calendar.current.startOfDay(for: dog.arrivalDate) > Calendar.current.startOfDay(for: Date())
            
            return (isPresent || (isArrivingToday && !hasArrived)) && !isFutureBooking
        }
        
        // Sort based on selected filter
        return presentDogs.sorted(by: { (dog1: Dog, dog2: Dog) -> Bool in
            switch selectedFilter {
            case .alphabetical:
                return dog1.name.localizedCaseInsensitiveCompare(dog2.name) == .orderedAscending
                
            case .breakfast:
                let dog1LastBreakfast = dog1.feedingRecords
                    .filter { $0.type == .breakfast && Calendar.current.isDateInToday($0.timestamp) }
                    .sorted { $0.timestamp > $1.timestamp }
                    .first?.timestamp
                let dog2LastBreakfast = dog2.feedingRecords
                    .filter { $0.type == .breakfast && Calendar.current.isDateInToday($0.timestamp) }
                    .sorted { $0.timestamp > $1.timestamp }
                    .first?.timestamp
                
                // If both have had breakfast today, sort by time (most recent first)
                if let time1 = dog1LastBreakfast, let time2 = dog2LastBreakfast {
                    return time1 > time2
                }
                // If only one has had breakfast, put the one who hasn't first
                if (dog1LastBreakfast != nil) != (dog2LastBreakfast != nil) {
                    return dog1LastBreakfast == nil
                }
                // If neither has had breakfast, sort alphabetically
                return dog1.name.localizedCaseInsensitiveCompare(dog2.name) == .orderedAscending
                
            case .lunch:
                let dog1LastLunch = dog1.feedingRecords
                    .filter { $0.type == .lunch && Calendar.current.isDateInToday($0.timestamp) }
                    .sorted { $0.timestamp > $1.timestamp }
                    .first?.timestamp
                let dog2LastLunch = dog2.feedingRecords
                    .filter { $0.type == .lunch && Calendar.current.isDateInToday($0.timestamp) }
                    .sorted { $0.timestamp > $1.timestamp }
                    .first?.timestamp
                
                // If both have had lunch today, sort by time (most recent first)
                if let time1 = dog1LastLunch, let time2 = dog2LastLunch {
                    return time1 > time2
                }
                // If only one has had lunch, put the one who hasn't first
                if (dog1LastLunch != nil) != (dog2LastLunch != nil) {
                    return dog1LastLunch == nil
                }
                // If neither has had lunch, sort alphabetically
                return dog1.name.localizedCaseInsensitiveCompare(dog2.name) == .orderedAscending
                
            case .dinner:
                let dog1LastDinner = dog1.feedingRecords
                    .filter { $0.type == .dinner && Calendar.current.isDateInToday($0.timestamp) }
                    .sorted { $0.timestamp > $1.timestamp }
                    .first?.timestamp
                let dog2LastDinner = dog2.feedingRecords
                    .filter { $0.type == .dinner && Calendar.current.isDateInToday($0.timestamp) }
                    .sorted { $0.timestamp > $1.timestamp }
                    .first?.timestamp
                
                // If both have had dinner today, sort by time (most recent first)
                if let time1 = dog1LastDinner, let time2 = dog2LastDinner {
                    return time1 > time2
                }
                // If only one has had dinner, put the one who hasn't first
                if (dog1LastDinner != nil) != (dog2LastDinner != nil) {
                    return dog1LastDinner == nil
                }
                // If neither has had dinner, sort alphabetically
                return dog1.name.localizedCaseInsensitiveCompare(dog2.name) == .orderedAscending
                
            case .snack:
                let dog1LastSnack = dog1.feedingRecords
                    .filter { $0.type == .snack && Calendar.current.isDateInToday($0.timestamp) }
                    .sorted { $0.timestamp > $1.timestamp }
                    .first?.timestamp
                let dog2LastSnack = dog2.feedingRecords
                    .filter { $0.type == .snack && Calendar.current.isDateInToday($0.timestamp) }
                    .sorted { $0.timestamp > $1.timestamp }
                    .first?.timestamp
                
                // If both have had a snack today, sort by time (most recent first)
                if let time1 = dog1LastSnack, let time2 = dog2LastSnack {
                    return time1 > time2
                }
                // If only one has had a snack, put the one who hasn't first
                if (dog1LastSnack != nil) != (dog2LastSnack != nil) {
                    return dog1LastSnack == nil
                }
                // If neither has had a snack, sort alphabetically
                return dog1.name.localizedCaseInsensitiveCompare(dog2.name) == .orderedAscending
            }
        })
    }
    
    private var daycareDogs: [Dog] {
        feedingDogs.filter { !$0.isBoarding }
    }
    
    private var boardingDogs: [Dog] {
        feedingDogs.filter { $0.isBoarding }
    }
    
    private var canModifyRecords: Bool {
        // Staff can only modify records for current day's dogs
        if let user = authService.currentUser, !user.isOwner {
            return true // Staff can add records for any dog that needs feeding
        }
        return true // Owners can modify all records
    }
    
    var body: some View {
        NavigationStack {
            List {
                if feedingDogs.isEmpty {
                    ContentUnavailableView(
                        "No Dogs Present",
                        systemImage: "fork.knife",
                        description: Text("Add dogs to see them in the feeding list")
                    )
                } else {
                    Section {
                        if daycareDogs.isEmpty {
                            Text("No daycare dogs present")
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            ForEach(daycareDogs) { dog in
                                DogFeedingRow(dog: dog)
                            }
                        }
                    } header: {
                        Text("Daycare")
                    }
                    .listSectionSpacing(20)
                    
                    Section {
                        if boardingDogs.isEmpty {
                            Text("No boarding dogs present")
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            ForEach(boardingDogs) { dog in
                                DogFeedingRow(dog: dog)
                            }
                        }
                    } header: {
                        Text("Boarding")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search dogs by name")
            .navigationTitle("Feeding List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Sort By", selection: $selectedFilter) {
                            Text("Alphabetical").tag(FeedingFilter.alphabetical)
                            Text("Breakfast").tag(FeedingFilter.breakfast)
                            Text("Lunch").tag(FeedingFilter.lunch)
                            Text("Dinner").tag(FeedingFilter.dinner)
                            Text("Snack").tag(FeedingFilter.snack)
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .menuStyle(.borderlessButton)
                }
            }
        }
    }
}

private struct DogFeedingRow: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = AuthenticationService.shared
    @Bindable var dog: Dog
    @State private var showingFeedingAlert = false
    @State private var feedingNotes = ""
    @State private var showingEditAlert = false
    @State private var showingDeleteAlert = false
    @State private var selectedRecord: FeedingRecord?
    @State private var selectedType: FeedingRecord.FeedingType?
    
    private var canModifyRecords: Bool {
        // Staff can only modify records for current day's dogs
        if let user = authService.currentUser, !user.isOwner {
            return Calendar.current.isDateInToday(dog.arrivalDate) && dog.isCurrentlyPresent
        }
        return true // Owners can modify all records
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(dog.name)
                    .font(.headline)
                    .onTapGesture {
                        showingFeedingAlert = true
                    }
                Spacer()
            }
            
            // Show allergies and feeding instructions if available
            if let allergiesAndFeeding = dog.allergiesAndFeedingInstructions, !allergiesAndFeeding.isEmpty {
                Text(allergiesAndFeeding)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "sunrise.fill")
                        .foregroundStyle(.orange)
                    Text("\(dog.breakfastCount)")
                }
                HStack {
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(.yellow)
                    Text("\(dog.lunchCount)")
                }
                HStack {
                    Image(systemName: "sunset.fill")
                        .foregroundStyle(.red)
                    Text("\(dog.dinnerCount)")
                }
                HStack {
                    Image(systemName: "pawprint.fill")
                        .foregroundStyle(.brown)
                    Text("\(dog.snackCount)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            if !dog.feedingRecords.isEmpty {
                let columns = [
                    GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 8)
                ]
                
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(dog.feedingRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.timestamp) { record in
                        FeedingRecordGridItem(dog: dog, record: record)
                            .disabled(!canModifyRecords)
                    }
                }
                .padding(.top, 4)
            } else {
                Color.clear
                    .frame(height: 0)
            }
        }
        .padding(.vertical, 4)
        .alert("Record Feeding", isPresented: $showingFeedingAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Breakfast") {
                print("Adding breakfast record for \(dog.name)")
                addFeedingRecord(for: dog, type: .breakfast)
            }
            Button("Lunch") {
                print("Adding lunch record for \(dog.name)")
                addFeedingRecord(for: dog, type: .lunch)
            }
            Button("Dinner") {
                print("Adding dinner record for \(dog.name)")
                addFeedingRecord(for: dog, type: .dinner)
            }
            Button("Snack") {
                print("Adding snack record for \(dog.name)")
                addFeedingRecord(for: dog, type: .snack)
            }
        } message: {
            Text("Record feeding for \(dog.name)")
        }
    }
    
    private func addFeedingRecord(for dog: Dog, type: FeedingRecord.FeedingType) {
        print("Adding \(type) record for \(dog.name)")
        guard canModifyRecords else { 
            print("Cannot modify records for \(dog.name)")
            return 
        }
        
        let record = FeedingRecord(timestamp: Date(), type: type, recordedBy: authService.currentUser?.name)
        print("Created feeding record: \(record)")
        modelContext.insert(record)
        print("Inserted feeding record into model context")
        
        // Set the inverse relationship
        record.dog = dog
        
        // Ensure the relationship is properly established
        dog.feedingRecords.append(record)
        print("Added feeding record to dog's feedingRecords array. Count before: \(dog.feedingRecords.count - 1), count after: \(dog.feedingRecords.count)")
        
        // Force a save to ensure the relationship is persisted
        dog.updatedAt = Date()
        dog.lastModifiedBy = authService.currentUser
        
        do {
            try modelContext.save()
            print("Successfully saved feeding record for \(dog.name)")
            print("Dog \(dog.name) now has \(dog.feedingRecords.count) feeding records")
            print("Feeding record array contents: \(dog.feedingRecords.map { "\($0.type) at \($0.timestamp)" })")
        } catch {
            print("Error saving feeding record: \(error)")
        }
    }
}

private struct FeedingRecordGridItem: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = AuthenticationService.shared
    let dog: Dog
    let record: FeedingRecord
    
    @State private var showingEditAlert = false
    @State private var showingDeleteAlert = false
    @State private var selectedType: FeedingRecord.FeedingType?
    
    private var canModifyRecords: Bool {
        // Staff can only modify records for current day's dogs
        if let user = authService.currentUser, !user.isOwner {
            return Calendar.current.isDateInToday(dog.arrivalDate) && dog.isCurrentlyPresent
        }
        return true // Owners can modify all records
    }
    
    var body: some View {
        Button {
            guard canModifyRecords else { return }
            showingEditAlert = true
            selectedType = record.type
        } label: {
            HStack {
                Image(systemName: iconForFeedingType(record.type))
                    .foregroundStyle(colorForFeedingType(record.type))
                Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!canModifyRecords)
        .contextMenu {
            if canModifyRecords {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Edit Feeding Record", isPresented: $showingEditAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Breakfast") {
                updateRecord(type: .breakfast)
            }
            Button("Lunch") {
                updateRecord(type: .lunch)
            }
            Button("Dinner") {
                updateRecord(type: .dinner)
            }
            Button("Snack") {
                updateRecord(type: .snack)
            }
        } message: {
            Text("Change feeding type for \(dog.name)?")
        }
        .alert("Delete Feeding Record", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteRecord()
            }
        } message: {
            Text("Are you sure you want to delete this feeding record?")
        }
    }
    
    private func updateRecord(type: FeedingRecord.FeedingType) {
        guard canModifyRecords else { return }
        if let index = dog.feedingRecords.firstIndex(where: { $0.timestamp == record.timestamp }) {
            let updatedRecord = FeedingRecord(
                timestamp: record.timestamp,
                type: type,
                recordedBy: authService.currentUser?.id
            )
            dog.feedingRecords[index] = updatedRecord
            dog.updatedAt = Date()
            dog.lastModifiedBy = authService.currentUser
            try? modelContext.save()
        }
    }
    
    private func deleteRecord() {
        guard canModifyRecords else { return }
        if let index = dog.feedingRecords.firstIndex(where: { $0.timestamp == record.timestamp }) {
            dog.feedingRecords.remove(at: index)
            dog.updatedAt = Date()
            dog.lastModifiedBy = authService.currentUser
            try? modelContext.save()
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

#Preview {
    NavigationStack {
        FeedingListView()
    }
    .modelContainer(for: Dog.self, inMemory: true)
} 