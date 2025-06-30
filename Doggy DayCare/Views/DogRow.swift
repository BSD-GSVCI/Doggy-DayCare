import SwiftUI

struct DogRow: View {
    let dog: Dog
    @EnvironmentObject var dataManager: DataManager
    @State private var showingDetail = false
    @State private var showingDeleteAlert = false
    @State private var showingUndoAlert = false
    @State private var showingEditDeparture = false
    @State private var showingSetArrivalTime = false
    @State private var newDepartureDate = Date()
    @State private var newArrivalTime = Date()
    
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
                            if dog.isArrivalTimeSet {
                                // Show date and time for dogs that have arrived
                                Text("\(shortDateFormatter.string(from: dog.arrivalDate)) \(shortTimeFormatter.string(from: dog.arrivalDate))")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                // Show only date for future bookings
                                Text("\(shortDateFormatter.string(from: dog.arrivalDate)) - No arrival time set")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            
                            if let departureDate = dog.departureDate {
                                Text("\(shortDateFormatter.string(from: departureDate)) \(shortTimeFormatter.string(from: departureDate))")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        
                        // Boarding departure date pill
                        if dog.isBoarding, let boardingEndDate = dog.boardingEndDate {
                            HStack(spacing: 4) {
                                Text("until: \(shortDateFormatter.string(from: boardingEndDate))")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                if dog.shouldBeTreatedAsDaycare && dog.departureDate == nil {
                                    Text("– is leaving today")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                } else if dog.shouldBeTreatedAsDaycare && dog.departureDate != nil {
                                    Text("– already left")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
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
            // Add Set Arrival Time option for dogs that have arrived but don't have arrival time set
            if Calendar.current.isDateInToday(dog.arrivalDate) && !dog.isArrivalTimeSet {
                Button {
                    newArrivalTime = Date()
                    showingSetArrivalTime = true
                } label: {
                    Label("Set Arrival Time", systemImage: "clock.badge.checkmark")
                }
            }
        }
        .sheet(isPresented: $showingSetArrivalTime) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Set Arrival Time")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("Set arrival time for \(dog.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    DatePicker("Arrival Time", selection: $newArrivalTime, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                    
                    Spacer()
                }
                .padding()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingSetArrivalTime = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Set Time") {
                            Task {
                                await setArrivalTime()
                            }
                            showingSetArrivalTime = false
                        }
                    }
                }
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
        await dataManager.undoDepartureOptimized(for: dog)
    }
    
    private func updateDepartureTime() async {
        await dataManager.editDepartureOptimized(for: dog, newDate: newDepartureDate)
    }
    
    private func setArrivalTime() async {
        await dataManager.setArrivalTimeOptimized(for: dog, newArrivalTime: newArrivalTime)
    }
} 