import SwiftUI
import SwiftData

struct DogFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var arrivalDate: Date
    @State private var needsWalking: Bool
    @State private var walkingNotes: String
    @State private var isBoarding: Bool
    @State private var specialInstructions: String
    @State private var medications: String
    @State private var isDaycareFed: Bool
    
    var dog: Dog?
    
    init(dog: Dog? = nil) {
        _name = State(initialValue: dog?.name ?? "")
        _arrivalDate = State(initialValue: dog?.arrivalDate ?? Date())
        _needsWalking = State(initialValue: dog?.needsWalking ?? false)
        _walkingNotes = State(initialValue: dog?.walkingNotes ?? "")
        _isBoarding = State(initialValue: dog?.isBoarding ?? false)
        _specialInstructions = State(initialValue: dog?.specialInstructions ?? "")
        _medications = State(initialValue: dog?.medications ?? "")
        _isDaycareFed = State(initialValue: dog?.isDaycareFed ?? false)
        self.dog = dog
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                    DatePicker("Arrival Time", selection: $arrivalDate)
                    Toggle("Boarding", isOn: $isBoarding)
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
                    TextField("Special Instructions", text: $specialInstructions, axis: .vertical)
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
                        save()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func save() {
        if let dog = dog {
            // Update existing dog
            dog.name = name
            dog.arrivalDate = arrivalDate
            dog.needsWalking = needsWalking
            dog.walkingNotes = walkingNotes.isEmpty ? nil : walkingNotes
            dog.isBoarding = isBoarding
            dog.specialInstructions = specialInstructions.isEmpty ? nil : specialInstructions
            dog.medications = medications.isEmpty ? nil : medications
            dog.isDaycareFed = isDaycareFed
            dog.updatedAt = Date()
        } else {
            // Create new dog
            let newDog = Dog(
                name: name,
                arrivalDate: arrivalDate,
                needsWalking: needsWalking,
                walkingNotes: walkingNotes.isEmpty ? nil : walkingNotes,
                isBoarding: isBoarding,
                specialInstructions: specialInstructions.isEmpty ? nil : specialInstructions,
                medications: medications.isEmpty ? nil : medications,
                isDaycareFed: isDaycareFed
            )
            modelContext.insert(newDog)
        }
        dismiss()
    }
} 