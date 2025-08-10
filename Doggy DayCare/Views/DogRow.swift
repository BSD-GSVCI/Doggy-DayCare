import SwiftUI

struct DogRow: View {
    let dog: DogWithVisit
    @Binding var selectedDogForOverlay: DogWithVisit?
    @EnvironmentObject var dataManager: DataManager
    @State private var showingDetail = false
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
                    // Profile picture with local overlay
                    LocalDogProfilePicture(dog: dog, size: 50, selectedDogForOverlay: $selectedDogForOverlay)
                        .padding(.trailing, 8)
                    
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
                            
                            if !dog.medications.isEmpty {
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
                        
                        // Expired vaccinations warning
                        let expiredVaccinations = dog.vaccinations.filter { vaccination in
                            if let endDate = vaccination.endDate {
                                return Calendar.current.startOfDay(for: endDate) <= Calendar.current.startOfDay(for: Date())
                            }
                            return false
                        }
                        
                        if !expiredVaccinations.isEmpty {
                            ForEach(expiredVaccinations, id: \.name) { vaccination in
                                Text("- \(vaccination.name) vaccination expired")
                                    .font(.caption)
                                    .fontWeight(.bold)
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
        .background(
            { () -> Color in
                let soonestVaxDate = dog.vaccinations.compactMap { $0.endDate }.min()
                if let soonest = soonestVaxDate, Calendar.current.startOfDay(for: soonest) <= Calendar.current.startOfDay(for: Date()) {
                    return Color.yellow.opacity(0.3)
                } else {
                    return Color.clear
                }
            }()
        )
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

// MARK: - Local Dog Profile Picture (Independent Overlay)
struct LocalDogProfilePicture: View {
    let dog: DogWithVisit
    let size: CGFloat
    @Binding var selectedDogForOverlay: DogWithVisit?
    
    var body: some View {
        Group {
            if let profilePictureData = dog.profilePictureData,
               let uiImage = UIImage(data: profilePictureData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .onTapGesture {
                        selectedDogForOverlay = dog
                    }
            } else {
                // Default dog icon
                Image(systemName: "pawprint.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .foregroundStyle(.gray)
            }
        }
    }
} 