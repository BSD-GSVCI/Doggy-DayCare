import SwiftUI
import SwiftData

struct MedicationsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Dog.name) private var allDogs: [Dog]
    @State private var searchText = ""
    
    private var filteredDogs: [Dog] {
        if searchText.isEmpty {
            return allDogs
        } else {
            return allDogs.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var dogsWithMedications: [Dog] {
        filteredDogs.filter { dog in
            let hasMedications = dog.medications != nil && !dog.medications!.isEmpty
            let isPresent = dog.isCurrentlyPresent
            return hasMedications && isPresent
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if dogsWithMedications.isEmpty {
                    ContentUnavailableView(
                        "No Dogs Need Medication",
                        systemImage: "pills.circle",
                        description: Text("Add medication information in the main list")
                    )
                } else {
                    ForEach(dogsWithMedications) { dog in
                        DogMedicationRow(dog: dog)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search dogs by name")
            .navigationTitle("Medications")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct DogMedicationRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var dog: Dog
    @State private var showingMedicationAlert = false
    @State private var medicationNotes = ""
    @State private var showingEditAlert = false
    @State private var showingDeleteAlert = false
    @State private var selectedRecord: MedicationRecord?
    
    private func deleteRecord(_ record: MedicationRecord) {
        withAnimation {
            if let index = dog.medicationRecords.firstIndex(where: { $0.timestamp == record.timestamp }) {
                dog.medicationRecords.remove(at: index)
                dog.updatedAt = Date()
                try? modelContext.save()
            }
        }
    }
    
    private func updateRecord(_ record: MedicationRecord, notes: String) {
        withAnimation {
            if let index = dog.medicationRecords.firstIndex(where: { $0.timestamp == record.timestamp }) {
                let updatedRecord = MedicationRecord(timestamp: record.timestamp, notes: notes.isEmpty ? nil : notes)
                dog.medicationRecords[index] = updatedRecord
                dog.updatedAt = Date()
                try? modelContext.save()
            }
        }
    }
    
    var body: some View {
        Button {
            showingMedicationAlert = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dog.name)
                        .font(.headline)
                    Spacer()
                    Text(dog.formattedStayDuration)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if let medications = dog.medications {
                    Text(medications)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Image(systemName: "pills.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text("\(dog.medicationRecords.count) administrations")
                        .font(.caption)
                }
                
                if !dog.medicationRecords.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(dog.medicationRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.timestamp) { record in
                            HStack {
                                Image(systemName: "pills.fill")
                                    .font(.caption)
                                    .foregroundStyle(.purple)
                                if let notes = record.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                } else {
                                    Text("Medication administered")
                                        .font(.caption)
                                }
                                Spacer()
                                Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Menu {
                                    Button {
                                        selectedRecord = record
                                        medicationNotes = record.notes ?? ""
                                        showingEditAlert = true
                                    } label: {
                                        Label("Edit Notes", systemImage: "pencil")
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
        .alert("Record Medication", isPresented: $showingMedicationAlert) {
            TextField("Notes (optional)", text: $medicationNotes)
            Button("Record Administration") {
                dog.addMedicationRecord(notes: medicationNotes.isEmpty ? nil : medicationNotes)
                medicationNotes = ""
            }
            Button("Cancel", role: .cancel) {
                medicationNotes = ""
            }
        } message: {
            if let medications = dog.medications {
                Text("Record administration of:\n\(medications)")
            } else {
                Text("Record medication administration for \(dog.name)")
            }
        }
        .alert("Edit Medication Record", isPresented: $showingEditAlert) {
            TextField("Notes (optional)", text: $medicationNotes)
            Button("Save") {
                if let record = selectedRecord {
                    updateRecord(record, notes: medicationNotes)
                    medicationNotes = ""
                }
            }
            Button("Cancel", role: .cancel) {
                medicationNotes = ""
            }
        } message: {
            if let medications = dog.medications {
                Text("Edit notes for medication:\n\(medications)")
            } else {
                Text("Edit medication record notes")
            }
        }
        .alert("Delete Medication Record", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let record = selectedRecord {
                    deleteRecord(record)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this medication record?")
        }
    }
}

#Preview {
    NavigationStack {
        MedicationsListView()
    }
    .modelContainer(for: Dog.self, inMemory: true)
} 