//
//  ContentView.swift
//  Doggy DayCare
//
//  Created by Behnam Soleimani Darinsoo on 6/10/25.
//

import SwiftUI
import SwiftData

// Debug extension to help us understand toolbar content types
extension View {
    func debugToolbarType<T: ToolbarContent>(_ content: T) -> some View {
        print("Toolbar content type: \(type(of: content))")
        return self.toolbar { content }
    }
}

struct CustomNavigationBar: View {
    @Binding var showingAddDog: Bool
    @Binding var showingExportData: Bool
    @Binding var showingStaffManagement: Bool
    @Binding var showingLogoutConfirmation: Bool
    @ObservedObject var authService: AuthenticationService
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Dogs")
                    .font(.headline)
                Spacer()
                HStack(spacing: 12) {
                    NavigationLink(destination: WalkingListView()) {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(.blue)
                    }
                    
                    NavigationLink(destination: FeedingListView()) {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(.blue)
                    }
                    
                    NavigationLink(destination: MedicationsListView()) {
                        Image(systemName: "pills")
                            .foregroundStyle(.blue)
                    }
                    
                    NavigationLink(destination: FutureBookingsView()) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.blue)
                    }
                    
                    Button {
                        showingAddDog = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                    
                    Menu {
                        if authService.currentUser?.isOwner == true {
                            Button {
                                showingStaffManagement = true
                            } label: {
                                Label("Staff Management", systemImage: "person.2")
                            }
                            
                            Button {
                                showingExportData = true
                            } label: {
                                Label("Export Data Manually", systemImage: "square.and.arrow.up")
                            }
                        }
                        
                        Button(role: .destructive) {
                            showingLogoutConfirmation = true
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            Divider()
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = AuthenticationService.shared
    @Query private var dogs: [Dog]
    @State private var searchText = ""
    @State private var showingAddDog = false
    @State private var showingStaffManagement = false
    @State private var showingLogoutConfirmation = false
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    
    private var filteredDogs: [Dog] {
        if searchText.isEmpty {
            return dogs
        } else {
            return dogs.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var daycareDogs: [Dog] {
        filteredDogs.filter { dog in
            let isPresent = dog.isCurrentlyPresent
            let isArrivingToday = Calendar.current.isDateInToday(dog.arrivalDate)
            let hasArrived = Calendar.current.dateComponents([.hour, .minute], from: dog.arrivalDate).hour != 0 ||
                            Calendar.current.dateComponents([.hour, .minute], from: dog.arrivalDate).minute != 0
            let isFutureBooking = Calendar.current.startOfDay(for: dog.arrivalDate) > Calendar.current.startOfDay(for: Date())
            
            return !dog.isBoarding && (isPresent || (isArrivingToday && !hasArrived)) && !isFutureBooking
        }
    }
    
    private var boardingDogs: [Dog] {
        filteredDogs.filter { dog in
            let isPresent = dog.isCurrentlyPresent
            let isArrivingToday = Calendar.current.isDateInToday(dog.arrivalDate)
            let hasArrived = Calendar.current.dateComponents([.hour, .minute], from: dog.arrivalDate).hour != 0 ||
                            Calendar.current.dateComponents([.hour, .minute], from: dog.arrivalDate).minute != 0
            let isFutureBooking = Calendar.current.startOfDay(for: dog.arrivalDate) > Calendar.current.startOfDay(for: Date())
            
            return dog.isBoarding && (isPresent || (isArrivingToday && !hasArrived)) && !isFutureBooking
        }
    }
    
    private var departedDogs: [Dog] {
        filteredDogs.filter { $0.departureDate != nil && Calendar.current.isDateInToday($0.departureDate!) }
    }
    
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
        if authService.currentUser == nil {
            LoginView()
        } else {
            NavigationStack {
            DogsListView(
                daycareDogs: daycareDogs,
                boardingDogs: boardingDogs,
                departedDogs: departedDogs
            )
        .searchable(text: $searchText, prompt: "Search dogs by name")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingAddDog = true
                } label: {
                    Image(systemName: "plus")
                                .foregroundStyle(.blue)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 12) {
                            NavigationLink(destination: WalkingListView()) {
                                Image(systemName: "figure.walk")
                                    .foregroundStyle(.blue)
                            }
                            
                            NavigationLink(destination: FeedingListView()) {
                                Image(systemName: "fork.knife")
                                    .foregroundStyle(.blue)
                            }
                            
                            NavigationLink(destination: MedicationsListView()) {
                                Image(systemName: "pills")
                                    .foregroundStyle(.blue)
                            }
                            
                            NavigationLink(destination: FutureBookingsView()) {
                                Image(systemName: "calendar")
                                    .foregroundStyle(.blue)
                            }
                            
                            if authService.currentUser?.isOwner == true {
                                Button {
                                    showingStaffManagement = true
                                } label: {
                                    Image(systemName: "person.2")
                                        .foregroundStyle(.blue)
                                }
                            }
                            
                            Button {
                                Task {
                                    do {
                                        exportURL = try await BackupService.shared.exportDogs(filteredDogs)
                                        showingShareSheet = true
                                    } catch {
                                        print("Export error: \(error)")
                                    }
                                }
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(.blue)
    }
    
                            Button {
                                showingLogoutConfirmation = true
                            } label: {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingAddDog) {
                    NavigationStack {
                        DogFormView()
                    }
                }
                .sheet(isPresented: $showingStaffManagement) {
                    NavigationStack {
                        StaffManagementView()
                    }
                }
                .sheet(isPresented: $showingShareSheet) {
                    if let url = exportURL {
                        ShareSheet(activityItems: [url])
                    }
                }
                .alert("Sign Out", isPresented: $showingLogoutConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Sign Out", role: .destructive) {
                        authService.signOut()
                    }
                } message: {
                    Text("Are you sure you want to sign out?")
                }
            }
        }
    }
}

// MARK: - User Info View
private struct UserInfoView: View {
    let user: User?
    
    var body: some View {
        if let user = user {
            VStack(spacing: 4) {
                Text("Logged in as: \(user.name) (\(user.isOwner ? "Owner" : "Staff"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if !user.isOwner {
                    if user.canWorkToday {
                        Text("Working today")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("Not scheduled to work today")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.top)
        }
    }
}

// MARK: - Dogs List View
private struct DogsListView: View {
    let daycareDogs: [Dog]
    let boardingDogs: [Dog]
    let departedDogs: [Dog]
    
    var body: some View {
        List {
            Section {
                if daycareDogs.isEmpty {
                    Text("No daycare dogs present")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(daycareDogs) { dog in
                        DogRow(dog: dog)
                    }
                }
            } header: {
                Text("Daycare")
            }
            .listSectionSpacing(20)
            
            Section {
                if boardingDogs.isEmpty {
                    Text("No boarding dogs present")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(boardingDogs) { dog in
                        DogRow(dog: dog)
                    }
                }
            } header: {
                Text("Boarding")
            }
            .listSectionSpacing(20)
            
            if !departedDogs.isEmpty {
                Section {
                    ForEach(departedDogs) { dog in
                        DogRow(dog: dog)
                    }
                } header: {
                    Text("Departed Today")
                }
            }
        }
    }
}

// MARK: - Dog Row View
private struct DogRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var dog: Dog
    @State private var showingDepartureSheet = false
    @State private var showingUndoConfirmation = false
    @State private var showingArrivalSheet = false
    @State private var arrivalTime = Date()
    
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
    
    private var hasArrived: Bool {
        let calendar = Calendar.current
        let arrivalComponents = calendar.dateComponents([.hour, .minute], from: dog.arrivalDate)
        return arrivalComponents.hour != 0 || arrivalComponents.minute != 0
    }
    
    private var needsArrivalTime: Bool {
        Calendar.current.isDateInToday(dog.arrivalDate) && !hasArrived
    }
    
    var body: some View {
        NavigationLink {
            DogDetailView(dog: dog)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dog.name)
                        .font(.headline)
                    if dog.needsWalking {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(.blue)
                    }
                    if dog.medications != nil && !dog.medications!.isEmpty {
                        Image(systemName: "pills")
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    if dog.departureDate != nil {
                        HStack(spacing: 8) {
                            Text(dog.formattedStayDuration)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Button {
                                showingDepartureSheet = true
                            } label: {
                                Image(systemName: "clock")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                showingUndoConfirmation = true
                            } label: {
                                Image(systemName: "arrow.uturn.backward.circle")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    } else if needsArrivalTime {
                        Button {
                            showingArrivalSheet = true
                        } label: {
                            Text("Set Arrival Time")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Show arrival time or "No arrival time set" message
                if hasArrived {
                    Text("\(shortDateFormatter.string(from: dog.arrivalDate)) at \(shortTimeFormatter.string(from: dog.arrivalDate))")
                        .font(.subheadline)
                        .foregroundStyle(.green.opacity(0.8))
                } else if Calendar.current.isDateInToday(dog.arrivalDate) {
                    Text("\(shortDateFormatter.string(from: dog.arrivalDate)) - No arrival time set")
                        .font(.subheadline)
                        .foregroundStyle(.red.opacity(0.8))
                } else {
                    Text("\(shortDateFormatter.string(from: dog.arrivalDate)) at \(shortTimeFormatter.string(from: dog.arrivalDate))")
                        .font(.subheadline)
                        .foregroundStyle(.green.opacity(0.8))
                }
                
                if let departureDate = dog.departureDate {
                    Text("\(shortDateFormatter.string(from: departureDate)) at \(shortTimeFormatter.string(from: departureDate))")
                        .font(.subheadline)
                        .foregroundStyle(.red.opacity(0.8))
                }
                
                HStack {
                    Text(dog.isBoarding ? "Boarding" : "Daycare")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(dog.isBoarding ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                        .clipShape(Capsule())
                    
                    if dog.isBoarding, let boardingEndDate = dog.boardingEndDate {
                        Text("Until \(shortDateFormatter.string(from: boardingEndDate))")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Capsule())
                            .onAppear {
                                print("Showing boarding end date for \(dog.name): \(boardingEndDate)")
                            }
                    } else if dog.isBoarding {
                        Text("No end date set")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .clipShape(Capsule())
                            .onAppear {
                                print("Dog \(dog.name) is boarding but has no end date set")
                            }
                    }
                    
                    if dog.isDaycareFed {
                        Text("Daycare Feeds")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(
            Calendar.current.isDateInToday(dog.arrivalDate) && !hasArrived ?
            Color.red :
            Color.clear
        )
        .alert("Undo Departure", isPresented: $showingUndoConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Undo", role: .destructive) {
                withAnimation {
                    dog.departureDate = nil
                    dog.updatedAt = Date()
                    try? modelContext.save()
                }
            }
        } message: {
            Text("Are you sure you want to undo \(dog.name)'s departure? This will move them back to the active dogs list.")
        }
        .sheet(isPresented: $showingDepartureSheet) {
            NavigationStack {
                Form {
                    Section {
                        DatePicker(
                            "Departure Time",
                            selection: Binding(
                                get: { dog.departureDate ?? Date() },
                                set: { newValue in
                                    // Keep the same date, only update the time
                                    let calendar = Calendar.current
                                    let currentDate = dog.departureDate ?? Date()
                                    let currentDateComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
                                    let newTimeComponents = calendar.dateComponents([.hour, .minute], from: newValue)
                                    
                                    var combinedComponents = DateComponents()
                                    combinedComponents.year = currentDateComponents.year
                                    combinedComponents.month = currentDateComponents.month
                                    combinedComponents.day = currentDateComponents.day
                                    combinedComponents.hour = newTimeComponents.hour
                                    combinedComponents.minute = newTimeComponents.minute
                                    
                                    if let updatedDate = calendar.date(from: combinedComponents) {
                                        dog.departureDate = updatedDate
                                    dog.updatedAt = Date()
                                    try? modelContext.save()
                                    }
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: dog.departureDate) { _, newValue in
                            // Keep the sheet open - don't auto-close
                        }
                    }
                }
                .navigationTitle("Edit Departure Time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingDepartureSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingDepartureSheet = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingArrivalSheet) {
            NavigationStack {
                Form {
                    DatePicker("Arrival Time", selection: $arrivalTime, displayedComponents: .hourAndMinute)
                }
                .navigationTitle("Set Arrival Time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingArrivalSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let calendar = Calendar.current
                            var components = calendar.dateComponents([.year, .month, .day], from: dog.arrivalDate)
                            let timeComponents = calendar.dateComponents([.hour, .minute], from: arrivalTime)
                            components.hour = timeComponents.hour
                            components.minute = timeComponents.minute
                            if let newDate = calendar.date(from: components) {
                                dog.arrivalDate = newDate
                                dog.updatedAt = Date()
                                try? modelContext.save()
                            }
                            showingArrivalSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.height(200)])
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Dog.self, User.self, configurations: config)
    
    // Set up authentication service
    let authService = AuthenticationService.shared
    authService.setModelContext(container.mainContext)
    
    return ContentView()
        .modelContainer(container)
}
