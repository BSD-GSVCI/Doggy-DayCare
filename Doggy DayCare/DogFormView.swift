import SwiftUI

struct DogFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var authService = AuthenticationService.shared
    
    @State private var name = ""
    @State private var ownerName = ""
    @State private var arrivalDate = Date()
    @State private var departureDate: Date?
    @State private var boardingEndDate: Date?
    @State private var isBoarding = false
    @State private var isDaycareFed = false
    @State private var needsWalking = false
    @State private var walkingNotes = ""
    @State private var medications = ""
    @State private var allergiesAndFeedingInstructions = ""
    @State private var notes: String?
    @State private var showingBoardingDatePicker = false
    @State private var profileImage: UIImage?
    @State private var showingImagePicker = false
    @State private var isLoading = false
    @State private var showingImportDatabase = false
    @State private var showingDuplicateAlert = false
    @State private var duplicateDog: Dog?
    @State private var bypassDuplicateCheck = false
    @State private var showingCamera = false
    @State private var age: Int? = nil
    @State private var gender: DogGender = .unknown
    @State private var vaccinationEndDate: Date? = nil
    @State private var isNeuteredOrSpayed: Bool = false
    @State private var ownerPhoneNumber: String = ""
    
    let dog: Dog?
    
    init(dog: Dog? = nil) {
        self.dog = dog
        if let dog = dog {
            _name = State(initialValue: dog.name)
            _ownerName = State(initialValue: dog.ownerName ?? "")
            _arrivalDate = State(initialValue: dog.arrivalDate)
            _departureDate = State(initialValue: dog.departureDate)
            _boardingEndDate = State(initialValue: dog.boardingEndDate ?? Date())
            _isBoarding = State(initialValue: dog.isBoarding)
            _isDaycareFed = State(initialValue: dog.isDaycareFed)
            _needsWalking = State(initialValue: dog.needsWalking)
            _walkingNotes = State(initialValue: dog.walkingNotes ?? "")
            _medications = State(initialValue: dog.medications ?? "")
            _allergiesAndFeedingInstructions = State(initialValue: dog.allergiesAndFeedingInstructions ?? "")
            _notes = State(initialValue: dog.notes)
            if let imageData = dog.profilePictureData {
                _profileImage = State(initialValue: UIImage(data: imageData))
            }
            _age = State(initialValue: dog.age)
            _gender = State(initialValue: dog.gender ?? .unknown)
            _vaccinationEndDate = State(initialValue: dog.vaccinationEndDate)
            _isNeuteredOrSpayed = State(initialValue: dog.isNeuteredOrSpayed ?? false)
            _ownerPhoneNumber = State(initialValue: dog.ownerPhoneNumber ?? "")
        } else {
            _name = State(initialValue: "")
            _ownerName = State(initialValue: "")
            _arrivalDate = State(initialValue: Date())
            _departureDate = State(initialValue: nil)
            _boardingEndDate = State(initialValue: Date())
            _isBoarding = State(initialValue: false)
            _isDaycareFed = State(initialValue: false)
            _needsWalking = State(initialValue: false)
            _walkingNotes = State(initialValue: "")
            _medications = State(initialValue: "")
            _allergiesAndFeedingInstructions = State(initialValue: "")
            _notes = State(initialValue: nil)
            _profileImage = State(initialValue: nil)
            _age = State(initialValue: nil)
            _gender = State(initialValue: .unknown)
            _vaccinationEndDate = State(initialValue: nil)
            _isNeuteredOrSpayed = State(initialValue: false)
            _ownerPhoneNumber = State(initialValue: "")
        }
    }
    

    
    var body: some View {
        NavigationStack {
            Form {
                    // Import from Database Section (only show when adding new dog)
                    if dog == nil {
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
                        
                        let buttonTitle = profileImage == nil ? "Add Profile Picture from Library" : "Change Picture"
                        Button(buttonTitle) {
                            showingImagePicker = true
                        }
                        .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    
                    TextField("Name", text: $name)
                    TextField("Owner Name", text: $ownerName)
                    DatePicker("Arrival Time", selection: $arrivalDate)
                    
                    Toggle("Boarding", isOn: $isBoarding)
                        .onChange(of: isBoarding) { _, newValue in
                            if !newValue {
                                boardingEndDate = nil
                            }
                        }
                    
                    if isBoarding {
                        let boardingEndDateBinding = Binding(
                            get: { boardingEndDate ?? Calendar.current.startOfDay(for: Date()) },
                            set: { boardingEndDate = $0 }
                        )
                        DatePicker(
                            "Boarding End Date",
                            selection: boardingEndDateBinding,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .onChange(of: boardingEndDate) { _, newValue in
                            DispatchQueue.main.async {
                                // Force a view refresh to close the picker
                            }
                        }
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
                    TextField("Medications (leave blank if none)", text: $medications, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Allergies and Feeding Instructions", text: $allergiesAndFeedingInstructions, axis: .vertical)
                        .lineLimit(3...6)
                    let additionalNotesBinding = Binding(
                        get: { notes ?? "" },
                        set: { notes = $0.isEmpty ? nil : $0 }
                    )
                    TextField("Additional Notes", text: additionalNotesBinding, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Miscellaneous Details") {
                    TextField("Age", value: $age, format: .number)
                        .keyboardType(.numberPad)
                    Picker("Gender", selection: $gender) {
                        let genderCases = DogGender.allCases
                        ForEach(genderCases, id: \ .self) { gender in
                            Text(gender.displayName).tag(gender)
                        }
                    }
                    if let vaccinationEndDate = vaccinationEndDate {
                        let vaccinationEndDateBinding = Binding(
                            get: { vaccinationEndDate },
                            set: { self.vaccinationEndDate = $0 }
                        )
                        DatePicker("Vaccination End Date", selection: vaccinationEndDateBinding, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        Button("Clear Vaccination Date") {
                            self.vaccinationEndDate = nil
                        }
                    } else {
                        Button("Set Vaccination End Date") {
                            self.vaccinationEndDate = Date()
                        }
                    }
                    Toggle("Neutered/Spayed", isOn: $isNeuteredOrSpayed)
                    TextField("Owner's Phone Number", text: $ownerPhoneNumber)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle(dog == nil ? "Add Dog" : "Edit Dog")
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
                            await saveDog()
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
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                // Add a small delay to let the keyboard fully appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // The form will naturally scroll to the focused field
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            PhotoLibraryPicker(image: $profileImage)
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(image: $profileImage)
        }
        .sheet(isPresented: $showingImportDatabase) {
            ImportSingleDogView { importedDog in
                loadDogFromImport(importedDog)
            }
        }
        .alert("Duplicate Dog Found", isPresented: $showingDuplicateAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Use Imported Data") {
                if let duplicateDog = duplicateDog {
                    bypassDuplicateCheck = true
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
        // Check for duplicates (unless bypassing)
        if !bypassDuplicateCheck {
            // When importing from database, only check against currently present dogs
            // This allows importing departed dogs for new visits
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
        }
        
        // Reset the bypass flag
        bypassDuplicateCheck = false
        
        // Load the imported data
        name = importedDog.name
        ownerName = importedDog.ownerName ?? ""
        medications = importedDog.medications ?? ""
        allergiesAndFeedingInstructions = importedDog.allergiesAndFeedingInstructions ?? ""
        needsWalking = importedDog.needsWalking
        walkingNotes = importedDog.walkingNotes ?? ""
        isDaycareFed = importedDog.isDaycareFed
        notes = importedDog.notes
        profileImage = importedDog.profilePictureData.flatMap { UIImage(data: $0) }
        age = importedDog.age
        gender = importedDog.gender ?? .unknown
        vaccinationEndDate = importedDog.vaccinationEndDate
        isNeuteredOrSpayed = importedDog.isNeuteredOrSpayed ?? false
        ownerPhoneNumber = importedDog.ownerPhoneNumber ?? ""
        
        // Keep current arrival date and boarding status
        // arrivalDate stays as current date
        // isBoarding stays as false
    }
    
    private func saveDog() async {
        isLoading = true
        
        // Convert profile image to data
        let profilePictureData = profileImage?.jpegData(compressionQuality: 0.8)
        
        if let existingDog = dog {
            // Update existing dog
            var updatedDog = existingDog
            updatedDog.name = name
            updatedDog.ownerName = ownerName.isEmpty ? nil : ownerName
            updatedDog.arrivalDate = arrivalDate
            updatedDog.departureDate = departureDate
            updatedDog.isBoarding = isBoarding
            updatedDog.boardingEndDate = isBoarding ? boardingEndDate : nil
            updatedDog.medications = medications.isEmpty ? nil : medications
            updatedDog.allergiesAndFeedingInstructions = allergiesAndFeedingInstructions.isEmpty ? nil : allergiesAndFeedingInstructions
            updatedDog.needsWalking = needsWalking
            updatedDog.walkingNotes = walkingNotes.isEmpty ? nil : walkingNotes
            updatedDog.isDaycareFed = isDaycareFed
            updatedDog.notes = notes
            updatedDog.profilePictureData = profilePictureData
            updatedDog.age = age ?? existingDog.age
            updatedDog.gender = (gender == .unknown ? existingDog.gender : gender)
            updatedDog.vaccinationEndDate = vaccinationEndDate ?? existingDog.vaccinationEndDate
            updatedDog.isNeuteredOrSpayed = isNeuteredOrSpayed ? true : (existingDog.isNeuteredOrSpayed ?? false)
            updatedDog.ownerPhoneNumber = ownerPhoneNumber.isEmpty ? (existingDog.ownerPhoneNumber ?? "") : ownerPhoneNumber
            updatedDog.updatedAt = Date()
            updatedDog.lastModifiedBy = authService.currentUser
            
            await dataManager.updateDog(updatedDog)
        } else {
            // Create new dog
            let newDog = Dog(
                name: name,
                ownerName: ownerName.isEmpty ? nil : ownerName,
                arrivalDate: arrivalDate,
                isBoarding: isBoarding,
                boardingEndDate: isBoarding ? boardingEndDate : nil,
                medications: medications.isEmpty ? nil : medications,
                allergiesAndFeedingInstructions: allergiesAndFeedingInstructions.isEmpty ? nil : allergiesAndFeedingInstructions,
                needsWalking: needsWalking,
                walkingNotes: walkingNotes.isEmpty ? nil : walkingNotes,
                isDaycareFed: isDaycareFed,
                notes: notes?.isEmpty == true ? nil : notes,
                profilePictureData: profilePictureData,
                age: age,
                gender: gender,
                vaccinationEndDate: vaccinationEndDate,
                isNeuteredOrSpayed: isNeuteredOrSpayed,
                ownerPhoneNumber: ownerPhoneNumber
            )
            
            await dataManager.addDog(newDog)
        }
        
        isLoading = false
        dismiss()
    }
}

// MARK: - Import from Database (for adding new dogs)

struct ImportSingleDogView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var importedDogs: [Dog] = []
    @State private var zoomedDog: Dog?
    
    let onImport: (Dog) -> Void
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("Loading database...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if importedDogs.isEmpty {
                    ContentUnavailableView {
                        Label("No Saved Dogs", systemImage: "database")
                    } description: {
                        Text("No previously saved dog entries found in the database.")
                    }
                } else {
                    List {
                        ForEach(filteredDogs) { dog in
                            ImportedDogRow(dog: dog, onZoom: {
                                zoomedDog = dog
                            }) {
                                onImport(dog)
                                dismiss()
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search dogs")
                }
            }
            .navigationTitle("Import from Database")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh") {
                        Task {
                            // Clear cache and reload
                            dataManager.clearImportCache()
                            await loadImportedDogs()
                        }
                    }
                    .disabled(isLoading)
                }
            }

            .overlay {
                if let dog = zoomedDog, let imageData = dog.profilePictureData, let uiImage = UIImage(data: imageData) {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                        .onTapGesture {
                            zoomedDog = nil
                        }
                        .overlay {
                            VStack {
                                Spacer()
                                
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: UIScreen.main.bounds.width * 0.8, maxHeight: UIScreen.main.bounds.height * 0.6)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(radius: 20)
                                
                                Spacer()
                                
                                Button("Close") {
                                    zoomedDog = nil
                                }
                                .foregroundStyle(.white)
                                .padding()
                                .background(.blue)
                                .clipShape(Capsule())
                                .padding(.bottom, 50)
                            }
                        }
                }
            }
        }
        .task {
            await loadImportedDogs()
        }
    }
    
    private var filteredDogs: [Dog] {
        if searchText.isEmpty {
            return importedDogs
        } else {
            return importedDogs.filter { dog in
                dog.name.localizedCaseInsensitiveContains(searchText) ||
                (dog.ownerName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    private func loadImportedDogs() async {
        isLoading = true
        
        print("🚀 Import: Starting optimized loadImportedDogs...")
        
        // Use optimized method that doesn't load all records
        let allDogs = await dataManager.fetchDogsForImport()
        
        print("🔍 Import: Found \(allDogs.count) total dogs in database (optimized)")
        
        // Filter out deleted dogs and group by name+owner
        let activeDogs = allDogs.filter { !$0.isDeleted }
        print("🔍 Import: After filtering deleted dogs: \(activeDogs.count) active dogs")
        
        var dogGroups: [String: [Dog]] = [:]
        for dog in activeDogs {
            let key = "\(dog.name.lowercased())_\(dog.ownerName?.lowercased() ?? "")"
            if dogGroups[key] == nil {
                dogGroups[key] = []
            }
            dogGroups[key]?.append(dog)
        }
        
        print("🔍 Import: Created \(dogGroups.count) dog groups")
        
        // For each group, if any dog is currently present, skip showing this group in the import list
        // Otherwise, show the most recent departed record, with the total visit count
        importedDogs = dogGroups.compactMap { key, dogs in
            print("🔍 Import: Processing group '\(key)' with \(dogs.count) dogs")
            
            // If any dog in the group is currently present, skip
            if dogs.contains(where: { $0.isCurrentlyPresent }) {
                print("⏭️ Import: Skipping group '\(key)' - has currently present dogs")
                return nil
            }
            
            // Find the most recent departed record
            let departedDogs = dogs.filter { !$0.isCurrentlyPresent }
            print("🔍 Import: Group '\(key)' has \(departedDogs.count) departed dogs")
            
            guard let mostRecent = departedDogs.sorted(by: { $0.arrivalDate > $1.arrivalDate }).first else {
                print("⚠️ Import: No departed dogs found in group '\(key)'")
                return nil
            }
            
            var importedDog = mostRecent
            importedDog.visitCount = dogs.count // Count all visits (present and past)
            print("✅ Import: Added dog '\(importedDog.name)' with \(importedDog.visitCount) visits")
            return importedDog
        }
        .sorted { $0.name < $1.name }
        
        print("✅ Import: Final result - \(importedDogs.count) dogs available for import")
        for dog in importedDogs {
            print("- \(dog.name) (\(dog.ownerName ?? "no owner"), visits: \(dog.visitCount), deleted: \(dog.isDeleted), present: \(dog.isCurrentlyPresent))")
        }
        
        isLoading = false
    }
    
    // MARK: - Lazy Loading for Import
    
    private func importDogWithFullRecords(_ dog: Dog) async -> Dog? {
        print("🔍 Import: Loading full records for \(dog.name)...")
        
        // Fetch the specific dog with all its records
        guard let fullDog = await dataManager.fetchSpecificDogWithRecords(for: dog.id.uuidString) else {
            print("❌ Import: Failed to load full records for \(dog.name)")
            return nil
        }
        
        print("✅ Import: Successfully loaded full records for \(fullDog.name)")
        return fullDog
    }
}

struct ImportedDogRow: View {
    let dog: Dog
    let onZoom: () -> Void
    let onImport: () -> Void
    @State private var isImporting = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture
            if let imageData = dog.profilePictureData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                    .onTapGesture {
                        onZoom()
                    }
            } else {
                Image(systemName: "camera.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .foregroundColor(.gray)
            }
            
            // Name and Owner
            VStack(alignment: .leading, spacing: 2) {
                Text(dog.name)
                    .font(.headline)
                if let ownerName = dog.ownerName {
                    Text("Owner: \(ownerName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Visit Count
            Text("\(dog.visitCount) visits")
                .font(.caption)
                .foregroundStyle(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.blue.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            importDog()
        }
    }
    
    private func importDog() {
        isImporting = true
        
        Task {
            // Simulate a brief delay to show loading state
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                onImport()
                isImporting = false
            }
        }
    }
} 