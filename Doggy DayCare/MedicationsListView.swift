import SwiftUI

struct MedicationsListView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var authService = AuthenticationService.shared
    
    @State private var searchText = ""
    @State private var showingAddMedication = false
    @State private var selectedDog: Dog?
    @State private var selectedFilter: MedicationFilter = .all
    @State private var selectedSort: MedicationSort = .alphabetical
    @State private var showingDeleteAlert = false
    @State private var showingDeleteMedicationAlert = false
    @State private var medicationRecordToDelete: MedicationRecord?
    @State private var showingMedicationPopup = false
    @State private var medicationNotes = ""
    @State private var editingMedicationRecord: MedicationRecord?
    
    enum MedicationFilter {
        case all
        case daycare
        case boarding
        case needsMedication
        case medicatedToday
        case notMedicatedToday
    }
    
    enum MedicationSort {
        case alphabetical
        case recentAdministration
    }
    
    private var filteredDogs: [Dog] {
        let dogs = dataManager.dogs.filter { dog in
            if !searchText.isEmpty {
                return dog.name.localizedCaseInsensitiveContains(searchText)
            }
            return true
        }
        
        return dogs.filter { dog in
            dog.isCurrentlyPresent && !(dog.medications?.isEmpty ?? true)
        }
    }
    
    private var dogsNeedingMedication: [Dog] {
        let filtered = filteredDogs
        
        return selectedSort == .recentAdministration ? filtered.sorted { dog1, dog2 in
            let dog1Recent = dog1.medicationRecords.contains { record in
                record.timestamp > Date().addingTimeInterval(-3 * 3600) // 3 hours ago
            }
            let dog2Recent = dog2.medicationRecords.contains { record in
                record.timestamp > Date().addingTimeInterval(-3 * 3600) // 3 hours ago
            }
            return dog1Recent && !dog2Recent
        } : filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var daycareDogs: [Dog] {
        dogsNeedingMedication.filter { $0.shouldBeTreatedAsDaycare }
    }
    private var boardingDogs: [Dog] {
        dogsNeedingMedication.filter { !$0.shouldBeTreatedAsDaycare }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if daycareDogs.isEmpty && boardingDogs.isEmpty {
                    ContentUnavailableView {
                        Label("No Dogs Need Medication", systemImage: "pills")
                    } description: {
                        Text("Dogs that need medication will appear here.")
                    }
                } else {
                    if !daycareDogs.isEmpty {
                        Section {
                            ForEach(daycareDogs) { dog in
                                DogMedicationRow(dog: dog)
                                    .buttonStyle(PlainButtonStyle())
                            }
                        } header: {
                            Text("DAYCARE \(daycareDogs.count)")
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
                                DogMedicationRow(dog: dog)
                                    .buttonStyle(PlainButtonStyle())
                            }
                        } header: {
                            Text("BOARDING \(boardingDogs.count)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                                .textCase(nil)
                        }
                        .listSectionSpacing(20)
                    }
                }
            }
            .navigationTitle("Medications")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search dogs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Alphabetical") {
                            selectedSort = .alphabetical
                        }
                        Button("Recent Administration") {
                            selectedSort = .recentAdministration
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddMedication) {
                if let dog = selectedDog {
                    AddMedicationView(dog: dog)
                }
            }
        }
    }
}

struct MedicationFilterButton: View {
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

struct DogMedicationRow: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var authService = AuthenticationService.shared
    let dog: Dog
    @State private var showingDeleteAlert = false
    @State private var showingDeleteMedicationAlert = false
    @State private var medicationRecordToDelete: MedicationRecord?
    @State private var showingMedicationPopup = false
    @State private var medicationNotes = ""
    @State private var editingMedicationRecord: MedicationRecord?
    
    private func editMedicationRecord(_ record: MedicationRecord) {
        editingMedicationRecord = record
    }
    
    private func updateMedicationRecordNotes(_ record: MedicationRecord, newNote: String?) {
        Task {
            if let dogIndex = dataManager.dogs.firstIndex(where: { $0.id == dog.id }) {
                var updatedDog = dataManager.dogs[dogIndex]
                updatedDog.updateMedicationRecord(at: record.timestamp, notes: newNote, modifiedBy: authService.currentUser)
                await dataManager.updateDog(updatedDog)
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(dog.name)
                        .font(.headline)
                }
                
                Spacer()
            }
            
            // Medication type and count
            if let medications = dog.medications, !medications.isEmpty {
                Text(medications)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Medication count
            HStack(spacing: 16) {
                let todaysMedicationRecords = dog.medicationRecords.filter { record in
                    Calendar.current.isDate(record.timestamp, inSameDayAs: Date())
                }
                
                let todaysMedicationCount = todaysMedicationRecords.count
                
                HStack {
                    Image(systemName: "pills.fill")
                        .foregroundStyle(.purple)
                    Text("\(todaysMedicationCount)")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
                
                Spacer()
            }
            .font(.caption)
            
            // Individual medication instances grid
            if !dog.medicationRecords.isEmpty {
                let todaysMedicationRecords = dog.medicationRecords.filter { record in
                    Calendar.current.isDate(record.timestamp, inSameDayAs: Date())
                }
                if !todaysMedicationRecords.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 4) {
                        ForEach(todaysMedicationRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.id) { record in
                            MedicationInstanceView(
                                record: record,
                                onUpdateNote: { newNotes in updateMedicationRecordNotes(record, newNote: newNotes) },
                                onDelete: { medicationRecordToDelete = record; showingDeleteMedicationAlert = true }
                            )
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            showingMedicationPopup = true
        }
        .contextMenu {
            // Only allow deletion via long-press
            if !dog.medicationRecords.isEmpty {
                let todaysMedicationRecords = dog.medicationRecords.filter { record in
                    Calendar.current.isDate(record.timestamp, inSameDayAs: Date())
                }
                ForEach(todaysMedicationRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.id) { record in
                    Button("Delete medication at \(record.timestamp.formatted(date: .omitted, time: .shortened))", role: .destructive) {
                        deleteMedicationRecord(record)
                    }
                }
            }
        }
        .alert("Record Medication", isPresented: $showingMedicationPopup) {
            TextField("Notes (optional)", text: $medicationNotes)
            Button("Cancel", role: .cancel) { }
            Button("Record") {
                let notesToSave = medicationNotes  // Capture the value before resetting
                medicationNotes = ""  // Reset the state variable
                Task {
                    await addMedicationRecord(notes: notesToSave)
                }
            }
        } message: {
            Text("Add notes for \(dog.name)'s medication")
        }
        .alert("Delete Last Medication", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteLastMedication()
            }
        } message: {
            Text("Are you sure you want to delete the last medication for \(dog.name)?")
        }
        .alert("Delete Medication Record", isPresented: $showingDeleteMedicationAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let record = medicationRecordToDelete {
                    deleteMedicationRecord(record)
                }
            }
        } message: {
            Text("Are you sure you want to delete this medication record?")
        }
    }
    
    private func addMedicationRecord(notes: String) async {
        print("🔄 DogMedicationRow.addMedicationRecord called for \(dog.name)")
        print("📝 Notes parameter: '\(notes)'")
        print("📝 Notes isEmpty: \(notes.isEmpty)")
        
        await dataManager.addMedicationRecord(to: dog, notes: notes.isEmpty ? nil : notes, recordedBy: authService.currentUser?.name)
        print("✅ Medication record added for \(dog.name)")
    }
    
    private func deleteLastMedication() {
        if let lastMedication = dog.medicationRecords.last {
            Task {
                await dataManager.deleteMedicationRecord(lastMedication, from: dog)
            }
        }
    }
    
    private func deleteMedicationRecord(_ record: MedicationRecord) {
        Task {
            await dataManager.deleteMedicationRecord(record, from: dog)
        }
    }
}

struct MedicationInstanceView: View {
    let record: MedicationRecord
    let onUpdateNote: (String?) -> Void
    let onDelete: () -> Void
    @State private var showingNoteAlert = false
    @State private var showingEditNote = false
    @State private var editedNotes = ""
    
    var body: some View {
        Button(action: {
            showingNoteAlert = true
        }) {
            HStack(spacing: 2) {
                Image(systemName: "pills.fill")
                    .foregroundStyle(.purple)
                    .font(.caption)
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
        .alert("Medication Record Notes", isPresented: $showingNoteAlert) {
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
                onUpdateNote(editedNotes.isEmpty ? nil : editedNotes)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Edit notes for this medication record")
        }
    }
}

struct AddMedicationView: View {
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
                    
                    if let medications = dog.medications, !medications.isEmpty {
                        Text("Medications: \(medications)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Medication Details") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Record Medication")
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
                            await recordMedication()
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
    
    private func recordMedication() async {
        isLoading = true
        
        await dataManager.addMedicationRecord(to: dog, notes: notes.isEmpty ? nil : notes, recordedBy: AuthenticationService.shared.currentUser?.name)
        
        isLoading = false
        dismiss()
    }
}

#Preview {
    MedicationsListView()
        .environmentObject(DataManager.shared)
} 
