import SwiftUI

struct FutureBookingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddBooking = false
    @State private var searchText = ""
    
    private var filteredDogs: [Dog] {
        if searchText.isEmpty {
            return dataManager.dogs
        } else {
            return dataManager.dogs.filter { dog in
                dog.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var futureBookings: [Dog] {
        filteredDogs.filter { dog in
            Calendar.current.startOfDay(for: dog.arrivalDate) > Calendar.current.startOfDay(for: Date())
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if futureBookings.isEmpty {
                    ContentUnavailableView {
                        Label("No Future Bookings", systemImage: "calendar")
                    } description: {
                        Text("Dogs with future arrival dates will appear here.")
                    }
                } else {
                    ForEach(futureBookings) { dog in
                        FutureBookingRow(dog: dog)
                    }
                }
            }
            .navigationTitle("Future Bookings")
            .searchable(text: $searchText, prompt: "Search dogs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
        }
    }
}

struct FutureBookingRow: View {
    @EnvironmentObject var dataManager: DataManager
    let dog: Dog
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dog.name)
                    .font(.headline)
                Spacer()
                Text(dateFormatter.string(from: dog.arrivalDate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if let ownerName = dog.ownerName {
                Text("Owner: \(ownerName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text(dog.isBoarding ? "Boarding" : "Daycare")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(dog.isBoarding ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                    .foregroundStyle(dog.isBoarding ? .orange : .blue)
                    .clipShape(Capsule())
                
                Spacer()
                
                if dog.isDaycareFed {
                    Text("Daycare Fed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Edit") {
                showingEditSheet = true
            }
            Button("Delete", role: .destructive) {
                showingDeleteAlert = true
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                DogFormView(dog: dog)
            }
        }
        .alert("Delete Future Booking", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await dataManager.deleteDog(dog)
                }
            }
        } message: {
            Text("Are you sure you want to delete the future booking for \(dog.name)?")
        }
    }
}

struct FutureBookingFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    
    @State private var name = ""
    @State private var ownerName = ""
    @State private var arrivalDate = Date()
    @State private var isBoarding = false
    @State private var boardingEndDate = Date()
    @State private var isDaycareFed = false
    @State private var needsWalking = false
    @State private var walkingNotes = ""
    @State private var medications = ""
    @State private var allergiesAndFeedingInstructions = ""
    @State private var notes = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Dog Information") {
                    TextField("Name", text: $name)
                    TextField("Owner Name", text: $ownerName)
                    DatePicker("Arrival Date", selection: $arrivalDate, displayedComponents: .date)
                }
                
                Section("Stay Type") {
                    Toggle("Boarding", isOn: $isBoarding)
                    
                    if isBoarding {
                        DatePicker("Expected Departure", selection: $boardingEndDate, displayedComponents: .date)
                    }
                }
                
                Section("Services") {
                    Toggle("Daycare Fed", isOn: $isDaycareFed)
                    Toggle("Needs Walking", isOn: $needsWalking)
                    
                    if needsWalking {
                        TextField("Walking Notes", text: $walkingNotes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                
                Section("Additional Information") {
                    TextField("Medications", text: $medications, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Allergies & Feeding Instructions", text: $allergiesAndFeedingInstructions, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Notes", text: $notes, axis: .vertical)
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
                    Button("Add") {
                        Task {
                            await addFutureBooking()
                        }
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
            .overlay {
                if isLoading {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Adding...")
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                }
            }
        }
    }
    
    private func addFutureBooking() async {
        isLoading = true
        
        let newDog = Dog(
            name: name,
            ownerName: ownerName.isEmpty ? nil : ownerName,
            arrivalDate: arrivalDate,
            isBoarding: isBoarding,
            medications: medications.isEmpty ? nil : medications,
            allergiesAndFeedingInstructions: allergiesAndFeedingInstructions.isEmpty ? nil : allergiesAndFeedingInstructions,
            needsWalking: needsWalking,
            walkingNotes: walkingNotes.isEmpty ? nil : walkingNotes,
            isDaycareFed: isDaycareFed,
            notes: notes.isEmpty ? nil : notes
        )
        
        await dataManager.addDog(newDog)
        
        isLoading = false
        dismiss()
    }
}

#Preview {
    FutureBookingsView()
        .environmentObject(DataManager.shared)
} 