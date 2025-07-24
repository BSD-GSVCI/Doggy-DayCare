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
            .refreshable {
                await dataManager.fetchDogsIncremental()
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
            .imageOverlay()
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
                DogProfilePicture(dog: dog, size: 40)
                    .padding(.trailing, 8)
                
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
                        Text("Boarding End Date")
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
    @State private var profileImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var age: Int? = nil
    @State private var gender: DogGender = .unknown
    @State private var vaccinations: [VaccinationItem] = [
        .init(name: "Bordetella", endDate: nil),
        .init(name: "DHPP", endDate: nil),
        .init(name: "Rabies", endDate: nil),
        .init(name: "CIV", endDate: nil),
        .init(name: "Leptospirosis", endDate: nil)
    ]
    @State private var isNeuteredOrSpayed: Bool = false
    @State private var ownerPhoneNumber: String = ""
    
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
                
                Section {
                    // Profile Picture
                    VStack {
                        if let profileImage = profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                        } else {
                            Image(systemName: "camera.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100)
                                .foregroundColor(.gray)
                                .onTapGesture {
                                    // Camera icon tap opens camera directly
                                    showingCamera = true
                                }
                        }
                        
                        Button(profileImage == nil ? "Add Profile Picture from Library" : "Change Picture") {
                            showingImagePicker = true
                        }
                        .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    
                    TextField("Name", text: $name)
                    TextField("Owner Name", text: $ownerName)
                    DatePicker("Arrival Date", selection: $arrivalDate, displayedComponents: .date)
                    // Move toggles to bottom
                    Toggle("Boarding", isOn: $isBoarding)
                    if isBoarding {
                        DatePicker("Boarding End Date", selection: $boardingEndDate, displayedComponents: .date)
                    }
                    Toggle("Daycare Feeds", isOn: $isDaycareFed)
                }
                
                Section("Walking") {
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
                
                Section("Miscellaneous Details") {
                    TextField("Age", value: $age, format: .number)
                        .keyboardType(.numberPad)
                    Picker("Gender", selection: $gender) {
                        ForEach(DogGender.allCases, id: \ .self) { gender in
                            Text(gender.displayName).tag(gender)
                        }
                    }
                    Section("Vaccinations") {
                        VaccinationListEditor(vaccinations: $vaccinations)
                    }
                    Toggle("Neutered/Spayed", isOn: $isNeuteredOrSpayed)
                    TextField("Owner's Phone Number", text: $ownerPhoneNumber)
                        .keyboardType(.phonePad)
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
            ImportSingleDogView { importedDog in
                loadDogFromImport(importedDog)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            PhotoLibraryPicker(image: $profileImage)
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(image: $profileImage)
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
        // Check for duplicates (only against currently present dogs)
        let existingDogs = dataManager.dogs.filter { dog in
            dog.isCurrentlyPresent && // Only check currently present dogs
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
        profileImage = importedDog.profilePictureData.flatMap { UIImage(data: $0) }
        // Ensure vaccinations array has all 5 required vaccinations
        let defaultVaccinations = [
            VaccinationItem(name: "Bordetella", endDate: nil),
            VaccinationItem(name: "DHPP", endDate: nil),
            VaccinationItem(name: "Rabies", endDate: nil),
            VaccinationItem(name: "CIV", endDate: nil),
            VaccinationItem(name: "Leptospirosis", endDate: nil)
        ]
        
        // Merge imported vaccinations with defaults, preserving dates from imported data
        vaccinations = defaultVaccinations.map { defaultVax in
            if let importedVax = importedDog.vaccinations.first(where: { $0.name == defaultVax.name }) {
                return VaccinationItem(name: defaultVax.name, endDate: importedVax.endDate)
            } else {
                return defaultVax
            }
        }
        
        // Keep current arrival date and boarding status
        // arrivalDate stays as current date
        // isBoarding stays as false
    }
    
    private func addFutureBooking() async {
        isLoading = true
        
        // Convert profile image to data
        let profilePictureData = profileImage?.jpegData(compressionQuality: 0.8)
        
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
            profilePictureData: profilePictureData,
            isArrivalTimeSet: false,
            vaccinations: vaccinations.map { VaccinationItem(name: $0.name, endDate: $0.endDate) }
        )
        
        // Set boarding end date for boarding dogs
        var dogToAdd = newDog
        if isBoarding {
            dogToAdd.boardingEndDate = boardingEndDate
        }
        
        await dataManager.addDog(dogToAdd)
        
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
    @State private var profileImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var age: Int? = nil
    @State private var gender: DogGender = .unknown
    @State private var vaccinations: [VaccinationItem] = [
        .init(name: "Bordetella", endDate: nil),
        .init(name: "DHPP", endDate: nil),
        .init(name: "Rabies", endDate: nil),
        .init(name: "CIV", endDate: nil),
        .init(name: "Leptospirosis", endDate: nil)
    ]
    @State private var isNeuteredOrSpayed: Bool = false
    @State private var ownerPhoneNumber: String = ""
    
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
        self._profileImage = State(initialValue: dog.profilePictureData.flatMap { UIImage(data: $0) })
        self._age = State(initialValue: dog.age)
        self._gender = State(initialValue: dog.gender ?? .unknown)
        self._vaccinations = State(initialValue: dog.vaccinations.map { VaccinationItem(name: $0.name, endDate: $0.endDate) })
        self._isNeuteredOrSpayed = State(initialValue: dog.isNeuteredOrSpayed ?? false)
        self._ownerPhoneNumber = State(initialValue: dog.ownerPhoneNumber ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Profile Picture
                    VStack {
                        if let profileImage = profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                        } else {
                            Image(systemName: "camera.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100)
                                .foregroundColor(.gray)
                                .onTapGesture {
                                    // Camera icon tap opens camera directly
                                    showingCamera = true
                                }
                        }
                        
                        Button(profileImage == nil ? "Add Profile Picture from Library" : "Change Picture") {
                            showingImagePicker = true
                        }
                        .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    
                    TextField("Name", text: $name)
                    TextField("Owner Name", text: $ownerName)
                    DatePicker("Arrival Date", selection: $arrivalDate, displayedComponents: .date)
                    // Move toggles to bottom
                    Toggle("Boarding", isOn: $isBoarding)
                    if isBoarding {
                        DatePicker("Boarding End Date", selection: $boardingEndDate, displayedComponents: .date)
                    }
                    Toggle("Daycare Feeds", isOn: $isDaycareFed)
                }
                
                Section("Walking") {
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
                
                Section("Miscellaneous Details") {
                    TextField("Age", value: $age, format: .number)
                        .keyboardType(.numberPad)
                    Picker("Gender", selection: $gender) {
                        ForEach(DogGender.allCases, id: \ .self) { gender in
                            Text(gender.displayName).tag(gender)
                        }
                    }
                    Section("Vaccinations") {
                        VaccinationListEditor(vaccinations: $vaccinations)
                    }
                    Toggle("Neutered/Spayed", isOn: $isNeuteredOrSpayed)
                    TextField("Owner's Phone Number", text: $ownerPhoneNumber)
                        .keyboardType(.phonePad)
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
        .sheet(isPresented: $showingImagePicker) {
            PhotoLibraryPicker(image: $profileImage)
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(image: $profileImage)
        }
    }
    
    private func updateFutureBooking() async {
        isLoading = true
        
        // Convert profile image to data
        let profilePictureData = profileImage?.jpegData(compressionQuality: 0.8)
        
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
        updatedDog.profilePictureData = profilePictureData
        updatedDog.isArrivalTimeSet = false
        updatedDog.updatedAt = Date()
        updatedDog.age = age
        updatedDog.gender = gender
        updatedDog.vaccinations = vaccinations.map { VaccinationItem(name: $0.name, endDate: $0.endDate) }
        updatedDog.isNeuteredOrSpayed = isNeuteredOrSpayed
        updatedDog.ownerPhoneNumber = ownerPhoneNumber.isEmpty ? nil : ownerPhoneNumber
        
        await dataManager.updateDog(updatedDog)
        
        isLoading = false
        dismiss()
    }
}

#Preview {
    FutureBookingsView()
        .environmentObject(DataManager.shared)
} 