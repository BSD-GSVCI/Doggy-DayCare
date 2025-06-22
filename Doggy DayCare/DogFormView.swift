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
                        }
                        
                        Button(profileImage == nil ? "Add Profile Picture" : "Change Picture") {
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
                        DatePicker(
                            "Expected Departure",
                            selection: Binding(
                                get: { boardingEndDate ?? Calendar.current.startOfDay(for: Date()) },
                                set: { boardingEndDate = $0 }
                            ),
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
                    TextField("Additional Notes", text: Binding(
                        get: { notes ?? "" },
                        set: { notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                        .lineLimit(3...6)
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
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $profileImage)
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
        notes = importedDog.notes
        profileImage = importedDog.profilePictureData.flatMap { UIImage(data: $0) }
        
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
                medications: medications.isEmpty ? nil : medications,
                allergiesAndFeedingInstructions: allergiesAndFeedingInstructions.isEmpty ? nil : allergiesAndFeedingInstructions,
                needsWalking: needsWalking,
                walkingNotes: walkingNotes.isEmpty ? nil : walkingNotes,
                isDaycareFed: isDaycareFed,
                notes: notes?.isEmpty == true ? nil : notes,
                profilePictureData: profilePictureData
            )
            
            await dataManager.addDog(newDog)
        }
        
        isLoading = false
        dismiss()
    }
}

struct ImportDatabaseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var importedDogs: [Dog] = []
    
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
                            ImportedDogRow(dog: dog) {
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
        
        // Get all dogs from the database (including departed ones)
        let allDogs = await dataManager.getAllDogs()
        
        // Group by name and owner to find unique dogs with visit counts
        var dogGroups: [String: [Dog]] = [:]
        
        for dog in allDogs {
            let key = "\(dog.name.lowercased())_\(dog.ownerName?.lowercased() ?? "")"
            if dogGroups[key] == nil {
                dogGroups[key] = []
            }
            dogGroups[key]?.append(dog)
        }
        
        // Create imported dog entries with visit counts
        importedDogs = dogGroups.compactMap { _, dogs in
            guard let firstDog = dogs.first else { return nil }
            
            var importedDog = firstDog
            importedDog.visitCount = dogs.count
            
            return importedDog
        }
        .sorted { $0.name < $1.name }
        
        isLoading = false
    }
}

struct ImportedDogRow: View {
    let dog: Dog
    let onImport: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(dog.name)
                        .font(.headline)
                    if let ownerName = dog.ownerName {
                        Text("Owner: \(ownerName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(dog.visitCount) visits")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            
            if let medications = dog.medications, !medications.isEmpty {
                Text("Medications: \(medications)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let allergiesAndFeedingInstructions = dog.allergiesAndFeedingInstructions, !allergiesAndFeedingInstructions.isEmpty {
                Text("Feeding: \(allergiesAndFeedingInstructions)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onImport()
        }
    }
} 