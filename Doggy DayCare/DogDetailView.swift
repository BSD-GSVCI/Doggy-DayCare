import SwiftUI
import SwiftData

struct DogDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var dog: Dog
    
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingDepartureSheet = false
    @State private var departureDate = Date()
    
    var body: some View {
        NavigationStack {
            List {
                Section("Dog Information") {
                    LabeledContent("Name", value: dog.name)
                }
                
                Section("Stay Information") {
                    LabeledContent("Arrival", value: dog.arrivalDate.formatted(date: .abbreviated, time: .shortened))
                    if let departureDate = dog.departureDate {
                        LabeledContent("Departure", value: departureDate.formatted(date: .abbreviated, time: .shortened))
                    }
                    LabeledContent("Duration", value: dog.formattedStayDuration)
                    LabeledContent("Type", value: dog.isBoarding ? "Boarding" : "Daycare")
                    LabeledContent("Feeding", value: dog.isDaycareFed ? "Daycare Fed" : "Own Food")
                    
                    if dog.isCurrentlyPresent {
                        Button {
                            showingDepartureSheet = true
                        } label: {
                            Label("Set Departure Time", systemImage: "clock")
                        }
                    }
                }
                
                if let medications = dog.medications, !medications.isEmpty {
                    Section("Medications") {
                        Text(medications)
                    }
                }
                
                if dog.needsWalking {
                    Section("Walking Information") {
                        if let notes = dog.walkingNotes {
                            Text(notes)
                        }
                        
                        HStack(spacing: 12) {
                            HStack {
                                Image(systemName: "drop.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                                Text("\(dog.peeCount) pees")
                            }
                            HStack {
                                Text("💩")
                                    .font(.caption)
                                    .foregroundColor(.brown)
                                Text("\(dog.poopCount) poops")
                            }
                        }
                        
                        if !dog.pottyRecords.isEmpty {
                            ForEach(dog.pottyRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.timestamp) { record in
                                HStack {
                                    if record.type == .pee {
                                        Image(systemName: "drop.fill")
                                            .foregroundStyle(.yellow)
                                    } else {
                                        Text("💩")
                                            .foregroundColor(.brown)
                                    }
                                    Text(record.type == .pee ? "Peed" : "Pooped")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                
                if let instructions = dog.specialInstructions, !instructions.isEmpty {
                    Section("Special Instructions") {
                        Text(instructions)
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete Dog", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(dog.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        showingEditSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            DogFormView(dog: dog)
        }
        .sheet(isPresented: $showingDepartureSheet) {
            NavigationStack {
                Form {
                    DatePicker("Departure Time", selection: $departureDate)
                }
                .navigationTitle("Set Departure")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingDepartureSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            dog.departureDate = departureDate
                            dog.updatedAt = Date()
                            showingDepartureSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.height(200)])
        }
        .alert("Delete Dog", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteDog()
            }
        } message: {
            Text("Are you sure you want to delete \(dog.name)? This action cannot be undone.")
        }
    }
    
    private func deleteDog() {
        modelContext.delete(dog)
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Dog.self, configurations: config)
    let dog = Dog(
        name: "Buddy",
        arrivalDate: Date(),
        needsWalking: true,
        walkingNotes: "Needs 30-minute walk every 4 hours",
        isBoarding: true,
        specialInstructions: "Allergic to chicken"
    )
    
    NavigationStack {
        DogDetailView(dog: dog)
    }
    .modelContainer(container)
} 