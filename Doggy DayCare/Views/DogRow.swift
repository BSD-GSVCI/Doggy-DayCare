import SwiftUI

struct DogRow: View {
    let dog: Dog
    @EnvironmentObject var dataManager: DataManager
    @State private var showingDetail = false
    @State private var showingDeleteAlert = false
    @State private var showingUndoAlert = false
    @State private var showingEditDeparture = false
    @State private var newDepartureDate = Date()
    
    private let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy"
        return formatter
    }()
    
    private let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationLink(destination: DogDetailView(dog: dog)) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(dog.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            if dog.needsWalking {
                                Image(systemName: "figure.walk")
                                    .foregroundStyle(.blue)
                                    .font(.caption)
                            }
                            
                            if let medications = dog.medications, !medications.isEmpty {
                                Image(systemName: "pills")
                                    .foregroundStyle(.purple)
                                    .font(.caption)
                            }
                        }
                        
                        // Arrival and departure times
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(shortDateFormatter.string(from: dog.arrivalDate)) \(shortTimeFormatter.string(from: dog.arrivalDate))")
                                .font(.caption)
                                .foregroundStyle(.green)
                            
                            if let departureDate = dog.departureDate {
                                Text("\(shortDateFormatter.string(from: departureDate)) \(shortTimeFormatter.string(from: departureDate))")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        
                        // Boarding departure date pill
                        if dog.isBoarding, let boardingEndDate = dog.boardingEndDate {
                            Text("until: \(shortDateFormatter.string(from: boardingEndDate))")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    Spacer()
                    
                    // Departure actions for departed dogs
                    if !dog.isCurrentlyPresent && dog.departureDate != nil {
                        HStack(spacing: 12) {
                            // For departed dogs, show total stay time and undo button
                            HStack(spacing: 8) {
                                Text(dog.formattedStayDuration)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Button {
                                    showingUndoAlert = true
                                } label: {
                                    Image(systemName: "arrow.uturn.backward.circle")
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .onTapGesture {
                                    // Prevent navigation
                                }
                            }
                            
                            Button {
                                newDepartureDate = dog.departureDate ?? Date()
                                showingEditDeparture = true
                            } label: {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onTapGesture {
                                // Prevent navigation
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .alert("Undo Departure", isPresented: $showingUndoAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Undo", role: .destructive) {
                Task {
                    await undoDeparture()
                }
            }
        } message: {
            Text("Are you sure you want to undo the departure for \(dog.name)?")
        }
        .sheet(isPresented: $showingEditDeparture) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Edit Departure Time")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("Set departure time for \(dog.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    DatePicker("Departure Time", selection: $newDepartureDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                    
                    Spacer()
                }
                .padding()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingEditDeparture = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                await updateDepartureTime()
                            }
                            showingEditDeparture = false
                        }
                    }
                }
            }
        }
        .contextMenu {
            Button("Delete", role: .destructive) {
                showingDeleteAlert = true
            }
        }
        .alert("Delete Dog", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await dataManager.deleteDog(dog)
                }
            }
        } message: {
            Text("Are you sure you want to delete \(dog.name)? This action cannot be undone.")
        }
    }
    
    private func undoDeparture() async {
        var updatedDog = dog
        updatedDog.departureDate = nil
        updatedDog.updatedAt = Date()
        await dataManager.updateDog(updatedDog)
    }
    
    private func updateDepartureTime() async {
        var updatedDog = dog
        updatedDog.departureDate = newDepartureDate
        updatedDog.updatedAt = Date()
        await dataManager.updateDog(updatedDog)
    }
} 