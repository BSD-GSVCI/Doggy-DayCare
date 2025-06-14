import SwiftUI
import SwiftData

struct FeedingListView: View {
    @Environment(\.modelContext) private var modelContext
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
                }
            }
        }
    }
}

private struct DogFeedingRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var dog: Dog
    @State private var showingFeedingAlert = false
    @State private var showingEditAlert = false
    @State private var showingDeleteAlert = false
    @State private var selectedRecord: FeedingRecord?
    @State private var selectedType: FeedingRecord.FeedingType?
    
    private func deleteRecord(_ record: FeedingRecord) {
        withAnimation {
            if let index = dog.feedingRecords.firstIndex(where: { $0.timestamp == record.timestamp }) {
                dog.feedingRecords.remove(at: index)
                dog.updatedAt = Date()
                try? modelContext.save()
            }
        }
    }
    
    private func updateRecord(_ record: FeedingRecord, type: FeedingRecord.FeedingType) {
        withAnimation {
            if let index = dog.feedingRecords.firstIndex(where: { $0.timestamp == record.timestamp }) {
                let updatedRecord = FeedingRecord(timestamp: record.timestamp, type: type)
                dog.feedingRecords[index] = updatedRecord
                dog.updatedAt = Date()
                try? modelContext.save()
            }
        }
    }
    
    var body: some View {
        Button {
            showingFeedingAlert = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dog.name)
                            .font(.headline)
                        
                        if dog.isBoarding {
                            Text("Boarding")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .clipShape(Capsule())
                        } else {
                            Text("Daycare")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    
                    Spacer()
                    
                    if dog.isDaycareFed {
                        Text("Daycare Feeds")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                
                if let notes = dog.specialInstructions {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "sunrise.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("\(dog.breakfastCount)")
                            .font(.caption)
                    }
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                        Text("\(dog.lunchCount)")
                            .font(.caption)
                    }
                    HStack {
                        Image(systemName: "sunset.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Text("\(dog.dinnerCount)")
                            .font(.caption)
                    }
                    HStack {
                        Image(systemName: "pawprint.fill")
                            .font(.caption)
                            .foregroundStyle(.brown)
                        Text("\(dog.snackCount)")
                            .font(.caption)
                    }
                }
                
                if !dog.feedingRecords.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(dog.feedingRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.timestamp) { record in
                            HStack {
                                Image(systemName: iconForFeedingType(record.type))
                                    .font(.caption)
                                    .foregroundStyle(colorForFeedingType(record.type))
                                Text(record.type.rawValue.capitalized)
                                    .font(.caption)
                                Spacer()
                                Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Menu {
                                    Button {
                                        selectedRecord = record
                                        selectedType = record.type
                                        showingEditAlert = true
                                    } label: {
                                        Label("Change Type", systemImage: "arrow.triangle.2.circlepath")
                                    }
                                    
                                    Button(role: .destructive) {
                                        selectedRecord = record
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.leading)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .alert("Record Feeding", isPresented: $showingFeedingAlert) {
            Button("Breakfast") {
                dog.addFeedingRecord(type: .breakfast)
            }
            Button("Lunch") {
                dog.addFeedingRecord(type: .lunch)
            }
            Button("Dinner") {
                dog.addFeedingRecord(type: .dinner)
            }
            Button("Snack") {
                dog.addFeedingRecord(type: .snack)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("What did \(dog.name) eat?")
        }
        .alert("Edit Feeding Record", isPresented: $showingEditAlert) {
            Button("Breakfast") {
                if let record = selectedRecord {
                    updateRecord(record, type: .breakfast)
                }
            }
            Button("Lunch") {
                if let record = selectedRecord {
                    updateRecord(record, type: .lunch)
                }
            }
            Button("Dinner") {
                if let record = selectedRecord {
                    updateRecord(record, type: .dinner)
                }
            }
            Button("Snack") {
                if let record = selectedRecord {
                    updateRecord(record, type: .snack)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Change feeding type to:")
        }
        .alert("Delete Feeding Record", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let record = selectedRecord {
                    deleteRecord(record)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let record = selectedRecord {
                Text("Are you sure you want to delete this \(record.type.rawValue) record?")
            } else {
                Text("Are you sure you want to delete this feeding record?")
            }
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