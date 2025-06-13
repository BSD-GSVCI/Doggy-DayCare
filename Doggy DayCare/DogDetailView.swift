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
                        
                        HStack {
                            Image(systemName: "pills.fill")
                                .font(.caption)
                                .foregroundStyle(.purple)
                            Text("\(dog.medicationCount) administrations")
                                .font(.caption)
                        }
                        
                        if !dog.medicationRecords.isEmpty {
                            ForEach(dog.medicationRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.timestamp) { record in
                                HStack {
                                    Image(systemName: "pills.fill")
                                        .foregroundStyle(.purple)
                                    if let notes = record.notes {
                                        Text(notes)
                                            .font(.subheadline)
                                    } else {
                                        Text("Medication administered")
                                            .font(.subheadline)
                                    }
                                    Spacer()
                                    Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                            .onDelete { indexSet in
                                let sortedRecords = dog.medicationRecords.sorted(by: { $0.timestamp > $1.timestamp })
                                for index in indexSet {
                                    if let recordToDelete = sortedRecords[safe: index] {
                                        dog.medicationRecords.removeAll { $0.timestamp == recordToDelete.timestamp }
                                    }
                                }
                                dog.updatedAt = Date()
                            }
                        }
                    }
                }
                
                Section("Feeding Information") {
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "sunrise.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("\(dog.breakfastCount)")
                                .font(.caption)
                        }
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                            Text("\(dog.lunchCount)")
                                .font(.caption)
                        }
                        HStack {
                            Image(systemName: "sunset.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                            Text("\(dog.dinnerCount)")
                                .font(.caption)
                        }
                        HStack {
                            Image(systemName: "pawprint.fill")
                                .font(.caption)
                                .foregroundStyle(.brown)
                            Text("\(dog.snackCount)")
                                .font(.caption)
                        }
                    }
                    
                    if !dog.feedingRecords.isEmpty {
                        ForEach(dog.feedingRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.timestamp) { record in
                            HStack {
                                Image(systemName: iconForFeedingType(record.type))
                                    .foregroundStyle(colorForFeedingType(record.type))
                                Text(record.type.rawValue.capitalized)
                                    .font(.subheadline)
                                Spacer()
                                Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete { indexSet in
                            let sortedRecords = dog.feedingRecords.sorted(by: { $0.timestamp > $1.timestamp })
                            for index in indexSet {
                                if let recordToDelete = sortedRecords[safe: index] {
                                    dog.feedingRecords.removeAll { $0.timestamp == recordToDelete.timestamp }
                                }
                            }
                            dog.updatedAt = Date()
                        }
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
                            .onDelete { indexSet in
                                let sortedRecords = dog.pottyRecords.sorted(by: { $0.timestamp > $1.timestamp })
                                for index in indexSet {
                                    if let recordToDelete = sortedRecords[safe: index],
                                       let originalIndex = dog.pottyRecords.firstIndex(where: { $0.timestamp == recordToDelete.timestamp }) {
                                        dog.pottyRecords.remove(at: originalIndex)
                                    }
                                }
                                dog.updatedAt = Date()
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
    
    private func iconForFeedingType(_ type: FeedingRecord.FeedingType) -> String {
        switch type {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "sunset.fill"
        case .snack: return "pawprint.fill"
        }
    }
    
    private func colorForFeedingType(_ type: FeedingRecord.FeedingType) -> Color {
        switch type {
        case .breakfast: return .orange
        case .lunch: return .yellow
        case .dinner: return .red
        case .snack: return .brown
        }
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Dog.self, configurations: config)
    let dog = Dog(
        name: "Test Dog",
        arrivalDate: Date(),
        isBoarding: true,
        needsWalking: true,
        walkingNotes: "Test walking notes",
        medications: "Test medication"
    )
    
    NavigationStack {
        DogDetailView(dog: dog)
    }
    .modelContainer(container)
} 