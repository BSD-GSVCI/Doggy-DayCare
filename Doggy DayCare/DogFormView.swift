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
    @State private var vaccinations: [VaccinationItem] = [
        .init(name: "Bordetella", endDate: nil),
        .init(name: "DHPP", endDate: nil),
        .init(name: "Rabies", endDate: nil),
        .init(name: "CIV", endDate: nil),
        .init(name: "Leptospirosis", endDate: nil)
    ]
    @State private var isNeuteredOrSpayed: Bool = false
    @State private var ownerPhoneNumber: String = ""
    
    // Medication state for new dog creation
    @State private var medications: [Medication] = []
    @State private var scheduledMedications: [ScheduledMedication] = []
    @State private var showingAddMedication = false
    @State private var showingAddScheduledMedication = false
    
    let dog: Dog?
    let addToDatabaseOnly: Bool
    

    
    init(dog: Dog? = nil, addToDatabaseOnly: Bool = false) {
        print("DogFormView init called")
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
                    if let dog = dog {
                        MedicationManagementView(dog: dog)
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
                                            print("✅ Added daily medication: \(medication.name)")
                                            print("📊 Total medications: \(medications.count)")
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
                                            print("✅ Added scheduled medication for: \(scheduledMedication.medicationId)")
                                            print("📊 Total scheduled medications: \(scheduledMedications.count)")
                                        },
                                        onAddMedication: { medication in
                                            medications.append(medication)
                                            print("✅ Added medication from scheduled sheet: \(medication.name)")
                                            print("📊 Total medications: \(medications.count)")
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
                print("Vaccinations changed: \(vaccinations.map { $0.name })")
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
                Text("A dog with the same name, owner, and phone number already exists in the database with \(duplicateDog.visitCount) previous visits. Would you like to use the imported data?")
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
            // Update existing dog
            var updatedDog = existingDog
            updatedDog.name = name
            updatedDog.ownerName = ownerName.isEmpty ? nil : ownerName
            updatedDog.arrivalDate = arrivalDate
            updatedDog.departureDate = departureDate
            updatedDog.isBoarding = isBoarding
            updatedDog.boardingEndDate = isBoarding ? boardingEndDate : nil
            // Medications handled by new system
            updatedDog.allergiesAndFeedingInstructions = allergiesAndFeedingInstructions.isEmpty ? nil : allergiesAndFeedingInstructions
            updatedDog.needsWalking = needsWalking
            updatedDog.walkingNotes = walkingNotes.isEmpty ? nil : walkingNotes
            updatedDog.isDaycareFed = isDaycareFed
            updatedDog.notes = notes
            updatedDog.profilePictureData = profilePictureData
            updatedDog.age = age ?? existingDog.age
            updatedDog.gender = (gender == .unknown ? existingDog.gender : gender)
            updatedDog.vaccinations = vaccinations
            updatedDog.isNeuteredOrSpayed = isNeuteredOrSpayed ? true : (existingDog.isNeuteredOrSpayed ?? false)
            updatedDog.ownerPhoneNumber = ownerPhoneNumber.isEmpty ? (existingDog.ownerPhoneNumber ?? "") : ownerPhoneNumber
            updatedDog.updatedAt = Date()
            updatedDog.lastModifiedBy = authService.currentUser
            
            // Use optimized update for vaccinations
            await dataManager.updateDogVaccinations(updatedDog, vaccinations: vaccinations)
        } else {
            // Create new dog
            let newDog = Dog(
                name: name,
                ownerName: ownerName.isEmpty ? nil : ownerName,
                arrivalDate: addToDatabaseOnly ? Date.distantPast : arrivalDate, // Use distant past for database-only dogs
                isBoarding: addToDatabaseOnly ? false : isBoarding, // No boarding for database-only dogs
                boardingEndDate: addToDatabaseOnly ? nil : (isBoarding ? boardingEndDate : nil), // No boarding end date for database-only dogs
                allergiesAndFeedingInstructions: allergiesAndFeedingInstructions.isEmpty ? nil : allergiesAndFeedingInstructions,
                needsWalking: needsWalking,
                walkingNotes: walkingNotes.isEmpty ? nil : walkingNotes,
                isDaycareFed: addToDatabaseOnly ? false : isDaycareFed, // No daycare feeds for database-only dogs
                notes: notes?.isEmpty == true ? nil : notes,
                profilePictureData: profilePictureData,
                age: age,
                gender: gender,
                vaccinations: vaccinations,
                isNeuteredOrSpayed: isNeuteredOrSpayed,
                ownerPhoneNumber: ownerPhoneNumber,
                medications: medications,
                scheduledMedications: scheduledMedications
            )
            
            print("🔄 DogFormView: Creating new dog with \(medications.count) medications and \(scheduledMedications.count) scheduled medications")
            print("📋 Medications: \(medications.map { $0.name })")
            print("📅 Scheduled Medications: \(scheduledMedications.map { $0.medicationId })")
            print("📅 Arrival Date: \(arrivalDate)")
            print("📅 Is Currently Present: \(newDog.isCurrentlyPresent)")
            print("📅 Has Medications: \(newDog.hasMedications)")
            
            print("🔄 DogFormView: Saving new dog '\(newDog.name)' - addToDatabaseOnly: \(addToDatabaseOnly)")
            
            if addToDatabaseOnly {
                print("📝 DogFormView: Adding dog to database only (will not appear on main page)")
                await dataManager.addDogToDatabase(newDog)
            } else {
                print("📝 DogFormView: Adding dog to main page and database")
                await dataManager.addDog(newDog)
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
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var authService = AuthenticationService.shared
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
        print("🗑️ Long press detected - attempting to delete medication: \(medication.name)")
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
                        print("🔘 Add new medication button tapped")
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
                            print("✅ Creating scheduled medication for: \(medication.name)")
                            onSave(scheduledMedication)
                            dismiss()
                        } else {
                            print("❌ No medication selected")
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
                                print("✅ Creating medication: \(medication.name)")
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
                    Text("Total Dogs: \(importedDogs.count)")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
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
            let key = "\(dog.name.lowercased())_\(dog.ownerName?.lowercased() ?? "")_\(dog.ownerPhoneNumber?.unformatPhoneNumber() ?? "")"
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
            print("- \(dog.name) (\(dog.ownerName ?? "no owner"), phone: \(dog.ownerPhoneNumber?.formatPhoneNumber() ?? "none"), visits: \(dog.visitCount), deleted: \(dog.isDeleted), present: \(dog.isCurrentlyPresent))")
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