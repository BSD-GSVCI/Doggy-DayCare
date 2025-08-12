import SwiftUI

struct DogFormView: View {
    @Environment(\.dismiss) private var dismiss
    let dataManager: DataManager
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

    @State private var allergiesAndFeedingInstructions = ""
    @State private var notes: String?
    @State private var specialInstructions: String?
    @State private var showingBoardingDatePicker = false
    @State private var profileImage: UIImage?
    @State private var showingImagePicker = false
    @State private var isLoading = false
    @State private var showingImportDatabase = false
    @State private var showingDuplicateAlert = false
    @State private var duplicateDog: DogWithVisit?
    @State private var bypassDuplicateCheck = false
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
    
    // Track if we're using an existing PersistentDog (from database import)
    @State private var existingPersistentDogId: UUID? = nil
    
    // Medication state for new dog creation
    @State private var medications: [Medication] = []
    @State private var scheduledMedications: [ScheduledMedication] = []
    @State private var showingAddMedication = false
    @State private var showingAddScheduledMedication = false
    
    let dog: DogWithVisit?
    let addToDatabaseOnly: Bool
    

    
    private var importSection: some View {
        Section {
            Button {
                showingImportDatabase = true
            } label: {
                HStack {
                    Image(systemName: "arrow.down.doc")
                        .foregroundStyle(.blue)
                    Text("Select Dog from Database")
                        .foregroundStyle(.blue)
                }
            }
        } header: {
            Text("Quick Select")
        } footer: {
            Text("Select saved dog entries to avoid re-entering information")
        }
    }
    
    init(dataManager: DataManager, dog: DogWithVisit? = nil, addToDatabaseOnly: Bool = false) {
        #if DEBUG
        print("DogFormView init called")
        #endif
        self.dataManager = dataManager
        self.dog = dog
        self.addToDatabaseOnly = addToDatabaseOnly
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
            _allergiesAndFeedingInstructions = State(initialValue: dog.allergiesAndFeedingInstructions ?? "")
            _notes = State(initialValue: dog.notes)
            if let imageData = dog.profilePictureData {
                _profileImage = State(initialValue: UIImage(data: imageData))
            }
            _age = State(initialValue: dog.age)
            _gender = State(initialValue: dog.gender ?? .unknown)
            // Always preserve existing vaccination end dates and add missing ones if needed
            let defaultVaccinationNames = [
                "Bordetella", "DHPP", "Rabies", "CIV", "Leptospirosis"
            ]
            var mergedVaccinations: [VaccinationItem] = []
            for name in defaultVaccinationNames {
                if let existing = dog.vaccinations.first(where: { $0.name == name }) {
                    mergedVaccinations.append(existing)
                } else {
                    mergedVaccinations.append(VaccinationItem(name: name, endDate: nil))
                }
            }
            _vaccinations = State(initialValue: mergedVaccinations)
            _isNeuteredOrSpayed = State(initialValue: dog.isNeuteredOrSpayed ?? false)
            _ownerPhoneNumber = State(initialValue: dog.ownerPhoneNumber ?? "")
            _medications = State(initialValue: dog.medications)
            _scheduledMedications = State(initialValue: dog.scheduledMedications)
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
            _allergiesAndFeedingInstructions = State(initialValue: "")
            _notes = State(initialValue: nil)
            _profileImage = State(initialValue: nil)
            _age = State(initialValue: nil)
            _gender = State(initialValue: .unknown)
            _vaccinations = State(initialValue: [
                .init(name: "Bordetella", endDate: nil),
                .init(name: "DHPP", endDate: nil),
                .init(name: "Rabies", endDate: nil),
                .init(name: "CIV", endDate: nil),
                .init(name: "Leptospirosis", endDate: nil)
            ])
            _isNeuteredOrSpayed = State(initialValue: false)
            _ownerPhoneNumber = State(initialValue: "")
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Import from Database Section (only show when adding new dog and not database-only)
                if dog == nil && !addToDatabaseOnly {
                    importSection
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
                    
                    // Only show arrival/boarding fields if not adding to database only
                    if !addToDatabaseOnly {
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
                }
                
                Section("Walking") {
                    Toggle("Needs Walking", isOn: $needsWalking)
                    if needsWalking {
                        TextField("Walking Notes", text: $walkingNotes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                
                Section("Medications") {
                    if dog != nil {
                        // For existing dogs, medications are managed through the dedicated interface
                    Text("Use the 'Manage Medications' button in the dog detail view")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    } else {
                        // For new dog creation, use a simplified medication management interface
                        VStack(alignment: .leading, spacing: 12) {
                            // Daily Medications
                            if !medications.filter({ $0.type == .daily }).isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Daily Medications")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    
                                    ForEach(medications.filter({ $0.type == .daily })) { medication in
                                        HStack {
                                            Text(medication.name)
                                                .foregroundStyle(.primary)
                                            if let notes = medication.notes {
                                                Text("(\(notes))")
                                                    .foregroundStyle(.secondary)
                                                    .font(.caption)
                                            }
                                            Spacer()
                                            Button("Remove") {
                                                medications.removeAll { $0.id == medication.id }
                                            }
                                            .foregroundStyle(.red)
                                            .font(.caption)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                            
                            // Scheduled Medications
                            if !scheduledMedications.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Scheduled Medications")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    
                                    ForEach(scheduledMedications) { scheduledMedication in
                                        HStack {
                                            if let medication = medications.first(where: { $0.id == scheduledMedication.medicationId }) {
                                                Text(medication.name)
                                                    .foregroundStyle(.primary)
                                            }
                                            Text("(\(scheduledMedication.scheduledDate.formatted(date: .abbreviated, time: .shortened)))")
                                                .foregroundStyle(.secondary)
                                                .font(.caption)
                                            if let notes = scheduledMedication.notes {
                                                Text("(\(notes))")
                                                    .foregroundStyle(.secondary)
                                                    .font(.caption)
                                            }
                                            Spacer()
                                            Button("Remove") {
                                                scheduledMedications.removeAll { $0.id == scheduledMedication.id }
                                            }
                                            .foregroundStyle(.red)
                                            .font(.caption)
                                        }
                                        .padding(.vertical, 2)
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
                                .sheet(isPresented: $showingAddMedication) {
                                    AddDailyMedicationSheet(
                                        onSave: { medication in
                                            medications.append(medication)
                                            #if DEBUG
                                            print("✅ Added daily medication: \(medication.name)")
                                            print("📊 Total medications: \(medications.count)")
                                            #endif
                                        }
                                    )
                                }
                                
                                Button("Add/Edit Scheduled Medication") {
                                    showingAddScheduledMedication = true
                                }
                                .foregroundStyle(.blue)
                                .buttonStyle(.plain)
                                .sheet(isPresented: $showingAddScheduledMedication) {
                                    AddScheduledMedicationForNewDogSheet(
                                        availableMedications: medications,
                                        onSave: { scheduledMedication in
                                            scheduledMedications.append(scheduledMedication)
                                            #if DEBUG
                                            print("✅ Added scheduled medication for: \(scheduledMedication.medicationId)")
                                            print("📊 Total scheduled medications: \(scheduledMedications.count)")
                                            #endif
                                        },
                                        onAddMedication: { medication in
                                            medications.append(medication)
                                            #if DEBUG
                                            print("✅ Added medication from scheduled sheet: \(medication.name)")
                                            print("📊 Total medications: \(medications.count)")
                                            #endif
                                        }
                                    )
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                
                Section("Additional Information") {
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
                    Toggle("Neutered/Spayed", isOn: $isNeuteredOrSpayed)
                    TextField("Owner's Phone Number", text: $ownerPhoneNumber)
                        .keyboardType(.phonePad)
                        .onChange(of: ownerPhoneNumber) { _, newValue in
                            // Format the phone number as user types
                            let formatted = newValue.formatPhoneNumber()
                            if formatted != newValue {
                                ownerPhoneNumber = formatted
                            }
                        }
                }
                Section("Vaccinations") {
                    VaccinationListEditor(vaccinations: $vaccinations)
                }
            }
            .onChange(of: vaccinations) {
                #if DEBUG
                print("Vaccinations changed: \(vaccinations.map { $0.name })")
                #endif
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
            CheckInDogPickerView(dataManager: dataManager) { selectedDog in
                loadDogFromImport(selectedDog)
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
                Text("A dog with the same name, owner, and phone number already exists in the database with \(duplicateDog.visitCount) previous visits. Would you like to use the imported data?")
            }
        }
    }
    
    private func loadDogFromImport(_ importedDog: DogWithVisit) {
        // Check for duplicates (unless bypassing)
        if !bypassDuplicateCheck {
            // When importing from database, only check against currently present dogs
            // This allows importing departed dogs for new visits
            let existingDogs = dataManager.dogs.filter { dog in
                dog.isCurrentlyPresent && // Only check currently present dogs
                dog.name.lowercased() == importedDog.name.lowercased() &&
                (dog.ownerName?.lowercased() == importedDog.ownerName?.lowercased() || 
                 (dog.ownerName == nil && importedDog.ownerName == nil)) &&
                (dog.ownerPhoneNumber?.unformatPhoneNumber() == importedDog.ownerPhoneNumber?.unformatPhoneNumber() ||
                 (dog.ownerPhoneNumber == nil && importedDog.ownerPhoneNumber == nil))
            }
            
            if !existingDogs.isEmpty {
                duplicateDog = existingDogs.first
                showingDuplicateAlert = true
                return
            }
        }
        
        // Reset the bypass flag
        bypassDuplicateCheck = false
        
        // IMPORTANT: Track that we're using an existing PersistentDog
        existingPersistentDogId = importedDog.persistentDog.id
        
        // Load the imported data
        name = importedDog.name
        ownerName = importedDog.ownerName ?? ""
        medications = importedDog.medications
        scheduledMedications = importedDog.scheduledMedications
        allergiesAndFeedingInstructions = importedDog.allergiesAndFeedingInstructions ?? ""
        needsWalking = importedDog.needsWalking
        walkingNotes = importedDog.walkingNotes ?? ""
        isDaycareFed = importedDog.isDaycareFed
        notes = importedDog.notes
        profileImage = importedDog.profilePictureData.flatMap { UIImage(data: $0) }
        age = importedDog.age
        gender = importedDog.gender ?? .unknown
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
            // Update existing dog using DogWithVisit structure
            await dataManager.updateDogWithVisit(
                dogWithVisit: existingDog,
                name: name,
                ownerName: ownerName.isEmpty ? nil : ownerName,
                ownerPhoneNumber: ownerPhoneNumber.isEmpty ? nil : ownerPhoneNumber,
                arrivalDate: arrivalDate,
                isBoarding: isBoarding,
                boardingEndDate: isBoarding ? boardingEndDate : nil,
                isDaycareFed: isDaycareFed,
                needsWalking: needsWalking,
                walkingNotes: walkingNotes.isEmpty ? nil : walkingNotes,
                notes: notes?.isEmpty == true ? nil : notes,
                specialInstructions: specialInstructions?.isEmpty == true ? nil : specialInstructions,
                allergiesAndFeedingInstructions: allergiesAndFeedingInstructions.isEmpty ? nil : allergiesAndFeedingInstructions,
                profilePictureData: profilePictureData,
                age: age,
                gender: gender,
                vaccinations: vaccinations,
                isNeuteredOrSpayed: isNeuteredOrSpayed,
                medications: medications,
                scheduledMedications: scheduledMedications
            )
        } else {
            // Create new dog using the new system
            #if DEBUG
            print("🔄 DogFormView: Creating new dog with \(medications.count) medications and \(scheduledMedications.count) scheduled medications")
            print("📋 Medications: \(medications.map { $0.name })")
            print("📅 Scheduled Medications: \(scheduledMedications.map { $0.medicationId })")
            print("📅 Arrival Date: \(arrivalDate)")
            #endif
            
            if addToDatabaseOnly {
                #if DEBUG
                print("📝 DogFormView: Adding dog to database only (will not appear on main page)")
                #endif
                await dataManager.addPersistentDogOnly(
                    name: name,
                    ownerName: ownerName.isEmpty ? nil : ownerName,
                    ownerPhoneNumber: ownerPhoneNumber.isEmpty ? nil : ownerPhoneNumber,
                    needsWalking: needsWalking,
                    walkingNotes: walkingNotes.isEmpty ? nil : walkingNotes,
                    notes: notes?.isEmpty == true ? nil : notes,
                    specialInstructions: specialInstructions?.isEmpty == true ? nil : specialInstructions,
                    allergiesAndFeedingInstructions: allergiesAndFeedingInstructions.isEmpty ? nil : allergiesAndFeedingInstructions,
                    profilePictureData: profilePictureData,
                    age: age,
                    gender: gender,
                    vaccinations: vaccinations,
                    isNeuteredOrSpayed: isNeuteredOrSpayed
                )
            } else {
                // Check if we're using an existing dog from database
                if let existingDogId = existingPersistentDogId {
                    // Using an existing PersistentDog from database - just create a visit
                    #if DEBUG
                    print("📝 DogFormView: Creating new visit for existing dog ID: \(existingDogId)")
                    #endif
                    await dataManager.addVisitForExistingDog(
                        dogId: existingDogId,
                        arrivalDate: arrivalDate,
                        isBoarding: isBoarding,
                        boardingEndDate: isBoarding ? boardingEndDate : nil,
                        medications: medications,
                        scheduledMedications: scheduledMedications
                    )
                } else {
                    // Creating a completely new dog
                    #if DEBUG
                    print("📝 DogFormView: Adding new dog to main page and database")
                    #endif
                    await dataManager.addDogWithVisit(
                        name: name,
                        ownerName: ownerName.isEmpty ? nil : ownerName,
                        ownerPhoneNumber: ownerPhoneNumber.isEmpty ? nil : ownerPhoneNumber,
                        arrivalDate: arrivalDate,
                        isBoarding: isBoarding,
                        boardingEndDate: isBoarding ? boardingEndDate : nil,
                        isDaycareFed: isDaycareFed,
                        needsWalking: needsWalking,
                        walkingNotes: walkingNotes.isEmpty ? nil : walkingNotes,
                        notes: notes?.isEmpty == true ? nil : notes,
                        specialInstructions: specialInstructions?.isEmpty == true ? nil : specialInstructions,
                        allergiesAndFeedingInstructions: allergiesAndFeedingInstructions.isEmpty ? nil : allergiesAndFeedingInstructions,
                        profilePictureData: profilePictureData,
                        age: age,
                        gender: gender,
                        vaccinations: vaccinations,
                        isNeuteredOrSpayed: isNeuteredOrSpayed,
                        medications: medications,
                        scheduledMedications: scheduledMedications
                    )
                }
            }
        }
        
        isLoading = false
        dismiss()
    }
}

// MARK: - Medication Management for New Dog Creation

struct AddDailyMedicationSheet: View {
    @Environment(\.dismiss) private var dismiss
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
            .navigationTitle("Add Daily Medication")
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
                            type: .daily,
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

struct AddScheduledMedicationForNewDogSheet: View {
    @Environment(\.dismiss) private var dismiss
    let availableMedications: [Medication]
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
        // Simple delete function to remove mistyped medications from the selection list
        #if DEBUG
        print("🗑️ Long press detected - attempting to delete medication: \(medication.name)")
        #endif
        // This will be handled by the parent view's medications array
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
                        #if DEBUG
                        print("🔘 Add new medication button tapped")
                        #endif
                        showingAddMedication = true
                    }
                    .foregroundStyle(.blue)
                }
                
                Section("Medication(s)") {
                    // Filter out daily medications - only show scheduled medications for scheduling
                    let scheduledMedications = availableMedications.filter { $0.type == .scheduled }
                    
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
                            #if DEBUG
                            print("✅ Creating scheduled medication for: \(medication.name)")
                            #endif
                            onSave(scheduledMedication)
                            dismiss()
                        } else {
                            #if DEBUG
                            print("❌ No medication selected")
                            #endif
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
                                #if DEBUG
                                print("✅ Creating medication: \(medication.name)")
                                #endif
                                onAddMedication(medication)
                                selectedMedication = medication
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

// MARK: - Import from Database (for adding new dogs)

struct CheckInDogPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let dataManager: DataManager
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var availableDogsForCheckIn: [DogWithVisit] = []
    @State private var zoomedDog: DogWithVisit?
    
    let onSelect: (DogWithVisit) -> Void
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("Loading database...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if availableDogsForCheckIn.isEmpty {
                    ContentUnavailableView {
                        Label("No Saved Dogs", systemImage: "database")
                    } description: {
                        Text("No previously saved dog entries found in the database.")
                    }
                } else {
                    Text("Available for Check-In: \(availableDogsForCheckIn.count)")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                    List {
                        ForEach(filteredDogs) { dog in
                            ImportedDogRow(dog: dog, onZoom: {
                                zoomedDog = dog
                            }) {
                                onSelect(dog)
                                dismiss()
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search dogs")
                }
            }
            .navigationTitle("Select Dog from Database")
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
                            await loadAvailableDogsForCheckIn()
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
            await loadAvailableDogsForCheckIn()
        }
    }
    
    private var filteredDogs: [DogWithVisit] {
        if searchText.isEmpty {
            return availableDogsForCheckIn
        } else {
            return availableDogsForCheckIn.filter { dog in
                dog.name.localizedCaseInsensitiveContains(searchText) ||
                (dog.ownerName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    private func loadAvailableDogsForCheckIn() async {
        isLoading = true
        
        #if DEBUG
        print("🚀 CheckInPicker: Loading available dogs for check-in...")
        #endif
        
        // First ensure we have all persistent dogs loaded
        await dataManager.fetchAllPersistentDogs()
        
        // Get all persistent dogs from database
        let allPersistentDogs = dataManager.allDogs
        
        // Get currently present dogs from main page
        let currentlyPresentDogs = dataManager.dogs
        let currentlyPresentDogIds = Set(currentlyPresentDogs.map { $0.id })
        
        // Filter to only show dogs that are NOT currently present (available for check-in)
        availableDogsForCheckIn = allPersistentDogs.filter { dog in
            !currentlyPresentDogIds.contains(dog.id)
        }.sorted { $0.name < $1.name }
        
        #if DEBUG
        print("✅ CheckInPicker: Found \(availableDogsForCheckIn.count) dogs available for check-in (out of \(allPersistentDogs.count) total)")
        #endif
        
        isLoading = false
    }
    
    // MARK: - Lazy Loading for Import
    
    private func importDogWithFullRecords(_ dog: DogWithVisit) async -> DogWithVisit? {
        #if DEBUG
        print("🔍 Import: Loading full records for \(dog.name)...")
        #endif
        
        // For now, return the dog as-is since we're using DogWithVisit
        #if DEBUG
        print("✅ Import: Successfully loaded full records for \(dog.name)")
        #endif
        return dog
    }
}

struct ImportedDogRow: View {
    let dog: DogWithVisit
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

struct VaccinationListEditor: View {
    @Binding var vaccinations: [VaccinationItem]
    @State private var editingIndex: Int? = nil
    @State private var tempDate: Date = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array($vaccinations.prefix(5).enumerated()), id: \ .element.id) { index, $item in
                HStack {
                    Text(item.name)
                        .frame(maxWidth: 120, alignment: .leading)
                    if let endDate = item.endDate {
                        Button(action: {
                            tempDate = endDate
                            editingIndex = index
                        }) {
                            Text(endDate, style: .date)
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                        Button(action: {
                            item.endDate = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: {
                            tempDate = Date()
                            editingIndex = index
                        }) {
                            Text("Set Date")
                                .foregroundColor(.blue)
                                .opacity(0.7)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: Binding<Bool>(
            get: { editingIndex != nil },
            set: { newValue in if !newValue { editingIndex = nil } }
        )) {
            if let idx = editingIndex {
                VStack {
                    DatePicker(
                        "Select End Date",
                        selection: Binding(
                            get: { tempDate },
                            set: { tempDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding()
                    Button("Save") {
                        vaccinations[idx].endDate = tempDate
                        editingIndex = nil
                    }
                    .padding(.bottom)
                    Button("Cancel", role: .cancel) {
                        editingIndex = nil
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
} 