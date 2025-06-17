import SwiftUI
import SwiftData

@MainActor
struct MedicationGridRow: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = AuthenticationService.shared
    @Bindable var dog: Dog
    @State private var showingMedicationAlert = false
    @State private var medicationName = ""
    @State private var medicationNotes = ""
    @State private var showingEditAlert = false
    @State private var showingDeleteAlert = false
    @State private var selectedRecord: MedicationRecord?
    
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
                Spacer()
                Button {
                    showingMedicationAlert = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }
                .disabled(!canModifyRecords)
            }
            
            if dog.isBoarding {
                Text("Boarding")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "pills.fill")
                        .foregroundStyle(.purple)
                    Text("\(dog.medicationRecords.count)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            if !dog.medicationRecords.isEmpty {
                let columns = [
                    GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 8)
                ]
                
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(dog.medicationRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.timestamp) { record in
                        MedicationRecordGridItem(dog: dog, record: record)
                            .disabled(!canModifyRecords)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .alert("Record Medication", isPresented: $showingMedicationAlert) {
            TextField("Medication Name", text: $medicationName)
            TextField("Notes (optional)", text: $medicationNotes)
            Button("Cancel", role: .cancel) {
                medicationName = ""
                medicationNotes = ""
            }
            Button("Add") {
                guard !medicationName.isEmpty else { 
                    showingMedicationAlert = false
                    return 
                }
                let newRecord = MedicationRecord(
                    timestamp: Date(),
                    notes: medicationName + (medicationNotes.isEmpty ? "" : "\n" + medicationNotes),
                    recordedBy: authService.currentUser?.name
                )
                dog.medicationRecords.append(newRecord)
                dog.updatedAt = Date()
                dog.lastModifiedBy = authService.currentUser
                try? modelContext.save()
                medicationName = ""
                medicationNotes = ""
                showingMedicationAlert = false
            }
        } message: {
            Text("Record medication for \(dog.name)")
        }
    }
}

@MainActor
struct MedicationRecordGridItem: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = AuthenticationService.shared
    @Bindable var dog: Dog
    let record: MedicationRecord
    @State private var showingEditAlert = false
    @State private var showingDeleteAlert = false
    @State private var medicationName = ""
    @State private var medicationNotes = ""
    
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
            medicationName = record.notes ?? ""
            medicationNotes = ""
            showingEditAlert = true
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: "pills.fill")
                        .foregroundStyle(.purple)
                    Text(record.notes ?? "No notes")
                        .font(.caption)
                        .lineLimit(1)
                }
                Text(record.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
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
        .alert("Edit Medication Record", isPresented: $showingEditAlert) {
            TextField("Medication Name", text: $medicationName)
            TextField("Notes (optional)", text: $medicationNotes)
            Button("Cancel", role: .cancel) { }
            Button("Update") {
                updateRecord()
            }
        } message: {
            Text("Edit medication record for \(dog.name)")
        }
        .alert("Delete Medication Record", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteRecord()
            }
        } message: {
            Text("Are you sure you want to delete this medication record?")
        }
    }
    
    private func updateRecord() {
        guard let index = dog.medicationRecords.firstIndex(where: { $0.timestamp == record.timestamp }) else { return }
        
        dog.medicationRecords[index] = MedicationRecord(
            timestamp: record.timestamp,
            notes: medicationName + (medicationNotes.isEmpty ? "" : "\n" + medicationNotes),
            recordedBy: authService.currentUser?.name
        )
        dog.updatedAt = Date()
        dog.lastModifiedBy = authService.currentUser
        try? modelContext.save()
        
        showingEditAlert = false
        medicationName = ""
        medicationNotes = ""
    }
    
    private func deleteRecord() {
        dog.medicationRecords.removeAll { $0.timestamp == record.timestamp }
        dog.updatedAt = Date()
        dog.lastModifiedBy = authService.currentUser
        try? modelContext.save()
        
        showingDeleteAlert = false
    }
}
