import SwiftUI
import SwiftData

struct DogDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthenticationService.shared
    @Bindable var dog: Dog
    
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingDepartureSheet = false
    @State private var showingBoardingSheet = false
    @State private var departureDate = Date()
    @State private var boardingEndDate = Date()
    
    private var canEdit: Bool {
        authService.currentUser?.isOwner ?? false
    }
    
    private var canDelete: Bool {
        authService.currentUser?.isOwner ?? false
    }
    
    private var canSetDeparture: Bool {
        authService.currentUser?.isOwner ?? false
    }
    
    private var canModifyRecords: Bool {
        // Staff can modify records for current day's dogs
        if let user = authService.currentUser, !user.isOwner {
            return Calendar.current.isDateInToday(dog.arrivalDate) && dog.isCurrentlyPresent
        }
        return true // Owners can modify all records
    }
    
    var body: some View {
        NavigationStack {
            Form {
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
                        if !dog.isBoarding {
                            Button {
                                showingBoardingSheet = true
                            } label: {
                                Label("Board", systemImage: "house.fill")
                            }
                        }
                        
                        Button {
                            withAnimation {
                                dog.departureDate = Date()
                                dog.updatedAt = Date()
                                try? modelContext.save()
                            }
                            dismiss()
                        } label: {
                            Label("Check Out", systemImage: "checkmark.circle")
                        }
                    } else if dog.departureDate != nil {
                        Button {
                            showingDepartureSheet = true
                        } label: {
                            Label("Edit Departure Time", systemImage: "clock")
                        }
                    }
                }
                
                Section {
                    Toggle("Needs Walking", isOn: $dog.needsWalking)
                        .onChange(of: dog.needsWalking) { _, newValue in
                            dog.recordStatusChange("Walking status", newValue: newValue)
                        }
                    
                    if dog.needsWalking {
                        if let notes = dog.walkingNotes, !notes.isEmpty {
                            Text(notes)
                                .font(.subheadline)
                        }
                        
                        if !dog.pottyRecords.isEmpty {
                            ForEach(dog.pottyRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.timestamp) { record in
                                HStack {
                                    if record.type == .pee {
                                        Image(systemName: "drop.fill")
                                            .foregroundStyle(.yellow)
                                    } else if record.type == .poop {
                                        Text("💩")
                                    } else if record.type == .nothing {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.red)
                                    } else {
                                        Image(systemName: "questionmark.circle")
                                            .foregroundStyle(.gray)
                                    }
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
                                guard canModifyRecords else { return }
                                let sortedRecords = dog.pottyRecords.sorted(by: { $0.timestamp > $1.timestamp })
                                for index in indexSet {
                                    if let recordToDelete = sortedRecords[safe: index] {
                                        dog.removePottyRecord(at: recordToDelete.timestamp, modifiedBy: authService.currentUser)
                                    }
                                }
                                try? modelContext.save()
                            }
                        }
                        
                        HStack(spacing: 12) {
                            HStack {
                                Image(systemName: "drop.fill")
                                    .foregroundStyle(.yellow)
                                Text("\(dog.peeCount)")
                            }
                            HStack {
                                Text("💩")
                                Text("\(dog.poopCount)")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Walking Information")
                }
                
                if dog.medications != nil && !dog.medications!.isEmpty {
                    Section("Medications") {
                        Text(dog.medications!)
                        
                        if !dog.medicationRecords.isEmpty {
                            ForEach(dog.medicationRecords.sorted(by: { $0.timestamp > $1.timestamp }), id: \.timestamp) { record in
                                HStack {
                                    Image(systemName: "pills.fill")
                                        .foregroundStyle(.purple)
                                    if let notes = record.notes, !notes.isEmpty {
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
                                guard canModifyRecords else { return }
                                let sortedRecords = dog.medicationRecords.sorted(by: { $0.timestamp > $1.timestamp })
                                for index in indexSet {
                                    if let recordToDelete = sortedRecords[safe: index] {
                                        dog.medicationRecords.removeAll { $0.timestamp == recordToDelete.timestamp }
                                        dog.updatedAt = Date()
                                        dog.lastModifiedBy = authService.currentUser
                                    }
                                }
                                try? modelContext.save()
                            }
                        }
                    }
                }
                
                Section("Feeding Information") {
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
                            guard canModifyRecords else { return }
                            let sortedRecords = dog.feedingRecords.sorted(by: { $0.timestamp > $1.timestamp })
                            for index in indexSet {
                                if let recordToDelete = sortedRecords[safe: index] {
                                    dog.feedingRecords.removeAll { $0.timestamp == recordToDelete.timestamp }
                                    dog.updatedAt = Date()
                                    dog.lastModifiedBy = authService.currentUser
                                }
                            }
                            try? modelContext.save()
                        }
                    }
                    
                    HStack(spacing: 16) {
                        HStack {
                            Image(systemName: "sunrise.fill")
                                .foregroundStyle(.orange)
                            Text("\(dog.breakfastCount)")
                        }
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .foregroundStyle(.yellow)
                            Text("\(dog.lunchCount)")
                        }
                        HStack {
                            Image(systemName: "sunset.fill")
                                .foregroundStyle(.red)
                            Text("\(dog.dinnerCount)")
                        }
                        HStack {
                            Image(systemName: "pawprint.fill")
                                .foregroundStyle(.brown)
                            Text("\(dog.snackCount)")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                }
                
                if let notes = dog.notes, !notes.isEmpty {
                    Section("Additional Notes") {
                        Text(notes)
                    }
                }
                
                if canDelete {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete Dog", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(dog.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if canEdit {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") {
                            showingEditSheet = true
                        }
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
                        .onChange(of: departureDate) { _, newValue in
                            // Auto-close the sheet when a date is selected
                            dog.departureDate = newValue
                            dog.updatedAt = Date()
                            dog.lastModifiedBy = authService.currentUser
                            showingDepartureSheet = false
                        }
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
                            dog.lastModifiedBy = authService.currentUser
                            showingDepartureSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.height(200)])
        }
        .sheet(isPresented: $showingBoardingSheet) {
            NavigationStack {
                Form {
                    Section {
                        DatePicker("Expected Departure Date", selection: $boardingEndDate, displayedComponents: .date)
                    } footer: {
                        Text("This will convert \(dog.name) from daycare to boarding. The dog will remain in boarding until the expected departure date.")
                    }
                }
                .navigationTitle("Convert to Boarding")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingBoardingSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Convert") {
                            dog.isBoarding = true
                            dog.boardingEndDate = boardingEndDate
                            dog.updatedAt = Date()
                            dog.lastModifiedBy = authService.currentUser
                            try? modelContext.save()
                            showingBoardingSheet = false
                            dismiss()
                        }
                    }
                }
            }
            .presentationDetents([.medium])
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

// MARK: - Test View for Development
#if DEBUG
struct DogDetailTestView: View {
    let dog: Dog
    
    var body: some View {
        DogDetailView(dog: dog)
    }
}
#endif

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Dog.self, User.self, configurations: config)
    
    // Create a sample dog for preview
    let sampleDog = Dog(
        id: UUID(),
        name: "Max",
        arrivalDate: Date(),
        isBoarding: true,
        medications: "Heart medication",
        specialInstructions: "Needs extra attention"
    )
    
    container.mainContext.insert(sampleDog)
    
    return DogDetailView(dog: sampleDog)
        .modelContainer(container)
} 