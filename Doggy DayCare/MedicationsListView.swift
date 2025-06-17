import SwiftUI
import SwiftData

struct MedicationsListView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = AuthenticationService.shared
    @Query(sort: \Dog.name) private var allDogs: [Dog]
    @State private var searchText = ""
    
    private var filteredDogs: [Dog] {
        if searchText.isEmpty {
            return allDogs
        } else {
            return allDogs.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var medicatedDogs: [Dog] {
        let presentDogs = filteredDogs.filter { dog in
            let isPresent = dog.isCurrentlyPresent
            let isArrivingToday = Calendar.current.isDateInToday(dog.arrivalDate)
            let hasArrived = Calendar.current.dateComponents([.hour, .minute], from: dog.arrivalDate).hour != 0 ||
                            Calendar.current.dateComponents([.hour, .minute], from: dog.arrivalDate).minute != 0
            let isFutureBooking = Calendar.current.startOfDay(for: dog.arrivalDate) > Calendar.current.startOfDay(for: Date())
            
            return (isPresent || (isArrivingToday && !hasArrived)) && !isFutureBooking && dog.medications != nil && !dog.medications!.isEmpty
        }
        
        return presentDogs
    }
    
    private var daycareDogs: [Dog] {
        medicatedDogs.filter { !$0.isBoarding }
    }
    
    private var boardingDogs: [Dog] {
        medicatedDogs.filter { $0.isBoarding }
    }
    
    private var canModifyRecords: Bool {
        // Staff can only modify records for current day's dogs
        if let user = authService.currentUser, !user.isOwner {
            return true // Staff can add records for any dog that needs medication
        }
        return true // Owners can modify all records
    }
    
    var body: some View {
        NavigationStack {
            List {
                if medicatedDogs.isEmpty {
                    ContentUnavailableView(
                        "No Dogs Need Medication",
                        systemImage: "pills.circle",
                        description: Text("Add medication information in the main list")
                    )
                } else {
                    Section {
                        if daycareDogs.isEmpty {
                            Text("No daycare dogs need medication")
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            ForEach(daycareDogs) { dog in
                                DogMedicationRow(dog: dog)
                            }
                        }
                    } header: {
                        Text("Daycare")
                    }
                    .listSectionSpacing(20)
                    
                    Section {
                        if boardingDogs.isEmpty {
                            Text("No boarding dogs need medication")
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            ForEach(boardingDogs) { dog in
                                DogMedicationRow(dog: dog)
                            }
                        }
                    } header: {
                        Text("Boarding")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search dogs by name")
            .navigationTitle("Medications List")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct DogMedicationRow: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = AuthenticationService.shared
    @Bindable var dog: Dog
    @State private var showingMedicationAlert = false
    @State private var medicationNotes = ""
    @State private var showingEditAlert = false
    @State private var showingDeleteAlert = false
    @State private var selectedRecord: MedicationRecord?
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
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
                        showingMedicationAlert = true
                    }
                Spacer()
            }
            
            if let medications = dog.medications {
                Text(medications)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "pills.fill")
                        .foregroundStyle(.purple)
                    Text("\(dog.medicationCount)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            if !dog.medicationRecords.isEmpty {
                ForEach(dog.medicationRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.timestamp) { record in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Administered at \(record.timestamp, formatter: timeFormatter)")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            Menu {
                                Button("Delete", role: .destructive) {
                                    deleteMedicationRecord(record)
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let notes = record.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 24)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding(.top, 4)
            } else {
                Color.clear
                    .frame(height: 0)
            }
        }
        .padding(.vertical, 4)
        .alert("Record Medication", isPresented: $showingMedicationAlert) {
            TextField("Notes (optional)", text: $medicationNotes)
            Button("Cancel", role: .cancel) { 
                medicationNotes = ""
            }
            Button("Record") {
                print("Adding medication record with notes for \(dog.name)")
                addMedicationRecord(for: dog, notes: medicationNotes.isEmpty ? nil : medicationNotes)
                medicationNotes = ""
            }
        } message: {
            Text("Record medication for \(dog.name)")
        }
    }
    
    private func addMedicationRecord(for dog: Dog, notes: String?) {
        print("Adding medication record for \(dog.name)")
        guard canModifyRecords else { 
            print("Cannot modify records for \(dog.name)")
            return 
        }
        
        let record = MedicationRecord(timestamp: Date(), notes: notes, recordedBy: authService.currentUser?.name)
        print("Created medication record: \(record)")
        modelContext.insert(record)
        print("Inserted medication record into model context")
        
        // Set the inverse relationship
        record.dog = dog
        
        // Ensure the relationship is properly established
        dog.medicationRecords.append(record)
        print("Added medication record to dog's medicationRecords array. Count before: \(dog.medicationRecords.count - 1), count after: \(dog.medicationRecords.count)")
        
        // Force a save to ensure the relationship is persisted
        dog.updatedAt = Date()
        dog.lastModifiedBy = authService.currentUser
        
        do {
            try modelContext.save()
            print("Successfully saved medication record for \(dog.name)")
            print("Dog \(dog.name) now has \(dog.medicationRecords.count) medication records")
            print("Medication record array contents: \(dog.medicationRecords.map { "notes: \($0.notes ?? "none") at \($0.timestamp)" })")
        } catch {
            print("Error saving medication record: \(error)")
        }
    }
    
    private func deleteMedicationRecord(_ record: MedicationRecord) {
        guard canModifyRecords else { return }
        if let index = dog.medicationRecords.firstIndex(where: { $0.timestamp == record.timestamp }) {
            print("Deleting medication record at index \(index) for \(dog.name)")
            dog.medicationRecords.remove(at: index)
            dog.updatedAt = Date()
            dog.lastModifiedBy = authService.currentUser
            try? modelContext.save()
        }
    }
}

#Preview {
    NavigationStack {
        MedicationsListView()
    }
    .modelContainer(for: Dog.self, inMemory: true)
} 