import SwiftUI
import SwiftData

struct MedicationsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allDogs: [Dog]
    
    private var dogsWithMedications: [Dog] {
        allDogs.filter { dog in
            let hasMedications = dog.medications != nil && !dog.medications!.isEmpty
            let isPresent = dog.isCurrentlyPresent
            return hasMedications && isPresent
        }
    }
    
    var body: some View {
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
        .navigationTitle("Medications")
    }
}

private struct DogMedicationRow: View {
    @Bindable var dog: Dog
    @State private var showingMedicationAlert = false
    @State private var medicationNotes = ""
    
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
                
                if let medications = dog.medications, !medications.isEmpty {
                    Text(medications)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Image(systemName: "pills.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text("\(dog.medicationCount) in total")
                        .font(.caption)
                }
                
                if !dog.medicationRecords.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(dog.medicationRecords.sorted(by: { $0.timestamp > $1.timestamp }).prefix(3), id: \.timestamp) { record in
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
                            }
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
    }
}

#Preview {
    NavigationStack {
        MedicationsListView()
    }
    .modelContainer(for: Dog.self, inMemory: true)
} 