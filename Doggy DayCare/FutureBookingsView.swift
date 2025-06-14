import SwiftUI
import SwiftData

struct FutureBookingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var dogs: [Dog]
    @State private var showingAddBooking = false
    @State private var showingEditBooking = false
    @State private var selectedDog: Dog?
    @State private var searchText = ""
    
    private var futureBookings: [Dog] {
        let filtered = searchText.isEmpty ? dogs : dogs.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return filtered.filter { dog in
            let isFutureBooking = Calendar.current.startOfDay(for: dog.arrivalDate) > Calendar.current.startOfDay(for: Date())
            let hasNoArrivalTime = Calendar.current.dateComponents([.hour, .minute], from: dog.arrivalDate).hour == 0 &&
                                  Calendar.current.dateComponents([.hour, .minute], from: dog.arrivalDate).minute == 0
            return isFutureBooking && hasNoArrivalTime
        }.sorted { $0.arrivalDate < $1.arrivalDate }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if futureBookings.isEmpty {
                    ContentUnavailableView(
                        "No Future Bookings",
                        systemImage: "calendar.badge.plus",
                        description: Text("Add future bookings to prepare for upcoming arrivals")
                    )
                } else {
                    ForEach(futureBookings) { dog in
                        FutureBookingRow(dog: dog) {
                            selectedDog = dog
                            showingEditBooking = true
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search bookings by name")
            .navigationTitle("Future Bookings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddBooking = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBooking) {
                NavigationStack {
                    FutureBookingFormView()
                }
            }
            .sheet(item: $selectedDog) { dog in
                NavigationStack {
                    FutureBookingFormView(dog: dog)
                }
            }
        }
    }
}

private struct FutureBookingRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var dog: Dog
    @State private var showingArrivalSheet = false
    @State private var arrivalTime = Date()
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(dog.name)
                    .font(.headline)
                if dog.needsWalking {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(.blue)
                }
                if dog.medications != nil && !dog.medications!.isEmpty {
                    Image(systemName: "pills")
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text(dog.arrivalDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Menu {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit Booking", systemImage: "pencil")
                    }
                    
                    if Calendar.current.isDateInToday(dog.arrivalDate) {
                        Button {
                            showingArrivalSheet = true
                        } label: {
                            Label("Set Arrival Time", systemImage: "clock")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack {
                Text(dog.isBoarding ? "Boarding" : "Daycare")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(dog.isBoarding ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                    .clipShape(Capsule())
                
                if dog.isBoarding, let boardingEndDate = dog.boardingEndDate {
                    Text("Until \(boardingEndDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(Capsule())
                }
                
                if dog.isDaycareFed {
                    Text("Daycare Feeds")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(
            Calendar.current.isDateInToday(dog.arrivalDate) ?
            Color.red.opacity(0.1) :
            Color.clear
        )
        .sheet(isPresented: $showingArrivalSheet) {
            NavigationStack {
                Form {
                    DatePicker("Arrival Time", selection: $arrivalTime, displayedComponents: .hourAndMinute)
                }
                .navigationTitle("Set Arrival Time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingArrivalSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let calendar = Calendar.current
                            var components = calendar.dateComponents([.year, .month, .day], from: dog.arrivalDate)
                            let timeComponents = calendar.dateComponents([.hour, .minute], from: arrivalTime)
                            components.hour = timeComponents.hour
                            components.minute = timeComponents.minute
                            if let newDate = calendar.date(from: components) {
                                dog.arrivalDate = newDate
                                dog.updatedAt = Date()
                            }
                            showingArrivalSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.height(200)])
        }
    }
}

struct FutureBookingFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var dogs: [Dog]
    
    @State private var name: String
    @State private var arrivalDate: Date
    @State private var boardingEndDate: Date?
    @State private var isBoarding: Bool
    @State private var isDaycareFed: Bool
    @State private var needsWalking: Bool
    @State private var walkingNotes: String
    @State private var medications: String
    @State private var notes: String
    
    private let editingDog: Dog?
    
    init(dog: Dog? = nil) {
        editingDog = dog
        if let dog = dog {
            _name = State(initialValue: dog.name)
            _arrivalDate = State(initialValue: Calendar.current.startOfDay(for: dog.arrivalDate))
            _boardingEndDate = State(initialValue: dog.boardingEndDate != nil ? Calendar.current.startOfDay(for: dog.boardingEndDate!) : nil)
            _isBoarding = State(initialValue: dog.isBoarding)
            _isDaycareFed = State(initialValue: dog.isDaycareFed)
            _needsWalking = State(initialValue: dog.needsWalking)
            _walkingNotes = State(initialValue: dog.walkingNotes ?? "")
            _medications = State(initialValue: dog.medications ?? "")
            _notes = State(initialValue: dog.notes ?? "")
        } else {
            _name = State(initialValue: "")
            _arrivalDate = State(initialValue: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400)))
            _boardingEndDate = State(initialValue: nil)
            _isBoarding = State(initialValue: false)
            _isDaycareFed = State(initialValue: false)
            _needsWalking = State(initialValue: false)
            _walkingNotes = State(initialValue: "")
            _medications = State(initialValue: "")
            _notes = State(initialValue: "")
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    DatePicker("Arrival Date", selection: $arrivalDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .onChange(of: arrivalDate) { _, newDate in
                            // Ensure the time is set to midnight
                            arrivalDate = Calendar.current.startOfDay(for: newDate)
                        }
                    
                    Toggle("Boarding", isOn: $isBoarding)
                        .onChange(of: isBoarding) { _, newValue in
                            if !newValue {
                                boardingEndDate = nil
                            }
                        }
                    
                    if isBoarding {
                        DatePicker(
                            "Expected Departure",
                            selection: Binding(
                                get: { boardingEndDate ?? Calendar.current.startOfDay(for: arrivalDate.addingTimeInterval(86400)) },
                                set: { boardingEndDate = Calendar.current.startOfDay(for: $0) }
                            ),
                            in: arrivalDate...,
                            displayedComponents: .date
                        )
                    }
                    
                    Toggle("Daycare Feeds", isOn: $isDaycareFed)
                }
                
                Section("Walking") {
                    Toggle("Needs Walking", isOn: $needsWalking)
                    if needsWalking {
                        TextField("Walking Notes", text: Binding(
                            get: { walkingNotes },
                            set: { walkingNotes = $0 }
                        ), axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                
                Section("Additional Information") {
                    TextField("Medications (leave blank if none)", text: Binding(
                        get: { medications },
                        set: { medications = $0 }
                    ), axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Additional Notes", text: Binding(
                        get: { notes },
                        set: { notes = $0 }
                    ), axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Future Booking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func save() {
        let midnightArrivalDate = Calendar.current.startOfDay(for: arrivalDate)
        
        if let existingDog = editingDog {
            // Update existing dog
            existingDog.name = name
            existingDog.arrivalDate = midnightArrivalDate
            existingDog.boardingEndDate = boardingEndDate != nil ? Calendar.current.startOfDay(for: boardingEndDate!) : nil
            existingDog.isBoarding = isBoarding
            existingDog.isDaycareFed = isDaycareFed
            existingDog.needsWalking = needsWalking
            existingDog.walkingNotes = walkingNotes.isEmpty ? nil : walkingNotes
            existingDog.medications = medications.isEmpty ? nil : medications
            existingDog.notes = notes.isEmpty ? nil : notes
            existingDog.updatedAt = Date()
        } else {
            // Create new dog
            let newDog = Dog(
                name: name,
                arrivalDate: midnightArrivalDate,
                departureDate: nil,
                boardingEndDate: boardingEndDate != nil ? Calendar.current.startOfDay(for: boardingEndDate!) : nil,
                isBoarding: isBoarding,
                isDaycareFed: isDaycareFed,
                needsWalking: needsWalking,
                walkingNotes: walkingNotes.isEmpty ? nil : walkingNotes,
                specialInstructions: nil,
                medications: medications.isEmpty ? nil : medications,
                notes: notes.isEmpty ? nil : notes,
                modelContext: modelContext
            )
            modelContext.insert(newDog)
        }
        
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    FutureBookingsView()
        .modelContainer(for: Dog.self, inMemory: true)
} 