import SwiftUI

struct FutureBookingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddBooking = false
    @State private var searchText = ""
    
    private var filteredDogs: [DogWithVisit] {
        if searchText.isEmpty {
            return dataManager.dogs
        } else {
            return dataManager.dogs.filter { dog in
                dog.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var futureBookings: [DogWithVisit] {
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
                    FutureBookingFormView(dataManager: dataManager)
                }
            }
            .imageOverlay()
        }
    }
}

struct FutureBookingRow: View {
    @EnvironmentObject var dataManager: DataManager
    let dog: DogWithVisit
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
                Task { @MainActor in
                    await dataManager.deleteDog(dog)
                }
            }
        } message: {
            Text("Are you sure you want to delete the future booking for \(dog.name)?")
        }
    }
}

struct FutureBookingEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    let dog: DogWithVisit
    
    @State private var name: String
    @State private var ownerName: String
    @State private var arrivalDate: Date
    @State private var isBoarding: Bool
    @State private var boardingEndDate: Date
    @State private var isDaycareFed: Bool
    @State private var needsWalking: Bool
    @State private var walkingNotes: String
    @State private var medications: [Medication]
    @State private var scheduledMedications: [ScheduledMedication]
    @State private var showingAddMedication = false
    @State private var showingAddScheduledMedication = false
    @State private var allergiesAndFeedingInstructions: String
    @State private var notes: String
    @State private var specialInstructions: String
    @State private var isLoading = false
    @State private var profileImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var age: Int?
    @State private var gender: DogGender
    @State private var vaccinations: [VaccinationItem]
    @State private var isNeuteredOrSpayed: Bool
    @State private var ownerPhoneNumber: String
    
    init(dog: DogWithVisit) {
        self.dog = dog
        self._name = State(initialValue: dog.name)
        self._ownerName = State(initialValue: dog.ownerName ?? "")
        self._arrivalDate = State(initialValue: dog.arrivalDate)
        self._isBoarding = State(initialValue: dog.isBoarding)
        
        let defaultBoardingEndDate: Date
        if let existingBoardingEndDate = dog.boardingEndDate {
            defaultBoardingEndDate = existingBoardingEndDate
        } else {
            defaultBoardingEndDate = Calendar.current.date(byAdding: .day, value: 7, to: dog.arrivalDate) ?? Date()
        }
        self._boardingEndDate = State(initialValue: defaultBoardingEndDate)
        
        self._isDaycareFed = State(initialValue: dog.isDaycareFed)
        self._needsWalking = State(initialValue: dog.needsWalking)
        self._walkingNotes = State(initialValue: dog.walkingNotes ?? "")
        self._medications = State(initialValue: dog.medications)
        self._scheduledMedications = State(initialValue: dog.scheduledMedications)
        self._allergiesAndFeedingInstructions = State(initialValue: dog.allergiesAndFeedingInstructions ?? "")
        self._notes = State(initialValue: dog.notes ?? "")
        self._specialInstructions = State(initialValue: dog.specialInstructions ?? "")
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
                
                Section("Walking") {
                    Toggle("Needs Walking", isOn: $needsWalking)
                    if needsWalking {
                        TextField("Walking Notes", text: $walkingNotes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                
                Section("Medications") {
                    VStack(alignment: .leading, spacing: 12) {
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
                    .padding(.top, 8)
                }
                
                Section("Additional Information") {
                    TextField("Allergies & Feeding Instructions", text: $allergiesAndFeedingInstructions, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
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
                
                Section("Vaccinations") {
                    VaccinationListEditor(vaccinations: $vaccinations)
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
        .sheet(isPresented: $showingAddMedication) {
            AddDailyMedicationSheet(
                onSave: { medication in
                    medications.append(medication)
                    print("✅ Added daily medication: \(medication.name)")
                    print("📊 Total medications: \(medications.count)")
                }
            )
        }
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
    
    private func updateFutureBooking() async {
        isLoading = true
        
        let profilePictureData = profileImage?.jpegData(compressionQuality: 0.8)
        
        // Update the future booking using DataManager
        await dataManager.updateFutureBooking(
            dogWithVisit: dog,
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
            specialInstructions: specialInstructions.isEmpty ? nil : specialInstructions,
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

#Preview {
    FutureBookingsView()
        .environmentObject(DataManager.shared)
}