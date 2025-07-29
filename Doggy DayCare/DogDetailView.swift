import SwiftUI

struct DogDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    let dog: Dog
    @State private var showingEditSheet = false
    @State private var showingCheckOutAlert = false
    @State private var showingBoardSheet = false
    @State private var showingExtendStaySheet = false
    @State private var showingDeleteAlert = false
    @State private var showingSetArrivalTimeSheet = false
    @State private var boardingEndDate = Date()
    @State private var newArrivalTime = Date()
    @State private var showingImageZoom = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy"
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        List {
            // Profile Picture Section
            Section {
                VStack(spacing: 12) {
                    HStack {
                        Spacer()
                        
                        if let imageData = dog.profilePictureData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                                .onTapGesture {
                                    showingImageZoom = true
                                }
                        } else {
                            Image(systemName: "camera.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    
                    Text(dog.name)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.vertical, 8)
            }
            
            // Basic Information Section
            Section("Basic Information") {
                InfoRow(title: "Stay Type", value: dog.isBoarding ? "Boarding" : "Daycare")
                InfoRow(title: "Feeding Type", value: dog.isDaycareFed ? "Daycare Fed" : "Own Food")
                
                InfoRow(title: "Arrival Date", value: dateFormatter.string(from: dog.arrivalDate))
                
                if let departureDate = dog.departureDate {
                    InfoRow(title: "Departure Date", value: dateFormatter.string(from: departureDate))
                }
                
                if let boardingEndDate = dog.boardingEndDate {
                    InfoRow(title: "Boarding End Date", value: dateFormatter.string(from: boardingEndDate))
                }
                
                InfoRow(title: "Stay Duration", value: dog.formattedStayDuration)
            }
            
            // Action Buttons Section (only for present dogs)
            if dog.isCurrentlyPresent {
                Section {
                    // Set Arrival Time button for dogs that have arrived but don't have arrival time set
                    if Calendar.current.isDateInToday(dog.arrivalDate) && !dog.isArrivalTimeSet {
                        Button {
                            newArrivalTime = Date()
                            showingSetArrivalTimeSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "clock.badge.checkmark")
                                    .foregroundStyle(.green)
                                Text("Set Arrival Time")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    
                    // Board button for daycare dogs
                    if !dog.isBoarding {
                        Button {
                            boardingEndDate = dog.boardingEndDate ?? Date()
                            showingBoardSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "house.fill")
                                    .foregroundStyle(.blue)
                                Text("Board")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    
                    // Extend Stay button for boarding dogs
                    if dog.isBoarding {
                        Button {
                            boardingEndDate = dog.boardingEndDate ?? Date()
                            showingExtendStaySheet = true
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                    .foregroundStyle(.blue)
                                Text("Extend Stay")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    
                    // Check Out button
                    Button {
                        showingCheckOutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Check Out")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            
            // Miscellaneous Information Section (moved here)
            if dog.isCurrentlyPresent {
                Section {
                    // ... action buttons ...
                }
            }
            
            Section("Miscellaneous Information") {
                if let age = dog.age {
                    InfoRow(title: "Age", value: String(age))
                }
                if let gender = dog.gender {
                    InfoRow(title: "Gender", value: gender.displayName)
                }
                if let isNeuteredOrSpayed = dog.isNeuteredOrSpayed {
                    InfoRow(title: "Neutered/Spayed", value: isNeuteredOrSpayed ? "Yes" : "No")
                }
                if let ownerName = dog.ownerName, !ownerName.isEmpty {
                    InfoRow(title: "Owner Name", value: ownerName)
                }
                if let ownerPhoneNumber = dog.ownerPhoneNumber, !ownerPhoneNumber.isEmpty {
                    InfoRow(title: "Owner's Phone Number", value: ownerPhoneNumber)
                }
            }
            Section("Vaccinations") {
                let vaxNames = ["Bordetella", "DHPP", "Rabies", "CIV", "Leptospirosis"]
                ForEach(vaxNames, id: \.self) { vaxName in
                    if let vax = dog.vaccinations.first(where: { $0.name == vaxName }) {
                        if let endDate = vax.endDate {
                            InfoRow(title: "\(vaxName) End Date", value: dateFormatter.string(from: endDate))
                        } else {
                            InfoRow(title: "\(vaxName) End Date", value: "Not set")
                        }
                    } else {
                        InfoRow(title: "\(vaxName) End Date", value: "Not set")
                    }
                }
            }
            
            // Reorder: Notes, Medications, Allergies, Feeding
            if let notes = dog.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .font(.body)
                }
            }
            if !dog.medications.isEmpty || !dog.medicationRecords.isEmpty {
                Section("Medications") {
                    // Show daily medications
                    ForEach(dog.medications.filter { $0.type == .daily }) { medication in
                        HStack {
                            Image(systemName: "pills.fill")
                                .foregroundStyle(.purple)
                            Text(medication.name)
                                .font(.subheadline)
                            if let notes = medication.notes, !notes.isEmpty {
                                Text("📝")
                                    .font(.caption)
                            }
                            Spacer()
                            Text("Daily")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Show scheduled medications that have been actually scheduled
                    ForEach(dog.scheduledMedications) { scheduledMedication in
                        if let medication = dog.medications.first(where: { $0.id == scheduledMedication.medicationId }) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading) {
                                    Text(medication.name)
                                        .font(.subheadline)
                                    Text("Scheduled for \(scheduledMedication.scheduledDate.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let notes = scheduledMedication.notes, !notes.isEmpty {
                                    Text("📝")
                                        .font(.caption)
                                }
                                Spacer()
                                Text(scheduledMedication.status.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if !dog.medicationRecords.isEmpty {
                        let sortedMedicationRecords = dog.medicationRecords.sorted(by: { $0.timestamp > $1.timestamp })
                        ForEach(sortedMedicationRecords, id: \ .id) { record in
                            HStack {
                                Image(systemName: "pills")
                                    .foregroundStyle(.purple)
                                VStack(alignment: .leading) {
                                    if let notes = record.notes {
                                        Text(notes)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            if let allergiesAndFeedingInstructions = dog.allergiesAndFeedingInstructions, !allergiesAndFeedingInstructions.isEmpty {
                Section("Allergies & Feeding Instructions") {
                    Text(allergiesAndFeedingInstructions)
                        .font(.body)
                }
            }
            if dog.isDaycareFed || !dog.feedingRecords.isEmpty {
                Section("Feeding Information") {
                    if !dog.feedingRecords.isEmpty {
                        let sortedFeedingRecords = dog.feedingRecords.sorted(by: { $0.timestamp > $1.timestamp })
                        ForEach(sortedFeedingRecords, id: \.id) { record in
                            HStack {
                                Image(systemName: iconForFeedingType(record.type))
                                    .foregroundStyle(colorForFeedingType(record.type))
                                VStack(alignment: .leading) {
                                    Text(record.type.rawValue.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let notes = record.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // Feeding counts
                    HStack(spacing: 16) {
                        HStack {
                            Image(systemName: "moon.stars.fill")
                                .foregroundStyle(.purple)
                                .font(.system(size: 15))
                            Text("\(dog.dinnerCount)")
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }
                        
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .foregroundStyle(.yellow)
                                .font(.system(size: 15))
                            Text("\(dog.lunchCount)")
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }
                        
                        HStack {
                            Image(systemName: "carrot.fill")
                                .foregroundStyle(.orange)
                                .font(.system(size: 15))
                            Text("\(dog.snackCount)")
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }
                        
                        HStack {
                            Image(systemName: "cup.and.saucer.fill")
                                .foregroundStyle(.brown)
                                .font(.system(size: 15))
                            Text("\(dog.breakfastCount)")
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }
                        
                        Spacer()
                    }
                    .font(.caption)
                }
            }
            
            // Walking Notes Section
            if let walkingNotes = dog.walkingNotes, !walkingNotes.isEmpty {
                Section("Walking Notes") {
                    Text(walkingNotes)
                        .font(.body)
                }
            }
            
            // Potty Records Section
            if dog.needsWalking || !dog.pottyRecords.isEmpty {
                if !dog.pottyRecords.isEmpty {
                    Section("Potty Records") {
                        let sortedPottyRecords = dog.pottyRecords.sorted(by: { $0.timestamp > $1.timestamp })
                        ForEach(sortedPottyRecords, id: \.id) { record in
                            HStack {
                                if record.type == .pee {
                                    Image(systemName: "drop.fill")
                                        .foregroundStyle(.yellow)
                                    Text("Pee")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else if record.type == .poop {
                                    Text("💩")
                                    Text("Poop")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else if record.type == .both {
                                    HStack(spacing: 2) {
                                        Image(systemName: "drop.fill")
                                            .foregroundStyle(.yellow)
                                        Text("💩")
                                    }
                                    Text("Both")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else if record.type == .nothing {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                    Text("Nothing")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                VStack(alignment: .leading) {
                                    if let notes = record.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Potty counts - Total for entire stay
                        HStack(spacing: 16) {
                            let totalPeeCount = dog.pottyRecords.filter { $0.type == .pee || $0.type == .both }.count
                            let totalPoopCount = dog.pottyRecords.filter { $0.type == .poop || $0.type == .both }.count
                            
                            // Debug: Print the counts
                            let _ = print("🐕 Total potty counts for \(dog.name): pee=\(totalPeeCount), poop=\(totalPoopCount), total records=\(dog.pottyRecords.count)")
                            
                            HStack {
                                Image(systemName: "drop.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.system(size: 15))
                                Text("\(totalPeeCount)")
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                            }
                            
                            HStack {
                                Text("💩")
                                    .font(.system(size: 15))
                                Text("\(totalPoopCount)")
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                            }
                            
                            Spacer()
                        }
                        .font(.caption)
                    }
                }
            }
            
            // Danger Zone Section
            Section {
                Button("Delete Dog") {
                    showingDeleteAlert = true
                }
                .foregroundStyle(.red)
            } header: {
                Text("Danger Zone")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                DogFormView(dog: dog)
            }
        }
        .sheet(isPresented: $showingBoardSheet) {
            NavigationStack {
                BoardDogView(dog: dog, endDate: $boardingEndDate)
            }
        }
        .sheet(isPresented: $showingExtendStaySheet) {
            NavigationStack {
                ExtendStayView(dog: dog, endDate: $boardingEndDate)
            }
        }
        .sheet(isPresented: $showingSetArrivalTimeSheet) {
            NavigationStack {
                SetArrivalTimeView(dog: dog, newArrivalTime: $newArrivalTime)
            }
        }
        .overlay {
            if showingImageZoom, let imageData = dog.profilePictureData, let uiImage = UIImage(data: imageData) {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingImageZoom = false
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
                                showingImageZoom = false
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
        .alert("Check Out", isPresented: $showingCheckOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Check Out", role: .destructive) {
                Task {
                    await checkOut()
                }
            }
        } message: {
            Text("Are you sure you want to check out \(dog.name)?")
        }
        .alert("Delete Dog", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteDog()
                }
            }
        } message: {
            Text("Are you sure you want to delete \(dog.name)? This action cannot be undone.")
        }
    }
    
    // MARK: - Action Functions
    
    private func checkOut() async {
        print("🔄 Starting checkout process for dog: \(dog.name)")
        print("📅 Current departure date: \(dog.departureDate?.description ?? "nil")")
        
        // Update local cache and dismiss immediately for responsive UI
        await dataManager.checkoutDog(dog)
        
        print("✅ Checkout completed for dog: \(dog.name)")
        
        // Dismiss immediately after local cache update
        dismiss()
    }
    
    private func deleteDog() async {
        await dataManager.deleteDog(dog)
        dismiss()
    }
    
    private func iconForFeedingType(_ type: FeedingRecord.FeedingType) -> String {
        switch type {
        case .breakfast: return "cup.and.saucer.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "carrot.fill"
        }
    }
    
    private func colorForFeedingType(_ type: FeedingRecord.FeedingType) -> Color {
        switch type {
        case .breakfast: return .brown
        case .lunch: return .yellow
        case .dinner: return .purple
        case .snack: return .orange
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct StatusBadge: View {
    let title: String
    let color: Color
    
    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct BoardDogView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    let dog: Dog
    @Binding var endDate: Date
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Dog: \(dog.name)")
                        .font(.headline)
                    
                    Text("Currently: Daycare")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Section("Boarding End Date") {
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Convert to Boarding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Convert") {
                        Task {
                            await convertToBoarding()
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .overlay {
                if isLoading {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Converting...")
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                }
            }
        }
    }
    
    private func convertToBoarding() async {
        isLoading = true
        await dataManager.boardDogOptimized(dog, endDate: endDate)
        isLoading = false
        dismiss()
    }
}

struct ExtendStayView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    let dog: Dog
    @Binding var endDate: Date
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Dog: \(dog.name)")
                        .font(.headline)
                    
                    if let currentEndDate = dog.boardingEndDate {
                        Text("Current end date: \(currentEndDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("New End Date") {
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Extend Stay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Extend") {
                        Task {
                            await extendStay()
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .overlay {
                if isLoading {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Extending...")
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                }
            }
        }
    }
    
    private func extendStay() async {
        isLoading = true
        await dataManager.extendBoardingOptimized(for: dog, newEndDate: endDate)
        isLoading = false
        dismiss()
    }
}

struct SetArrivalTimeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager
    let dog: Dog
    @Binding var newArrivalTime: Date
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Dog: \(dog.name)")
                        .font(.headline)
                    
                    Text("Set the actual arrival time for today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Section("Arrival Time") {
                    DatePicker("Arrival Time", selection: $newArrivalTime, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
            }
            .navigationTitle("Set Arrival Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set Time") {
                        Task {
                            await setArrivalTime()
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .overlay {
                if isLoading {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Setting arrival time...")
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                }
            }
        }
    }
    
    private func setArrivalTime() async {
        isLoading = true
        await dataManager.setArrivalTimeOptimized(for: dog, newArrivalTime: newArrivalTime)
        isLoading = false
        dismiss()
    }
}

#Preview {
    let sampleDog = Dog(
        name: "Buddy",
        ownerName: "John Doe",
        arrivalDate: Date(),
        isBoarding: false,
        allergiesAndFeedingInstructions: "No chicken",
        needsWalking: true,
        walkingNotes: "Likes to chase squirrels",
        isDaycareFed: true,
        notes: "Very friendly dog"
    )
    
    NavigationStack {
        DogDetailView(dog: sampleDog)
    }
} 