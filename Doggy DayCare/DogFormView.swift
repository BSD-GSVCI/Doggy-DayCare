import SwiftUI
import SwiftData

struct DogFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
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
                        saveDog()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $profileImage)
        }
    }
    
    private func saveDog() {
        // Convert profile image to data
        let profilePictureData = profileImage?.jpegData(compressionQuality: 0.8)
        
        if let existingDog = dog {
            existingDog.name = name
            existingDog.ownerName = ownerName.isEmpty ? nil : ownerName
            existingDog.arrivalDate = arrivalDate
            existingDog.departureDate = departureDate
            existingDog.isBoarding = isBoarding
            existingDog.boardingEndDate = isBoarding ? boardingEndDate : nil
            existingDog.medications = medications.isEmpty ? nil : medications
            existingDog.allergiesAndFeedingInstructions = allergiesAndFeedingInstructions.isEmpty ? nil : allergiesAndFeedingInstructions
            existingDog.needsWalking = needsWalking
            existingDog.walkingNotes = walkingNotes.isEmpty ? nil : walkingNotes
            existingDog.isDaycareFed = isDaycareFed
            existingDog.notes = notes
            existingDog.profilePictureData = profilePictureData
            existingDog.updatedAt = Date()
            existingDog.lastModifiedBy = authService.currentUser
        } else {
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
            newDog.boardingEndDate = isBoarding ? boardingEndDate : nil
            newDog.createdBy = authService.currentUser
            newDog.lastModifiedBy = authService.currentUser
            modelContext.insert(newDog)
        }
        
        try? modelContext.save()
        dismiss()
    }
} 