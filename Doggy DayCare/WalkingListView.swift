import SwiftUI
import Foundation

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
        case daycare
        case boarding
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
        switch selectedFilter {
        case .all:
            return dogs.filter { $0.isCurrentlyPresent && $0.needsWalking }
        case .daycare:
            return dogs.filter { $0.isCurrentlyPresent && $0.needsWalking && $0.shouldBeTreatedAsDaycare }
        case .boarding:
            return dogs.filter { $0.isCurrentlyPresent && $0.needsWalking && !$0.shouldBeTreatedAsDaycare }
        case .recentActivity:
            return dogs.filter { $0.isCurrentlyPresent && $0.needsWalking } // You can refine this if needed
        }
    }
    
    private func hadRecentPotty(for dog: Dog) -> Bool {
        let threeHoursAgo = Date().addingTimeInterval(-3 * 3600)
        return dog.pottyRecords.contains { $0.timestamp > threeHoursAgo }
    }
    
    private var daycareDogs: [Dog] {
        let dogs = filteredDogs.filter { $0.shouldBeTreatedAsDaycare }
        return selectedSort == .recentActivity ? dogs.sorted { dog1, dog2 in
            let dog1Recent = hadRecentPotty(for: dog1)
            let dog2Recent = hadRecentPotty(for: dog2)
            return (dog1Recent ? 1 : 0, dog1.name) < (dog2Recent ? 1 : 0, dog2.name)
        } : dogs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var boardingDogs: [Dog] {
        let dogs = filteredDogs.filter { !$0.shouldBeTreatedAsDaycare }
        return selectedSort == .recentActivity ? dogs.sorted { dog1, dog2 in
            let dog1Recent = hadRecentPotty(for: dog1)
            let dog2Recent = hadRecentPotty(for: dog2)
            return (dog1Recent ? 1 : 0, dog1.name) < (dog2Recent ? 1 : 0, dog2.name)
        } : dogs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter carousel
                HStack(spacing: 12) {
                    ContentFilterButton(title: "All", isSelected: selectedFilter == .all) { selectedFilter = .all }
                    ContentFilterButton(title: "Daycare", isSelected: selectedFilter == .daycare) { selectedFilter = .daycare }
                    ContentFilterButton(title: "Boarding", isSelected: selectedFilter == .boarding) { selectedFilter = .boarding }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)
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
                                Text("DAYCARE \(daycareDogs.count)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                            }
                        }
                        if !boardingDogs.isEmpty {
                            Section {
                                ForEach(boardingDogs) { dog in
                                    DogWalkingRow(dog: dog)
                                }
                            } header: {
                                Text("BOARDING \(boardingDogs.count)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                            }
                        }
                    }
                }
                .refreshable {
                    await dataManager.fetchDogsIncremental()
                }
            }
            .navigationTitle("Walking List")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search dogs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            selectedSort = .alphabetical
                        } label: {
                            Label("Alphabetical", systemImage: selectedSort == .alphabetical ? "checkmark" : "")
                        }
                        Button {
                            selectedSort = .recentActivity
                        } label: {
                            Label("Recent Activity", systemImage: selectedSort == .recentActivity ? "checkmark" : "")
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
            .imageOverlay()
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
                DogProfilePicture(dog: dog, size: 40)
                    .padding(.trailing, 8)
                
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
                
                let todaysPeeCount = todaysPottyRecords.filter { $0.type == .pee || $0.type == .both }.count
                let todaysPoopCount = todaysPottyRecords.filter { $0.type == .poop || $0.type == .both }.count
                
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 15))
                    Text("\(todaysPeeCount)")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
                
                HStack {
                    Text("💩")
                        .font(.system(size: 15))
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
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 4) {
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
                    Button("Delete \(record.type.rawValue) at \(record.timestamp.formatted(date: .omitted, time: .shortened))", role: .destructive) {
                        deletePottyRecord(record)
                    }
                }
            }
        }
        .sheet(isPresented: $showingPottyPopup) {
            PottyPopupView(dog: dog)
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
        Task {
            await dataManager.addWalkingRecord(to: dog, notes: nil, recordedBy: authService.currentUser?.name)
        }
    }
    
    private func deleteLastWalk() {
        if let lastWalk = dog.walkingRecords.last {
            Task {
                await dataManager.deleteWalkingRecord(lastWalk, from: dog)
            }
        }
    }
    
    private func deletePottyRecord(_ record: PottyRecord) {
        Task {
            await dataManager.deletePottyRecord(record, from: dog)
        }
    }
}

struct PottyInstanceView: View {
    let record: PottyRecord
    let onDelete: () -> Void
    @EnvironmentObject var dataManager: DataManager
    @State private var showingNoteAlert = false
    @State private var showingEditNote = false
    @State private var editedNotes = ""
    @State private var showingEditTimestamp = false
    @State private var editedTimestamp = Date()
    @State private var showingEditSheet = false
    @State private var editMode: EditMode = .note
    
    enum EditMode {
        case note
        case timestamp
    }
    
    var body: some View {
        Button(action: {
            showingNoteAlert = true
        }) {
            HStack(spacing: 2) {
                if record.type == .both {
                    HStack(spacing: 1) {
                        Image(systemName: iconForPottyType(record.type))
                            .foregroundStyle(colorForPottyType(record.type))
                            .font(.caption2)
                        Text("💩")
                            .font(.caption2)
                    }
                } else {
                    Image(systemName: iconForPottyType(record.type))
                        .foregroundStyle(colorForPottyType(record.type))
                        .font(.caption)
                }
                Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(1.0)
                if let notes = record.notes, !notes.isEmpty {
                    Text("📝")
                        .font(.caption2)
                        .padding(1)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture {
            onDelete()
        }
        .alert("Potty Record Options", isPresented: $showingNoteAlert) {
            if let notes = record.notes, !notes.isEmpty {
                Button("Edit Note") {
                    editMode = .note
                    editedNotes = notes
                    showingEditSheet = true
                }
            } else {
                Button("Add Note") {
                    editMode = .note
                    editedNotes = ""
                    showingEditSheet = true
                }
            }
            Button("Edit Timestamp") {
                editMode = .timestamp
                editedTimestamp = record.timestamp
                showingEditSheet = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let notes = record.notes, !notes.isEmpty {
                Text(notes)
            } else {
                Text("This record has no notes associated with it.")
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                VStack(spacing: 20) {
                    if editMode == .note {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Edit Note")
                                .font(.headline)
                                .padding(.top)
                            
                            TextField("Notes", text: $editedNotes, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                        }
                        .padding()
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Edit Timestamp")
                                .font(.headline)
                                .padding(.top)
                            
                            DatePicker("Timestamp", selection: $editedTimestamp, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                        }
                        .padding()
                    }
                    
                    Spacer()
                }
                .navigationTitle(editMode == .note ? "Edit Note" : "Edit Timestamp")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingEditSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                if editMode == .note {
                                    await updatePottyRecordNotes()
                                } else {
                                    await updatePottyRecordTimestamp()
                                }
                                showingEditSheet = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func updatePottyRecordNotes() async {
        // Find the dog that contains this record
        if let dog = dataManager.dogs.first(where: { dog in
            dog.pottyRecords.contains { $0.id == record.id }
        }) {
            await dataManager.updatePottyRecordNotes(record, newNotes: editedNotes.isEmpty ? nil : editedNotes, in: dog)
        }
    }
    
    private func updatePottyRecordTimestamp() async {
        if let dog = dataManager.dogs.first(where: { dog in
            dog.pottyRecords.contains { $0.id == record.id }
        }) {
            await dataManager.updatePottyRecordTimestamp(record, newTimestamp: editedTimestamp, in: dog)
        }
    }
    
    private func iconForPottyType(_ type: PottyRecord.PottyType) -> String {
        switch type {
        case .pee:
            return "drop.fill"
        case .poop:
            return "circle.fill"
        case .both:
            return "drop.fill" // This will be combined with emoji in the view
        case .nothing:
            return "xmark.circle.fill"
        }
    }
    
    private func colorForPottyType(_ type: PottyRecord.PottyType) -> Color {
        switch type {
        case .pee:
            return .yellow
        case .poop:
            return .brown
        case .both:
            return .yellow
        case .nothing:
            return .red
        }
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
        
        await dataManager.addWalkingRecord(to: dog, notes: notes.isEmpty ? nil : notes, recordedBy: AuthenticationService.shared.currentUser?.name)
        
        isLoading = false
        dismiss()
    }
}

struct PottyPopupView: View {
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
                    
                    if let walkingNotes = dog.walkingNotes, !walkingNotes.isEmpty {
                        Text("Walking Notes: \(walkingNotes)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Notes (optional)") {
                    TextField("Add notes for this potty activity", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Potty Activity") {
                    Button {
                        addPottyRecord(.pee)
                    } label: {
                        HStack {
                            Image(systemName: "drop.fill")
                                .foregroundStyle(.yellow)
                            Text("Peed")
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    Button {
                        addPottyRecord(.poop)
                    } label: {
                        HStack {
                            Text("💩")
                            Text("Pooped")
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    Button {
                        addPottyRecord(.both)
                    } label: {
                        HStack {
                            HStack(spacing: 2) {
                                Image(systemName: "drop.fill")
                                    .foregroundStyle(.yellow)
                                Text("💩")
                            }
                            Text("Both")
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    Button {
                        addPottyRecord(.nothing)
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("None")
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Record Potty")
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
    
    private func addPottyRecord(_ type: PottyRecord.PottyType) {
        isLoading = true
        Task {
            await dataManager.addPottyRecord(to: dog, type: type, notes: notes.isEmpty ? nil : notes, recordedBy: authService.currentUser?.name)
            isLoading = false
            dismiss()
        }
    }
}

#Preview {
    WalkingListView()
        .environmentObject(DataManager.shared)
} 
