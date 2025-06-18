import SwiftUI
import SwiftData

struct WalkingListView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = AuthenticationService.shared
    @Query(sort: \Dog.name) private var allDogs: [Dog]
    @State private var searchText = ""
    @State private var showingPottyAlert = false
    @State private var selectedDog: Dog?
    @State private var selectedFilter: WalkingFilter = .alphabetical
    
    enum WalkingFilter {
        case alphabetical
        case recentActivity
        
        var title: String {
            switch self {
            case .alphabetical: return "Alphabetical"
            case .recentActivity: return "Recent Activity"
            }
        }
    }
    
    private var canModifyRecords: Bool {
        // Staff can only modify records for current day's dogs
        if let user = authService.currentUser, !user.isOwner {
            return true // Staff can add records for any dog that needs walking
        }
        return true // Owners can modify all records
    }
    
    private var walkingDogs: [Dog] {
        let presentDogs = filteredDogs.filter { dog in
            let isPresent = dog.isCurrentlyPresent
            let isArrivingToday = Calendar.current.isDateInToday(dog.arrivalDate)
            let hasArrived = Calendar.current.dateComponents([.hour, .minute], from: dog.arrivalDate).hour != 0 ||
                            Calendar.current.dateComponents([.hour, .minute], from: dog.arrivalDate).minute != 0
            let isFutureBooking = Calendar.current.startOfDay(for: dog.arrivalDate) > Calendar.current.startOfDay(for: Date())
            
            return (isPresent || (isArrivingToday && !hasArrived)) && !isFutureBooking && dog.needsWalking
        }
        
        // Sort based on selected filter
        return presentDogs.sorted(by: { (dog1: Dog, dog2: Dog) -> Bool in
            switch selectedFilter {
            case .alphabetical:
                return dog1.name.localizedCaseInsensitiveCompare(dog2.name) == .orderedAscending
                
            case .recentActivity:
                let threeHoursAgo = Date().addingTimeInterval(-3 * 60 * 60) // 3 hours ago
                let dog1LastPotty = dog1.pottyRecords
                    .filter { $0.timestamp > threeHoursAgo }
                    .sorted { $0.timestamp > $1.timestamp }
                    .first?.timestamp
                let dog2LastPotty = dog2.pottyRecords
                    .filter { $0.timestamp > threeHoursAgo }
                    .sorted { $0.timestamp > $1.timestamp }
                    .first?.timestamp
                
                // If both have had potty in the last 3 hours, sort by time (most recent first)
                if let time1 = dog1LastPotty, let time2 = dog2LastPotty {
                    return time1 > time2
                }
                // If only one has had potty in the last 3 hours, put the one who hasn't first
                if (dog1LastPotty != nil) != (dog2LastPotty != nil) {
                    return dog1LastPotty == nil
                }
                // If neither has had potty in the last 3 hours, sort alphabetically
                return dog1.name.localizedCaseInsensitiveCompare(dog2.name) == .orderedAscending
            }
        })
    }
    
    private var daycareDogs: [Dog] {
        walkingDogs.filter { !$0.isBoarding }
    }
    
    private var boardingDogs: [Dog] {
        walkingDogs.filter { $0.isBoarding }
    }
    
    private var filteredDogs: [Dog] {
        if searchText.isEmpty {
            return allDogs
        } else {
            return allDogs.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if walkingDogs.isEmpty {
                    ContentUnavailableView(
                        "No Dogs Need Walking",
                        systemImage: "figure.walk",
                        description: Text("Enable walking for dogs in the main list")
                    )
                } else {
                    Section {
                        if daycareDogs.isEmpty {
                            Text("No daycare dogs need walking")
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            ForEach(daycareDogs) { dog in
                                DogWalkingRow(dog: dog, showingPottyAlert: showingPottyAlert(for:))
                            }
                        }
                    } header: {
                        Text("Daycare")
                    }
                    .listSectionSpacing(20)
                    
                    Section {
                        if boardingDogs.isEmpty {
                            Text("No boarding dogs need walking")
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            ForEach(boardingDogs) { dog in
                                DogWalkingRow(dog: dog, showingPottyAlert: showingPottyAlert(for:))
                            }
                        }
                    } header: {
                        Text("Boarding")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search dogs by name")
            .navigationTitle("Walking List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Sort By", selection: $selectedFilter) {
                            Text("Alphabetical").tag(WalkingFilter.alphabetical)
                            Text("Recent Activity").tag(WalkingFilter.recentActivity)
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .menuStyle(.borderlessButton)
                }
            }
        }
        .onAppear {
            print("WalkingListView appeared")
        }
        .alert("Record Potty", isPresented: $showingPottyAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Pee") {
                if let dog = selectedDog {
                    addPottyRecord(for: dog, type: .pee)
                }
            }
            Button("Poop") {
                if let dog = selectedDog {
                    addPottyRecord(for: dog, type: .poop)
                }
            }
            Button("Both") {
                if let dog = selectedDog {
                    addPottyRecord(for: dog, type: .both)
                }
            }
            Button("Nothing") {
                if let dog = selectedDog {
                    addPottyRecord(for: dog, type: .nothing)
                }
            }
        } message: {
            if let dog = selectedDog {
                Text("What did \(dog.name) do?")
            }
        }
    }
    
    private func showingPottyAlert(for dog: Dog) {
        print("Showing potty alert for \(dog.name)")
        selectedDog = dog
        showingPottyAlert = true
    }
    
    private func addPottyRecord(for dog: Dog, type: PottyRecord.PottyType) {
        print("Adding \(type) record for \(dog.name)")
        guard canModifyRecords else { 
            print("Cannot modify records for \(dog.name)")
            return 
        }
        
        switch type {
        case .both:
            // Create two separate records - one for pee and one for poop
            let peeRecord = PottyRecord(timestamp: Date(), type: .pee, recordedBy: authService.currentUser?.name)
            let poopRecord = PottyRecord(timestamp: Date(), type: .poop, recordedBy: authService.currentUser?.name)
            
            modelContext.insert(peeRecord)
            modelContext.insert(poopRecord)
            
            peeRecord.dog = dog
            poopRecord.dog = dog
            
            dog.pottyRecords.append(peeRecord)
            dog.pottyRecords.append(poopRecord)
            
        case .nothing:
            // Create a single "nothing" record that doesn't count toward totals
            let record = PottyRecord(timestamp: Date(), type: .nothing, recordedBy: authService.currentUser?.name)
            modelContext.insert(record)
            record.dog = dog
            dog.pottyRecords.append(record)
            
        default:
            // Regular single record for pee or poop
            let record = PottyRecord(timestamp: Date(), type: type, recordedBy: authService.currentUser?.name)
            modelContext.insert(record)
            record.dog = dog
            dog.pottyRecords.append(record)
        }
        
        // Force a save to ensure the relationship is persisted
        dog.updatedAt = Date()
        dog.lastModifiedBy = authService.currentUser
        
        do {
            try modelContext.save()
            print("Successfully saved potty record for \(dog.name)")
            print("Dog \(dog.name) now has \(dog.pottyRecords.count) potty records")
            print("Record array contents: \(dog.pottyRecords.map { "\($0.type) at \($0.timestamp)" })")
        } catch {
            print("Error saving potty record: \(error)")
        }
    }
}

private struct DogWalkingRow: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = AuthenticationService.shared
    @Bindable var dog: Dog
    let showingPottyAlert: (Dog) -> Void
    @State private var showingEditAlert = false
    @State private var showingDeleteAlert = false
    @State private var selectedRecord: PottyRecord?
    @State private var selectedType: PottyRecord.PottyType?
    @State private var showingNotes = false
    @State private var notes = ""
    
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
                        showingPottyAlert(dog)
                    }
                Spacer()
                if let notes = dog.walkingNotes {
                    Button {
                        self.notes = notes
                        showingNotes = true
                    } label: {
                        Image(systemName: "note.text")
                            .foregroundStyle(.blue)
                    }
                }
            }
            
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.yellow)
                    Text("\(dog.peeCount)")
                }
                HStack {
                    Text("💩")
                    Text("\(dog.poopCount)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            if !dog.pottyRecords.isEmpty {
                let columns = [
                    GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 8)
                ]
                
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(dog.pottyRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.timestamp) { record in
                        PottyRecordGridItem(dog: dog, record: record)
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
        .sheet(isPresented: $showingNotes) {
            NavigationStack {
                Form {
                    Section {
                        Text(notes)
                    } header: {
                        Text("Walking Notes")
                    }
                }
                .navigationTitle("\(dog.name)'s Notes")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingNotes = false
                        }
                    }
                }
            }
        }
    }
}

private struct PottyRecordGridItem: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = AuthenticationService.shared
    let dog: Dog
    let record: PottyRecord
    
    @State private var showingEditAlert = false
    @State private var showingDeleteAlert = false
    @State private var selectedType: PottyRecord.PottyType?
    
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
                if record.type == .pee {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.yellow)
                } else if record.type == .poop {
                    Text("💩")
                } else if record.type == .nothing {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                } else {
                    // This shouldn't happen, but just in case
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.gray)
                }
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
        .alert("Edit Potty Record", isPresented: $showingEditAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Pee") {
                dog.updatePottyRecord(at: record.timestamp, type: .pee, modifiedBy: authService.currentUser)
            }
            Button("Poop") {
                dog.updatePottyRecord(at: record.timestamp, type: .poop, modifiedBy: authService.currentUser)
            }
            Button("Nothing") {
                dog.updatePottyRecord(at: record.timestamp, type: .nothing, modifiedBy: authService.currentUser)
            }
        } message: {
            Text("Change record type for \(dog.name)?")
        }
        .alert("Delete Potty Record", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                dog.removePottyRecord(at: record.timestamp, modifiedBy: authService.currentUser)
            }
        } message: {
            Text("Are you sure you want to delete this record?")
        }
    }
}

#Preview {
    NavigationStack {
        WalkingListView()
    }
    .modelContainer(for: Dog.self, inMemory: true)
} 