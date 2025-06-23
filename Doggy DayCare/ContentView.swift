//
//  ContentView.swift
//  Doggy DayCare
//
//  Created by Behnam Soleimani Darinsoo on 6/10/25.
//

import SwiftUI

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
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var authService = AuthenticationService.shared
    @State private var showingAddDog = false
    @State private var showingStaffManagement = false
    @State private var showingLogoutConfirmation = false
    @State private var searchText = ""
    @State private var selectedFilter: DogFilter = .all
    
    enum ExportState {
        case idle
        case alertShown
        case sheetPending
        case sheetShown
    }
    
    @State private var exportState: ExportState = .idle
    @State private var exportURL: URL?
    @State private var isExportReady = false
    
    enum DogFilter {
        case all
        case daycare
        case boarding
        case departed
    }
    
    private var filteredDogs: [Dog] {
        let dogs = dataManager.dogs
        
        let filtered = dogs.filter { dog in
            if !searchText.isEmpty {
                return dog.name.localizedCaseInsensitiveContains(searchText)
            }
            return true
        }
        
        switch selectedFilter {
        case .all:
            return filtered
        case .daycare:
            return filtered.filter { $0.isCurrentlyPresent && !$0.isBoarding }
        case .boarding:
            return filtered.filter { $0.isCurrentlyPresent && $0.isBoarding }
        case .departed:
            return filtered.filter { $0.departureDate != nil && Calendar.current.isDateInToday($0.departureDate!) }
        }
    }
    
    private var daycareDogs: [Dog] {
        filteredDogs.filter { $0.isCurrentlyPresent && !$0.isBoarding }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var boardingDogs: [Dog] {
        filteredDogs.filter { $0.isCurrentlyPresent && $0.isBoarding }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var departedDogs: [Dog] {
        filteredDogs.filter { $0.departureDate != nil && Calendar.current.isDateInToday($0.departureDate!) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var visibleDogs: [Dog] {
        // Combine all dogs that are actually visible on the main page
        return daycareDogs + boardingDogs + departedDogs
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
        NavigationStack {
            VStack(spacing: 0) {
                // User info at the top
                UserInfoView(user: authService.currentUser)
                
                // Filter buttons
                HStack(spacing: 12) {
                    ContentFilterButton(title: "All", isSelected: selectedFilter == .all) {
                        selectedFilter = .all
                    }
                    
                    ContentFilterButton(title: "Daycare", isSelected: selectedFilter == .daycare) {
                        selectedFilter = .daycare
                    }
                    
                    ContentFilterButton(title: "Boarding", isSelected: selectedFilter == .boarding) {
                        selectedFilter = .boarding
                    }
                    
                    ContentFilterButton(title: "Departed", isSelected: selectedFilter == .departed) {
                        selectedFilter = .departed
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Dogs list
                DogsListView(
                    daycareDogs: daycareDogs,
                    boardingDogs: boardingDogs,
                    departedDogs: departedDogs
                )
            }
            .searchable(text: $searchText, prompt: "Search dogs by name")
            .navigationBarTitleDisplayMode(.inline)
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
                                await MainActor.run {
                                    exportState = .alertShown
                                    print("🔄 Export started - alert shown")
                                }
                                
                                // Record start time for minimum display duration
                                let startTime = Date()
                                
                                do {
                                    print("Starting export...")
                                    print("Visible dogs count: \(visibleDogs.count)")
                                    let url = try await BackupService.shared.exportDogs(visibleDogs)
                                    print("Export completed, URL: \(url.absoluteString)")
                                    
                                    // Calculate how long the export took
                                    let exportDuration = Date().timeIntervalSince(startTime)
                                    let minimumDisplayTime: TimeInterval = 1.0 // 1 second minimum
                                    
                                    // If export was faster than minimum, wait for the remainder
                                    if exportDuration < minimumDisplayTime {
                                        let remainingTime = minimumDisplayTime - exportDuration
                                        try await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
                                    }
                                    
                                    await MainActor.run {
                                        exportURL = url
                                        isExportReady = true
                                        exportState = .sheetPending
                                        print("Export ready, transitioning to sheet")
                                    }
                                    
                                    await MainActor.run {
                                        exportState = .sheetShown
                                        print("Sheet should now be visible")
                                    }
                                } catch {
                                    await MainActor.run {
                                        exportState = .idle
                                        print("❌ Export failed - back to idle")
                                    }
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
            .sheet(isPresented: Binding(
                get: { exportState == .sheetShown },
                set: { newValue in
                    if newValue && exportState == .sheetPending {
                        exportState = .sheetShown
                    } else if !newValue && exportState == .sheetShown {
                        exportState = .idle
                        isExportReady = false
                        exportURL = nil
                    }
                }
            )) {
                ExportSheet(url: $exportURL, isReady: $isExportReady)
            }
            .alert("Sign Out", isPresented: $showingLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authService.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .overlay {
                if exportState == .alertShown {
                    ExportingOverlay()
                }
            }
        }
    }
}

// MARK: - Filter Button
private struct ContentFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
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
        List {
            if !daycareDogs.isEmpty {
                Section {
                    ForEach(daycareDogs) { dog in
                        DogRow(dog: dog)
                            .listRowBackground(
                                Calendar.current.isDateInToday(dog.arrivalDate) && !dog.isArrivalTimeSet ? 
                                Color.red.opacity(0.1) : Color.clear
                            )
                    }
                } header: {
                    Text("DAYCARE \(daycareDogs.count)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
                .listSectionSpacing(80)
            }
            
            if !boardingDogs.isEmpty {
                Section {
                    ForEach(boardingDogs) { dog in
                        DogRow(dog: dog)
                            .listRowBackground(
                                Calendar.current.isDateInToday(dog.arrivalDate) && !dog.isArrivalTimeSet ? 
                                Color.red.opacity(0.1) : Color.clear
                            )
                    }
                } header: {
                    Text("BOARDING \(boardingDogs.count)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
                .listSectionSpacing(80)
            }
            
            if !departedDogs.isEmpty {
                Section {
                    ForEach(departedDogs) { dog in
                        DogRow(dog: dog)
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("DEPARTED TODAY \(departedDogs.count)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
            }
        }
    }
}

// MARK: - Export Sheet
private struct ExportSheet: View {
    @Binding var url: URL?
    @Binding var isReady: Bool
    
    var body: some View {
        VStack {
            if let url = url {
                Text("Export Ready!")
                    .font(.headline)
                    .padding()
                
                Text("File: \(url.lastPathComponent)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("URL: \(url.absoluteString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
                
                ShareSheet(activityItems: [url])
                    .presentationDetents([.medium, .large])
            } else {
                Text("Export failed - no file to share")
                    .padding()
                
                Text("URL is nil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("isReady: \(isReady)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        
        // Configure for better file sharing
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks,
            .markupAsPDF,
            .saveToCameraRoll,
            .postToFacebook,
            .postToTwitter,
            .postToWeibo,
            .postToVimeo,
            .postToTencentWeibo,
            .postToFlickr
        ]
        
        // Set completion handler to log any issues
        controller.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
            if let error = error {
                print("❌ ShareSheet error: \(error)")
            } else if completed {
                print("✅ ShareSheet completed successfully")
            } else {
                print("⚠️ ShareSheet was cancelled")
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Exporting Overlay
struct ExportingOverlay: View {
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // Loading content
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .foregroundStyle(.white)
                
                Text("Exporting...")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("Please wait while we prepare your export file")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.8))
            )
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataManager.shared)
}
