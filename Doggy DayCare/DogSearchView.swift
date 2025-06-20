import SwiftUI
import SwiftData

struct DogSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthenticationService.shared
    
    @State private var searchText = ""
    @State private var selectedDog: Dog?
    @State private var showingDogForm = false
    
    // Query all dogs that have been checked out (completed stays)
    @Query(sort: \Dog.name) private var allDogs: [Dog]
    
    private var completedDogs: [Dog] {
        allDogs.filter { dog in
            // Dogs that have been checked out (have a departure date)
            dog.departureDate != nil
        }
    }
    
    private var filteredDogs: [Dog] {
        if searchText.isEmpty {
            return completedDogs
        } else {
            return completedDogs.filter { dog in
                dog.name.localizedCaseInsensitiveContains(searchText) ||
                (dog.ownerName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if filteredDogs.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Previous Dogs" : "No Dogs Found",
                        systemImage: "magnifyingglass",
                        description: Text(searchText.isEmpty ? "Dogs will appear here after they complete their stay" : "Try searching with a different name")
                    )
                } else {
                    List {
                        ForEach(filteredDogs) { dog in
                            DogSearchRow(dog: dog) { selectedDog in
                                self.selectedDog = selectedDog
                                showingDogForm = true
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search by dog name or owner")
            .navigationTitle("Search Dogs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingDogForm) {
            if let selectedDog = selectedDog {
                DogFormFromSearchView(originalDog: selectedDog)
            }
        }
    }
}

struct DogSearchRow: View {
    let dog: Dog
    let onSelect: (Dog) -> Void
    
    var body: some View {
        Button {
            onSelect(dog)
        } label: {
            HStack {
                // Profile picture if available
                if let imageData = dog.profilePictureData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "dog.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(.gray)
                        .frame(width: 50, height: 50)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(dog.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let ownerName = dog.ownerName, !ownerName.isEmpty {
                        Text("Owner: \(ownerName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Last visit: \(dog.departureDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct DogFormFromSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthenticationService.shared
    
    let originalDog: Dog
    
    @State private var name: String
    @State private var ownerName: String
    @State private var arrivalDate = Date()
    @State private var boardingEndDate = Date()
    @State private var isBoardingState: Bool
    @State private var isDaycareFed: Bool
    @State private var needsWalking: Bool
    @State private var walkingNotes: String
    @State private var medications: String
    @State private var allergiesAndFeedingInstructions: String
    @State private var notes: String
    @State private var profileImage: UIImage?
    
    init(originalDog: Dog) {
        self.originalDog = originalDog
        
        // Initialize state with original dog's data
        _name = State(initialValue: originalDog.name)
        _ownerName = State(initialValue: originalDog.ownerName ?? "")
        _isBoardingState = State(initialValue: false) // Default to daycare
        _isDaycareFed = State(initialValue: originalDog.isDaycareFed)
        _needsWalking = State(initialValue: originalDog.needsWalking)
        _walkingNotes = State(initialValue: originalDog.walkingNotes ?? "")
        _medications = State(initialValue: originalDog.medications ?? "")
        _allergiesAndFeedingInstructions = State(initialValue: originalDog.allergiesAndFeedingInstructions ?? "")
        _notes = State(initialValue: originalDog.notes ?? "")
        
        if let imageData = originalDog.profilePictureData {
            _profileImage = State(initialValue: UIImage(data: imageData))
        }
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
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    
                    TextField("Name", text: $name)
                    TextField("Owner Name", text: $ownerName)
                    DatePicker("Arrival Time", selection: $arrivalDate)
                    
                    Toggle("Boarding", isOn: $isBoardingState)
                        .onChange(of: isBoardingState) { _, newValue in
                            if !newValue {
                                boardingEndDate = Date()
                            }
                        }
                    
                    if isBoardingState {
                        DatePicker(
                            "Expected Departure",
                            selection: $boardingEndDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
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
                    TextField("Allergies and Feeding Instructions (leave blank if none)", text: $allergiesAndFeedingInstructions, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Additional Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Register \(originalDog.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Register") {
                        registerDog()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func registerDog() {
        // Convert profile image to data
        let profilePictureData = profileImage?.jpegData(compressionQuality: 0.8)
        
        let newDog = Dog(
            name: name,
            ownerName: ownerName.isEmpty ? nil : ownerName,
            arrivalDate: arrivalDate,
            isBoarding: isBoardingState,
            medications: medications.isEmpty ? nil : medications,
            allergiesAndFeedingInstructions: allergiesAndFeedingInstructions.isEmpty ? nil : allergiesAndFeedingInstructions,
            needsWalking: needsWalking,
            walkingNotes: walkingNotes.isEmpty ? nil : walkingNotes,
            isDaycareFed: isDaycareFed,
            notes: notes.isEmpty ? nil : notes,
            profilePictureData: profilePictureData
        )
        
        newDog.boardingEndDate = isBoardingState ? boardingEndDate : nil
        newDog.createdBy = authService.currentUser
        newDog.lastModifiedBy = authService.currentUser
        
        modelContext.insert(newDog)
        try? modelContext.save()
        dismiss()
    }
} 