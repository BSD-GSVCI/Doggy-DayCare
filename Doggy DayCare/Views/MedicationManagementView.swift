import SwiftUI

struct MedicationManagementView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var authService = AuthenticationService.shared
    let dog: Dog
    
    @State private var showingAddMedication = false
    @State private var showingAddScheduledMedication = false
    @State private var selectedMedication: Medication?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Daily Medications
            if !dog.dailyMedications.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Medications")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    ForEach(dog.dailyMedications) { medication in
                        DailyMedicationRow(
                            medication: medication,
                            onDelete: {
                                deleteMedication(medication)
                            }
                        )
                    }
                }
            }
            
            // Scheduled Medications
            if !dog.scheduledMedications.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scheduled Medications")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    ForEach(dog.scheduledMedications) { scheduledMedication in
                        ScheduledMedicationRow(
                            scheduledMedication: scheduledMedication,
                            medication: dog.medications.first { $0.id == scheduledMedication.medicationId },
                            onDelete: {
                                deleteScheduledMedication(scheduledMedication)
                            }
                        )
                    }
                }
            }
            
            // Add Medication Buttons
            VStack(alignment: .leading, spacing: 12) {
                Button("Add Daily Medication") {
                    showingAddMedication = true
                }
                .foregroundStyle(.blue)
                .buttonStyle(.plain)
                
                Button("Add/Edit Scheduled Medication") {
                    showingAddScheduledMedication = true
                }
                .foregroundStyle(.blue)
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingAddMedication) {
            AddMedicationSheet(
                dog: dog,
                medicationType: .daily,
                onSave: { medication in
                    addMedication(medication)
                }
            )
        }
        .sheet(isPresented: $showingAddScheduledMedication) {
            AddScheduledMedicationSheet(
                dog: dog,
                onSave: { scheduledMedication in
                    addScheduledMedication(scheduledMedication)
                },
                onAddMedication: { medication in
                    addMedication(medication)
                }
            )
        }
    }
    
    private func addMedication(_ medication: Medication) {
        Task {
            if let dogIndex = dataManager.dogs.firstIndex(where: { $0.id == dog.id }) {
                var updatedDog = dataManager.dogs[dogIndex]
                updatedDog.addMedication(medication, createdBy: authService.currentUser)
                await dataManager.updateDogMedications(updatedDog, medications: updatedDog.medications, scheduledMedications: updatedDog.scheduledMedications)
            }
        }
    }
    
    private func deleteMedication(_ medication: Medication) {
        Task {
            if let dogIndex = dataManager.dogs.firstIndex(where: { $0.id == dog.id }) {
                var updatedDog = dataManager.dogs[dogIndex]
                updatedDog.removeMedication(medication, modifiedBy: authService.currentUser)
                await dataManager.updateDogMedications(updatedDog, medications: updatedDog.medications, scheduledMedications: updatedDog.scheduledMedications)
            }
        }
    }
    
    private func addScheduledMedication(_ scheduledMedication: ScheduledMedication) {
        Task {
            if let dogIndex = dataManager.dogs.firstIndex(where: { $0.id == dog.id }) {
                var updatedDog = dataManager.dogs[dogIndex]
                updatedDog.addScheduledMedication(scheduledMedication, createdBy: authService.currentUser)
                await dataManager.updateDogMedications(updatedDog, medications: updatedDog.medications, scheduledMedications: updatedDog.scheduledMedications)
                
                // Schedule notification
                await NotificationService.shared.scheduleMedicationNotification(for: updatedDog, scheduledMedication: scheduledMedication)
            }
        }
    }
    
    private func deleteScheduledMedication(_ scheduledMedication: ScheduledMedication) {
        Task {
            if let dogIndex = dataManager.dogs.firstIndex(where: { $0.id == dog.id }) {
                var updatedDog = dataManager.dogs[dogIndex]
                updatedDog.removeScheduledMedication(scheduledMedication, modifiedBy: authService.currentUser)
                await dataManager.updateDogMedications(updatedDog, medications: updatedDog.medications, scheduledMedications: updatedDog.scheduledMedications)
                
                // Cancel notification
                NotificationService.shared.cancelMedicationNotification(for: updatedDog, scheduledMedication: scheduledMedication)
            }
        }
    }
}

struct DailyMedicationRow: View {
    let medication: Medication
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "pills.fill")
                .foregroundStyle(.purple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(medication.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let notes = medication.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button("Delete") {
                onDelete()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct ScheduledMedicationRow: View {
    let scheduledMedication: ScheduledMedication
    let medication: Medication?
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(medication?.name ?? "Unknown Medication")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(scheduledMedication.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let notes = scheduledMedication.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Text(scheduledMedication.status.displayName)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(scheduledMedication.status.color).opacity(0.2))
                .foregroundStyle(Color(scheduledMedication.status.color))
                .clipShape(Capsule())
            
            Button("Delete") {
                onDelete()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct AddMedicationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let dog: Dog
    let medicationType: Medication.MedicationType
    let onSave: (Medication) -> Void
    
    @State private var name = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Medication Details") {
                    TextField("Medication Name", text: $name)
                    
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add \(medicationType.displayName) Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let medication = Medication(
                            name: name,
                            type: medicationType,
                            notes: notes.isEmpty ? nil : notes
                        )
                        onSave(medication)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct AddScheduledMedicationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var authService = AuthenticationService.shared
    let dog: Dog
    let onSave: (ScheduledMedication) -> Void
    let onAddMedication: (Medication) -> Void
    
    @State private var selectedMedication: Medication?
    @State private var scheduledDate = Date()
    @State private var notes = ""
    @State private var showingAddMedication = false
    @State private var newMedicationName = ""
    @State private var newMedicationNotes = ""
    @State private var showingDeleteAlert = false
    @State private var medicationToDelete: Medication?
    
    private func deleteMedicationFromList(_ medication: Medication) {
        // This function removes a medication from the dog's medications list
        // It's separate from the existing deleteMedication function which is for removing already scheduled medications
        print("🗑️ Long press detected - attempting to delete medication: \(medication.name)")
        Task {
            if let dogIndex = dataManager.dogs.firstIndex(where: { $0.id == dog.id }) {
                var updatedDog = dataManager.dogs[dogIndex]
                updatedDog.removeMedication(medication, modifiedBy: authService.currentUser)
                await dataManager.updateDogMedications(updatedDog, medications: updatedDog.medications, scheduledMedications: updatedDog.scheduledMedications)
                print("🗑️ Removed medication from selection list: \(medication.name)")
            }
        }
    }
    
    private func confirmDeleteMedication(_ medication: Medication) {
        medicationToDelete = medication
        showingDeleteAlert = true
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Add new medication") {
                        showingAddMedication = true
                    }
                    .foregroundStyle(.blue)
                }
                
                Section("Medication(s)") {
                    // Filter out daily medications - only show scheduled medications for scheduling
                    let scheduledMedications = dog.medications.filter { $0.type == .scheduled }
                    
                    if scheduledMedications.isEmpty {
                        Text("No scheduled medications available.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(scheduledMedications, id: \.id) { medication in
                            HStack {
                                Text(medication.name)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(selectedMedication?.id == medication.id ? .blue : .primary)
                                if selectedMedication?.id == medication.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedMedication = medication
                            }
                            .onLongPressGesture {
                                confirmDeleteMedication(medication)
                            }
                        }
                    }
                }
                
                Section("Schedule") {
                    if let selectedMedication = selectedMedication {
                        Text("Selected: \(selectedMedication.name)")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    } else {
                        Text("Select a medication above")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    DatePicker("Scheduled Date & Time", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Scheduled Medication(s)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let medication = selectedMedication {
                            let scheduledMedication = ScheduledMedication(
                                medicationId: medication.id,
                                scheduledDate: scheduledDate,
                                notificationTime: scheduledDate, // Use the same date/time for notification
                                status: .pending,
                                notes: notes.isEmpty ? nil : notes
                            )
                            onSave(scheduledMedication)
                            dismiss()
                        }
                    }
                    .disabled(selectedMedication == nil)
                }
            }
            
            .sheet(isPresented: $showingAddMedication) {
                NavigationStack {
                    Form {
                        Section("Medication Details") {
                            TextField("Medication Name", text: $newMedicationName)
                            
                            TextField("Notes (optional)", text: $newMedicationNotes, axis: .vertical)
                                .lineLimit(3...6)
                        }
                    }
                    .navigationTitle("Add Medication")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingAddMedication = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                let medication = Medication(
                                    name: newMedicationName,
                                    type: .scheduled,
                                    notes: newMedicationNotes.isEmpty ? nil : newMedicationNotes
                                )
                                onAddMedication(medication)
                                selectedMedication = medication
                                newMedicationName = ""
                                newMedicationNotes = ""
                                showingAddMedication = false
                            }
                            .disabled(newMedicationName.isEmpty)
                        }
                    }
                }
            }
        }
        .alert("Delete Medication", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let medication = medicationToDelete {
                    deleteMedicationFromList(medication)
                }
            }
        } message: {
            if let medication = medicationToDelete {
                Text("Are you sure you want to delete '\(medication.name)'? This action cannot be undone.")
            }
        }
    }
} 