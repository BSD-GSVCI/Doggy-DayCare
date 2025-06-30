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
                            "Boarding End Date",
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
            ImageSourcePicker(image: $profileImage)
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
                boardingEndDate: isBoarding ? boardingEndDate : nil,
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
    @State private var zoomedDog: Dog?
    @State private var showingDeleteAlert = false
    @State private var dogToDelete: Dog?
    
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
                            .contextMenu {
                                Button(role: .destructive) {
                                    dogToDelete = dog
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Permanently Delete", systemImage: "trash")
                                }
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
            .alert("Permanently Delete Dog", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let dog = dogToDelete {
                        print("🗑️ User confirmed permanent delete for dog: \(dog.name)")
                        Task {
                            print("🔄 Starting permanent delete process...")
                            await dataManager.permanentlyDeleteDog(dog)
                            print("🔄 Permanent delete completed, refreshing import list...")
                            await loadImportedDogs()
                            print("✅ Import list refresh completed")
                        }
                    }
                }
            } message: {
                if let dog = dogToDelete {
                    Text("Are you sure you want to permanently delete '\(dog.name)'? This action cannot be undone and will remove the dog from the database completely.")
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
        
        // Get all dogs from the database (including deleted ones)
        await dataManager.fetchAllDogsIncludingDeleted()
        let allDogs = dataManager.allDogs
        
        print("🔍 Import: Found \(allDogs.count) total dogs in database")
        
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
}

struct ImportedDogRow: View {
    let dog: Dog
    let onZoom: () -> Void
    let onImport: () -> Void
    
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
            onImport()
        }
    }
} 