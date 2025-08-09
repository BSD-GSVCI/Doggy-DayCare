import SwiftUI

struct FutureBookingFormView: View {
    @Environment(\.dismiss) private var dismiss
    let dataManager: DataManager
    
    @State private var name = ""
    @State private var ownerName = ""
    @State private var arrivalDate = Date()
    @State private var boardingEndDate = Date()
    @State private var isBoarding = false
    @State private var isDaycareFed = false
    @State private var needsWalking = false
    @State private var walkingNotes = ""
    @State private var allergiesAndFeedingInstructions = ""
    @State private var notes = ""
    @State private var profileImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var isLoading = false
    @State private var showingImportDatabase = false
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
    @State private var medications: [Medication] = []
    @State private var scheduledMedications: [ScheduledMedication] = []
    @State private var showingAddMedication = false
    @State private var showingAddScheduledMedication = false
    
    var body: some View {
        NavigationStack {
            Form {
                importDatabaseSection
                profileAndBasicInfoSection
                walkingSection
                medicationsSection
                additionalInfoSection
                miscDetailsSection
                vaccinationsSection
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
        .sheet(isPresented: $showingImagePicker) {
            PhotoLibraryPicker(image: $profileImage)
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(image: $profileImage)
        }
        .sheet(isPresented: $showingImportDatabase) {
            // TODO: Replace with PersistentDogImportView
            Text("Import feature is being updated for the new data model")
                .padding()
        }
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
}

// MARK: - View Sections
extension FutureBookingFormView {
    private var importDatabaseSection: some View {
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
    
    private var profileAndBasicInfoSection: some View {
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
            Toggle("Boarding", isOn: $isBoarding)
            if isBoarding {
                DatePicker("Boarding End Date", selection: $boardingEndDate, displayedComponents: .date)
            }
            Toggle("Daycare Feeds", isOn: $isDaycareFed)
        }
    }
    
    private var walkingSection: some View {
        Section("Walking") {
            Toggle("Needs Walking", isOn: $needsWalking)
            if needsWalking {
                TextField("Walking Notes", text: $walkingNotes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
    }
    
    private var medicationsSection: some View {
        Section("Medications") {
            VStack(alignment: .leading, spacing: 12) {
                dailyMedicationsView
                scheduledMedicationsView
                medicationButtonsView
            }
            .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private var dailyMedicationsView: some View {
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
    }
    
    @ViewBuilder
    private var scheduledMedicationsView: some View {
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
    }
    
    private var medicationButtonsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Add Daily Medication") {
                showingAddMedication = true
            }
            .foregroundStyle(.blue)
            .buttonStyle(.plain)
            
            Button("Add Scheduled Medication") {
                showingAddScheduledMedication = true
            }
            .foregroundStyle(.blue)
            .buttonStyle(.plain)
        }
    }
    
    private var additionalInfoSection: some View {
        Section("Additional Information") {
            TextField("Allergies & Feeding Instructions", text: $allergiesAndFeedingInstructions, axis: .vertical)
                .lineLimit(3...6)
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    private var miscDetailsSection: some View {
        Section("Miscellaneous Details") {
            TextField("Age", value: $age, format: .number)
                .keyboardType(.numberPad)
            Picker("Gender", selection: $gender) {
                ForEach(DogGender.allCases, id: \.self) { gender in
                    Text(gender.displayName).tag(gender)
                }
            }
            Toggle("Neutered/Spayed", isOn: $isNeuteredOrSpayed)
            TextField("Owner's Phone Number", text: $ownerPhoneNumber)
                .keyboardType(.phonePad)
                .onChange(of: ownerPhoneNumber) { _, newValue in
                    let formatted = newValue.formatPhoneNumber()
                    if formatted != newValue {
                        ownerPhoneNumber = formatted
                    }
                }
        }
    }
    
    private var vaccinationsSection: some View {
        Section("Vaccinations") {
            VaccinationListEditor(vaccinations: $vaccinations)
        }
    }
}

// MARK: - Functions
extension FutureBookingFormView {
    private func loadDogFromImport(_ importedDog: DogWithVisit) {
        name = importedDog.name
        ownerName = importedDog.ownerName ?? ""
        medications = importedDog.medications
        scheduledMedications = importedDog.scheduledMedications
        allergiesAndFeedingInstructions = importedDog.allergiesAndFeedingInstructions ?? ""
        needsWalking = importedDog.needsWalking
        walkingNotes = importedDog.walkingNotes ?? ""
        isDaycareFed = importedDog.isDaycareFed
        notes = importedDog.notes ?? ""
        profileImage = importedDog.profilePictureData.flatMap { UIImage(data: $0) }
        age = importedDog.age
        gender = importedDog.gender ?? .unknown
        vaccinations = importedDog.vaccinations
        isNeuteredOrSpayed = importedDog.isNeuteredOrSpayed ?? false
        ownerPhoneNumber = importedDog.ownerPhoneNumber ?? ""
    }
    
    private func addFutureBooking() async {
        isLoading = true
        
        let profilePictureData = profileImage?.jpegData(compressionQuality: 0.8)
        
        // For future bookings, we need to create a Visit for a future date
        // The persistent dog info needs to be created/updated
        await dataManager.addFutureBooking(
            name: name,
            ownerName: ownerName.isEmpty ? nil : ownerName,
            ownerPhoneNumber: ownerPhoneNumber.isEmpty ? nil : ownerPhoneNumber,
            arrivalDate: arrivalDate,
            isBoarding: isBoarding,
            boardingEndDate: isBoarding ? boardingEndDate : nil,
            isDaycareFed: isDaycareFed,
            needsWalking: needsWalking,
            walkingNotes: walkingNotes.isEmpty ? nil : walkingNotes,
            notes: notes.isEmpty ? nil : notes,
            specialInstructions: nil,
            allergiesAndFeedingInstructions: allergiesAndFeedingInstructions.isEmpty ? nil : allergiesAndFeedingInstructions,
            profilePictureData: profilePictureData,
            age: age,
            gender: gender,
            vaccinations: vaccinations,
            isNeuteredOrSpayed: isNeuteredOrSpayed,
            medications: medications,
            scheduledMedications: scheduledMedications
        )
        
        isLoading = false
        dismiss()
    }
}