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
            // Only show dogs with future arrival dates
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(dog.name)
                        .font(.headline)
                    
                    if let ownerName = dog.ownerName {
                        Text("Owner: \(ownerName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(dog.isBoarding ? "Boarding" : "Daycare")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(dog.isBoarding ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                        .foregroundStyle(dog.isBoarding ? .orange : .blue)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Expected Arrival")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dateFormatter.string(from: dog.arrivalDate))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    
                    if dog.isBoarding, let boardingEndDate = dog.boardingEndDate {
                        Text("Expected Departure")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(dateFormatter.string(from: boardingEndDate))
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
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
                FutureBookingEditView(dog: dog)
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
    @State private var showingImportDatabase = false
    @State private var showingDuplicateAlert = false
    @State private var duplicateDog: Dog?
    
    var body: some View {
        NavigationStack {
            Form {
                // Import from Database Section
                Section {
                    Button {
                        showingImportDatabase = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.doc")
                                .foregroundStyle(.blue)
                            Text("Import from Database")
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Text("Quick Import")
                } footer: {
                    Text("Import saved dog entries to avoid re-entering information")
                }
                
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
        .sheet(isPresented: $showingImportDatabase) {
            ImportDatabaseView { importedDog in
                loadDogFromImport(importedDog)
            }
        }
        .alert("Duplicate Dog Found", isPresented: $showingDuplicateAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Use Imported Data") {
                if let duplicateDog = duplicateDog {
                    loadDogFromImport(duplicateDog)
                }
            }
        } message: {
            if let duplicateDog = duplicateDog {
                Text("A dog with the same name and owner already exists in the database with \(duplicateDog.visitCount) previous visits. Would you like to use the imported data?")
            }
        }
    }
    
    private func loadDogFromImport(_ importedDog: Dog) {
        // Check for duplicates
        let existingDogs = dataManager.dogs.filter { dog in
            dog.name.lowercased() == importedDog.name.lowercased() &&
            (dog.ownerName?.lowercased() == importedDog.ownerName?.lowercased() || 
             (dog.ownerName == nil && importedDog.ownerName == nil))
        }
        
        if !existingDogs.isEmpty {
            duplicateDog = existingDogs.first
            showingDuplicateAlert = true
            return
        }
        
        // Load the imported data
        name = importedDog.name
        ownerName = importedDog.ownerName ?? ""
        medications = importedDog.medications ?? ""
        allergiesAndFeedingInstructions = importedDog.allergiesAndFeedingInstructions ?? ""
        needsWalking = importedDog.needsWalking
        walkingNotes = importedDog.walkingNotes ?? ""
        isDaycareFed = importedDog.isDaycareFed
        notes = importedDog.notes ?? ""
        
        // Keep current arrival date and boarding status
        // arrivalDate stays as current date
        // isBoarding stays as false
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
            notes: notes.isEmpty ? nil : notes,
            isArrivalTimeSet: false
        )
        
        await dataManager.addDog(newDog)
        
        isLoading = false
        dismiss()
    }
}

struct FutureBookingEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    let dog: Dog
    
    @State private var name: String
    @State private var ownerName: String
    @State private var arrivalDate: Date
    @State private var isBoarding: Bool
    @State private var boardingEndDate: Date
    @State private var isDaycareFed: Bool
    @State private var needsWalking: Bool
    @State private var walkingNotes: String
    @State private var medications: String
    @State private var allergiesAndFeedingInstructions: String
    @State private var notes: String
    @State private var isLoading = false
    
    init(dog: Dog) {
        self.dog = dog
        self._name = State(initialValue: dog.name)
        self._ownerName = State(initialValue: dog.ownerName ?? "")
        self._arrivalDate = State(initialValue: dog.arrivalDate)
        self._isBoarding = State(initialValue: dog.isBoarding)
        
        // For boarding end date, use existing value if available, otherwise use a reasonable default
        let defaultBoardingEndDate: Date
        if let existingBoardingEndDate = dog.boardingEndDate {
            defaultBoardingEndDate = existingBoardingEndDate
        } else {
            // Default to 7 days after arrival date for new boarding entries
            defaultBoardingEndDate = Calendar.current.date(byAdding: .day, value: 7, to: dog.arrivalDate) ?? Date()
        }
        self._boardingEndDate = State(initialValue: defaultBoardingEndDate)
        
        self._isDaycareFed = State(initialValue: dog.isDaycareFed)
        self._needsWalking = State(initialValue: dog.needsWalking)
        self._walkingNotes = State(initialValue: dog.walkingNotes ?? "")
        self._medications = State(initialValue: dog.medications ?? "")
        self._allergiesAndFeedingInstructions = State(initialValue: dog.allergiesAndFeedingInstructions ?? "")
        self._notes = State(initialValue: dog.notes ?? "")
    }
    
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
            .navigationTitle("Edit Future Booking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await updateFutureBooking()
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
                            ProgressView("Saving...")
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                }
            }
        }
    }
    
    private func updateFutureBooking() async {
        isLoading = true
        
        var updatedDog = dog
        updatedDog.name = name
        updatedDog.ownerName = ownerName.isEmpty ? nil : ownerName
        updatedDog.arrivalDate = arrivalDate
        updatedDog.isBoarding = isBoarding
        updatedDog.boardingEndDate = isBoarding ? boardingEndDate : nil
        updatedDog.medications = medications.isEmpty ? nil : medications
        updatedDog.allergiesAndFeedingInstructions = allergiesAndFeedingInstructions.isEmpty ? nil : allergiesAndFeedingInstructions
        updatedDog.needsWalking = needsWalking
        updatedDog.walkingNotes = walkingNotes.isEmpty ? nil : walkingNotes
        updatedDog.isDaycareFed = isDaycareFed
        updatedDog.notes = notes.isEmpty ? nil : notes
        updatedDog.isArrivalTimeSet = false // Keep as false for future bookings
        updatedDog.updatedAt = Date()
        
        await dataManager.updateDog(updatedDog)
        
        isLoading = false
        dismiss()
    }
}

#Preview {
    FutureBookingsView()
        .environmentObject(DataManager.shared)
} 