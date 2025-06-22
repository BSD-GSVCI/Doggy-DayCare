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
    @State private var showingShareSheet = false
    @State private var showingLogoutConfirmation = false
    @State private var exportURL: URL?
    @State private var searchText = ""
    @State private var selectedFilter: DogFilter = .all
    
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
                                do {
                                    exportURL = try await BackupService.shared.exportDogs(dataManager.dogs)
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
                            .listRowBackground(Color.clear)
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
                            .listRowBackground(Color.clear)
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

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
        .environmentObject(DataManager.shared)
}
