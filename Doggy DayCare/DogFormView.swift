import SwiftUI
import SwiftData

struct DogFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var arrivalDate = Date()
    @State private var departureDate: Date?
    @State private var boardingEndDate: Date?
    @State private var isBoarding = false
    @State private var isDaycareFed = false
    @State private var needsWalking = false
    @State private var walkingNotes: String?
    @State private var medications: String?
    @State private var notes: String?
    @State private var showingBoardingDatePicker = false
    
    private var dog: Dog?
    
    init(dog: Dog? = nil) {
        self.dog = dog
        if let dog = dog {
            _name = State(initialValue: dog.name)
            _arrivalDate = State(initialValue: dog.arrivalDate)
            _departureDate = State(initialValue: dog.departureDate)
            _boardingEndDate = State(initialValue: dog.boardingEndDate)
            _isBoarding = State(initialValue: dog.isBoarding)
            _isDaycareFed = State(initialValue: dog.isDaycareFed)
            _needsWalking = State(initialValue: dog.needsWalking)
            _walkingNotes = State(initialValue: dog.walkingNotes)
            _medications = State(initialValue: dog.medications)
            _notes = State(initialValue: dog.notes)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
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
                    }
                    
                    Toggle("Daycare Feeds", isOn: $isDaycareFed)
                }
                
                Section("Walking") {
                    Toggle("Needs Walking", isOn: $needsWalking)
                    if needsWalking {
                        TextField("Walking Notes", text: Binding(
                            get: { walkingNotes ?? "" },
                            set: { walkingNotes = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                
                Section("Additional Information") {
                    TextField("Medications (leave blank if none)", text: Binding(
                        get: { medications ?? "" },
                        set: { medications = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
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
                        save()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func save() {
        if let dog = dog {
            dog.name = name
            dog.arrivalDate = arrivalDate
            dog.departureDate = departureDate
            dog.boardingEndDate = boardingEndDate
            dog.isBoarding = isBoarding
            dog.isDaycareFed = isDaycareFed
            dog.needsWalking = needsWalking
            dog.walkingNotes = walkingNotes
            dog.medications = medications
            dog.notes = notes
            dog.setModelContext(modelContext)
        } else {
            let newDog = Dog(
                name: name,
                arrivalDate: arrivalDate,
                departureDate: departureDate,
                boardingEndDate: boardingEndDate,
                isBoarding: isBoarding,
                isDaycareFed: isDaycareFed,
                needsWalking: needsWalking,
                walkingNotes: walkingNotes,
                specialInstructions: nil,
                medications: medications,
                notes: notes,
                modelContext: modelContext
            )
            modelContext.insert(newDog)
        }
        
        try? modelContext.save()
        dismiss()
    }
} 