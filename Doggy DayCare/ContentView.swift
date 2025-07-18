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
    @State private var showingLogoutConfirmation = false
    @State private var showingHistoryView = false
    @State private var showingStaffManagement = false
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
    @State private var backupFolderURL: URL?
    @State private var showingFolderPicker = false
    
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
            return filtered.filter { $0.isCurrentlyPresent && $0.shouldBeTreatedAsDaycare }
        case .boarding:
            return filtered.filter { $0.isCurrentlyPresent && !$0.shouldBeTreatedAsDaycare }
        case .departed:
            return filtered.filter { $0.departureDate != nil && Calendar.current.isDateInToday($0.departureDate!) }
        }
    }
    
    private var daycareDogs: [Dog] {
        filteredDogs.filter { $0.isCurrentlyPresent && $0.shouldBeTreatedAsDaycare }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var boardingDogs: [Dog] {
        filteredDogs.filter { $0.isCurrentlyPresent && !$0.shouldBeTreatedAsDaycare }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var departedDogs: [Dog] {
        filteredDogs.filter { $0.departureDate != nil && Calendar.current.isDateInToday($0.departureDate!) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    // Add this property to always show the correct count
    private var currentlyPresentCount: Int {
        dataManager.dogs.filter { $0.isCurrentlyPresent }.count
    }
    
    private func loadBackupFolderBookmark() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "backup_folder_bookmark") else {
            print("No backup folder bookmark found")
            return
        }
        
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                print("⚠️ Backup folder bookmark is stale, removing...")
                UserDefaults.standard.removeObject(forKey: "backup_folder_bookmark")
                return
            }
            
            backupFolderURL = url
            print("✅ Backup folder loaded from bookmark: \(url.path)")
        } catch {
            print("❌ Failed to resolve backup folder bookmark: \(error)")
            UserDefaults.standard.removeObject(forKey: "backup_folder_bookmark")
        }
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
                
                // Show sync status
                SyncStatusView()
                    .padding(.bottom, 8)
                
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
                
                // Currently Present count - only show when "All" filter is active
                if selectedFilter == .all {
                    Text("Currently Present: \(currentlyPresentCount)")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                        .padding(.bottom, 4)
                }
                
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
                            NavigationLink(destination: DatabaseView()) {
                                Image(systemName: "externaldrive")
                                    .foregroundStyle(.blue)
                            }
                        }
                        
                        if authService.currentUser?.isOwner == true {
                            NavigationLink(destination: PaymentsView()) {
                                Image(systemName: "dollarsign")
                                    .foregroundStyle(.blue)
                            }
                        }
                        
                        Menu {
                            if authService.currentUser?.isOwner == true {
                                Button {
                                    showingFolderPicker = true
                                } label: {
                                    Label("Choose Backup Folder", systemImage: "folder")
                                }
                                
                                if backupFolderURL != nil {
                                    Button {
                                        backupFolderURL = nil
                                        UserDefaults.standard.removeObject(forKey: "backup_folder_bookmark")
                                    } label: {
                                        Label("Clear Backup Folder", systemImage: "folder.badge.minus")
                                    }
                                    
                                    Divider()
                                }
                                

                            }
                            
                            Button {
                                showingHistoryView = true
                            } label: {
                                Label("History", systemImage: "scroll")
                            }
                            
                            if authService.currentUser?.isOwner == true {
                                Button {
                                    showingStaffManagement = true
                                } label: {
                                    Label("Staff Management", systemImage: "person.2")
                                }
                                
                                Divider()
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
                                Label("Export Data", systemImage: "square.and.arrow.up")
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
            }
            .sheet(isPresented: $showingAddDog) {
                NavigationStack {
                    DogFormView(dog: nil, addToDatabaseOnly: false)
                }
            }
            .sheet(isPresented: $showingHistoryView) {
                NavigationStack {
                    HistoryView()
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
            .onAppear {
                loadBackupFolderBookmark()
            }
            .sheet(isPresented: $showingFolderPicker) {
                FolderPicker(selectedURL: $backupFolderURL)
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
                        Text("Currently scheduled for work")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        if let days = user.scheduledDays, !days.isEmpty {
                            let calendar = Calendar.current
                            let today = calendar.component(.weekday, from: Date())
                            if days.contains(today) {
                                Text("Outside working hours")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else {
                                Text("Not scheduled today")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        } else {
                            Text("No schedule set")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Dogs List View
private struct DogsListView: View {
    @EnvironmentObject var dataManager: DataManager
    let daycareDogs: [Dog]
    let boardingDogs: [Dog]
    let departedDogs: [Dog]
    @State private var selectedDogForOverlay: Dog?
    
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
                        DogRow(dog: dog, selectedDogForOverlay: $selectedDogForOverlay)
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
                        DogRow(dog: dog, selectedDogForOverlay: $selectedDogForOverlay)
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
                        DogRow(dog: dog, selectedDogForOverlay: $selectedDogForOverlay)
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
        .refreshable {
            await dataManager.refreshData()
        }
        .overlay {
            if let selectedDog = selectedDogForOverlay, let profilePictureData = selectedDog.profilePictureData, let uiImage = UIImage(data: profilePictureData) {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                    .onTapGesture {
                        selectedDogForOverlay = nil
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
                                selectedDogForOverlay = nil
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

// MARK: - Folder Picker
struct FolderPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FolderPicker
        
        init(_ parent: FolderPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Start accessing the security-scoped resource
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            
            if didStartAccessing {
                // Store the URL for future use
                parent.selectedURL = url
                
                // Save the bookmark data for persistent access
                do {
                    let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                    UserDefaults.standard.set(bookmarkData, forKey: "backup_folder_bookmark")
                    print("✅ Backup folder selected and bookmark saved: \(url.path)")
                } catch {
                    print("❌ Failed to save bookmark: \(error)")
                }
                
                // Stop accessing the security-scoped resource
                url.stopAccessingSecurityScopedResource()
            }
            
            parent.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
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
