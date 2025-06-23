import SwiftUI

struct WalkingListView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var authService = AuthenticationService.shared
    
    @State private var searchText = ""
    @State private var showingAddWalking = false
    @State private var selectedDog: Dog?
    @State private var selectedFilter: WalkingFilter = .all
    @State private var selectedSort: WalkingSort = .alphabetical
    
    enum WalkingFilter {
        case all
        case recentActivity
    }
    
    enum WalkingSort {
        case alphabetical
        case recentActivity
    }
    
    private var filteredDogs: [Dog] {
        let dogs = dataManager.dogs.filter { dog in
            if !searchText.isEmpty {
                return dog.name.localizedCaseInsensitiveContains(searchText)
            }
            return true
        }
        
        return dogs.filter { dog in
            dog.isCurrentlyPresent && dog.needsWalking
        }
    }
    
    private var daycareDogs: [Dog] {
        let dogs = filteredDogs.filter { !$0.isBoarding }
        return selectedSort == .recentActivity ? dogs.sorted { dog1, dog2 in
            let dog1Recent = dog1.walkingRecords.contains { record in
                record.timestamp > Date().addingTimeInterval(-3 * 3600) // 3 hours ago
            }
            let dog2Recent = dog2.walkingRecords.contains { record in
                record.timestamp > Date().addingTimeInterval(-3 * 3600) // 3 hours ago
            }
            return dog1Recent && !dog2Recent
        } : dogs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var boardingDogs: [Dog] {
        let dogs = filteredDogs.filter { $0.isBoarding }
        return selectedSort == .recentActivity ? dogs.sorted { dog1, dog2 in
            let dog1Recent = dog1.walkingRecords.contains { record in
                record.timestamp > Date().addingTimeInterval(-3 * 3600) // 3 hours ago
            }
            let dog2Recent = dog2.walkingRecords.contains { record in
                record.timestamp > Date().addingTimeInterval(-3 * 3600) // 3 hours ago
            }
            return dog1Recent && !dog2Recent
        } : dogs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if daycareDogs.isEmpty && boardingDogs.isEmpty {
                    ContentUnavailableView {
                        Label("No Dogs Need Walking", systemImage: "figure.walk")
                    } description: {
                        Text("Dogs that need walking will appear here.")
                    }
                } else {
                    if !daycareDogs.isEmpty {
                        Section {
                            ForEach(daycareDogs) { dog in
                                DogWalkingRow(dog: dog)
                            }
                        } header: {
                            Text("DAYCARE")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                                .textCase(nil)
                        }
                        .listSectionSpacing(20)
                    }
                    
                    if !boardingDogs.isEmpty {
                        Section {
                            ForEach(boardingDogs) { dog in
                                DogWalkingRow(dog: dog)
                            }
                        } header: {
                            Text("BOARDING")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                                .textCase(nil)
                        }
                        .listSectionSpacing(20)
                    }
                }
            }
            .navigationTitle("Walking List")
            .searchable(text: $searchText, prompt: "Search dogs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Alphabetical") {
                            selectedSort = .alphabetical
                        }
                        Button("Recent Activity") {
                            selectedSort = .recentActivity
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddWalking) {
                if let dog = selectedDog {
                    AddWalkingView(dog: dog)
                }
            }
        }
    }
}

struct WalkingFilterButton: View {
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

struct DogWalkingRow: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var authService = AuthenticationService.shared
    let dog: Dog
    @State private var showingDeleteAlert = false
    @State private var showingDeletePottyAlert = false
    @State private var pottyRecordToDelete: PottyRecord?
    @State private var showingPottyPopup = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(dog.name)
                        .font(.headline)
                    if let walkingNotes = dog.walkingNotes, !walkingNotes.isEmpty {
                        Text(walkingNotes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Potty counts
            HStack(spacing: 16) {
                let todaysPottyRecords = dog.pottyRecords.filter { record in
                    Calendar.current.isDate(record.timestamp, inSameDayAs: Date())
                }
                
                let todaysPeeCount = todaysPottyRecords.filter { $0.type == .pee }.count
                let todaysPoopCount = todaysPottyRecords.filter { $0.type == .poop }.count
                
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.yellow)
                    Text("\(todaysPeeCount)")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
                
                HStack {
                    Text("💩")
                    Text("\(todaysPoopCount)")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
                
                Spacer()
            }
            .font(.caption)
            
            // Individual potty instances grid
            if !dog.pottyRecords.isEmpty {
                let todaysPottyRecords = dog.pottyRecords.filter { record in
                    Calendar.current.isDate(record.timestamp, inSameDayAs: Date())
                }
                
                if !todaysPottyRecords.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 4) {
                        ForEach(todaysPottyRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.id) { record in
                            PottyInstanceView(record: record) {
                                pottyRecordToDelete = record
                                showingDeletePottyAlert = true
                            }
                        }
                    }
                }
            }
            
            if !dog.walkingRecords.isEmpty {
                Text("Last walked: \(dog.walkingRecords.last?.timestamp.formatted(date: .abbreviated, time: .shortened) ?? "Never")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            showingPottyPopup = true
        }
        .contextMenu {
            if !dog.pottyRecords.isEmpty {
                let todaysPottyRecords = dog.pottyRecords.filter { record in
                    Calendar.current.isDate(record.timestamp, inSameDayAs: Date())
                }
                
                ForEach(todaysPottyRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.id) { record in
                    if record.type != .nothing {
                        Button("Delete \(record.type.rawValue) at \(record.timestamp.formatted(date: .omitted, time: .shortened))", role: .destructive) {
                            deletePottyRecord(record)
                        }
                    }
                }
            }
        }
        .alert("Record Potty Activity", isPresented: $showingPottyPopup) {
            Button("Peed") { addPottyRecord(.pee) }
            Button("Pooped") { addPottyRecord(.poop) }
            Button("Both") { addPottyRecord(.both) }
            Button("None") { addPottyRecord(.nothing) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Record potty activity for \(dog.name)")
        }
        .alert("Delete Last Walk", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteLastWalk()
            }
        } message: {
            Text("Are you sure you want to delete the last walk for \(dog.name)?")
        }
        .alert("Delete Potty Record", isPresented: $showingDeletePottyAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let record = pottyRecordToDelete {
                    deletePottyRecord(record)
                }
            }
        } message: {
            Text("Are you sure you want to delete this potty record?")
        }
    }
    
    private func addWalkingRecord() {
        var updatedDog = dog
        updatedDog.addWalkingRecord(notes: nil, recordedBy: authService.currentUser)
        
        Task {
            await dataManager.updateDog(updatedDog)
        }
    }
    
    private func deleteLastWalk() {
        var updatedDog = dog
        if let lastWalk = updatedDog.walkingRecords.last {
            updatedDog.removeWalkingRecord(at: lastWalk.timestamp, modifiedBy: authService.currentUser)
            
            Task {
                await dataManager.updateDog(updatedDog)
            }
        }
    }
    
    private func deletePottyRecord(_ record: PottyRecord) {
        Task {
            await dataManager.deletePottyRecord(record, from: dog)
        }
    }
    
    private func addPottyRecord(_ type: PottyRecord.PottyType) {
        var updatedDog = dog
        
        switch type {
        case .both:
            let peeRecord = PottyRecord(timestamp: Date(), type: .pee, recordedBy: authService.currentUser?.name)
            let poopRecord = PottyRecord(timestamp: Date(), type: .poop, recordedBy: authService.currentUser?.name)
            updatedDog.pottyRecords.append(peeRecord)
            updatedDog.pottyRecords.append(poopRecord)
        case .nothing:
            let record = PottyRecord(timestamp: Date(), type: .nothing, recordedBy: authService.currentUser?.name)
            updatedDog.pottyRecords.append(record)
        default:
            let record = PottyRecord(timestamp: Date(), type: type, recordedBy: authService.currentUser?.name)
            updatedDog.pottyRecords.append(record)
        }
        
        updatedDog.updatedAt = Date()
        updatedDog.lastModifiedBy = authService.currentUser
        
        Task {
            await dataManager.updateDog(updatedDog)
        }
    }
}

struct PottyInstanceView: View {
    let record: PottyRecord
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onDelete) {
            HStack(spacing: 4) {
                if record.type == .pee {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.yellow)
                } else if record.type == .poop {
                    Text("💩")
                } else if record.type == .nothing {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                
                Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AddWalkingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    let dog: Dog
    
    @State private var notes = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Dog: \(dog.name)")
                        .font(.headline)
                    
                    if let walkingNotes = dog.walkingNotes, !walkingNotes.isEmpty {
                        Text("Walking Notes: \(walkingNotes)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Walk Details") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Record Walk")
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
                            await recordWalk()
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
    
    private func recordWalk() async {
        isLoading = true
        
        var updatedDog = dog
        updatedDog.addWalkingRecord(notes: notes.isEmpty ? nil : notes, recordedBy: AuthenticationService.shared.currentUser)
        
        await dataManager.updateDog(updatedDog)
        
        isLoading = false
        dismiss()
    }
}

#Preview {
    WalkingListView()
        .environmentObject(DataManager.shared)
} 