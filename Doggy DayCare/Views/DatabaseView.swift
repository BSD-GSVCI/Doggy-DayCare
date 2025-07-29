import SwiftUI

struct DatabaseView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var authService = AuthenticationService.shared
    @State private var allDogs: [Dog] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var dogToDelete: Dog?
    @State private var showingEditDog = false
    @State private var dogToEdit: Dog?
    @State private var isLoadingEdit = false
    @State private var errorMessage: String?
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var showingAddDogSheet = false
    @State private var exportData: String = ""
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var dogVisitCounts: [String: Int] = [:]
    @State private var selectedDogForOverlay: Dog?
    
    private var filteredDogs: [Dog] {
        if searchText.isEmpty {
            return allDogs
        } else {
            return allDogs.filter { dog in
                dog.name.localizedCaseInsensitiveContains(searchText) ||
                (dog.ownerName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("Loading database...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        Text("Total Dogs: \(allDogs.count)")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                            .padding(.top, 4)
                            .padding(.bottom, 4)
                        
                        List {
                            ForEach(filteredDogs) { dog in
                            DatabaseDogRow(dog: dog, visitCount: dogVisitCounts[dog.id.uuidString] ?? 1, selectedDogForOverlay: $selectedDogForOverlay)
                                .contextMenu {
                                    Button {
                                        Task {
                                            await loadFullDogForEdit(dog)
                                        }
                                    } label: {
                                        Label("Edit Dog", systemImage: "pencil")
                                    }
                                    
                                    Button(role: .destructive) {
                                        // Prevent deletion of currently present dogs
                                        if dog.isCurrentlyPresent {
                                            errorMessage = "Cannot delete dogs that are currently present. Please check them out first."
                                        } else {
                                            dogToDelete = dog
                                            showingDeleteConfirmation = true
                                        }
                                    } label: {
                                        Label("Permanently Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .refreshable {
                        dataManager.forceRefreshDatabaseCache()
                        await loadAllDogs()
                    }
                }
                }
            }
            .navigationTitle("Database")
            .navigationBarTitleDisplayMode(.inline)
            
            .searchable(text: $searchText, prompt: "Search dogs by name or owner")
            .task {
                await loadAllDogs()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddDogSheet = true
                        } label: {
                            Label("Add Dog", systemImage: "plus")
                        }
                        
                        Button {
                            Task {
                                await exportDatabase()
                            }
                        } label: {
                            Label("Export Database", systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            showingImportSheet = true
                        } label: {
                            Label("Import Database", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .alert("Delete Dog", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Permanently Delete", role: .destructive) {
                    if let dog = dogToDelete {
                        Task {
                            await permanentlyDeleteDog(dog)
                        }
                    }
                }
            } message: {
                if let dog = dogToDelete {
                    Text("Are you sure you want to permanently delete '\(dog.name)' from the database? This action cannot be undone and will completely remove the dog from CloudKit.")
                }
            }
            .sheet(isPresented: $showingEditDog) {
                if let dog = dogToEdit {
                    NavigationStack {
                        DogFormView(dog: dog, addToDatabaseOnly: true)
                    }
                }
            }
            .overlay {
                if isLoadingEdit {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Loading dog information...")
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                }
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
            .sheet(isPresented: $showingExportSheet) {
                NavigationStack {
                    ExportDatabaseView(exportData: exportData)
                }
            }
            .sheet(isPresented: $showingImportSheet) {
                NavigationStack {
                    ImportDatabaseView { importedDogs in
                        Task {
                            await importDatabase(importedDogs)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddDogSheet) {
                NavigationStack {
                    DogFormView(dog: nil, addToDatabaseOnly: true)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private func loadAllDogs() async {
        isLoading = true
        errorMessage = nil
        
        let dogs = await dataManager.getAllDogsForDatabase()
        await MainActor.run {
            // Group dogs by name and owner (like the import functionality does)
            var dogGroups: [String: [Dog]] = [:]
            
            // Group all dogs by name and owner
            for dog in dogs {
                let key = "\(dog.name.lowercased())_\(dog.ownerName?.lowercased() ?? "")"
                if dogGroups[key] == nil {
                    dogGroups[key] = []
                }
                dogGroups[key]?.append(dog)
            }
            
            // For each group, keep only the most recent version and count visits
            var uniqueDogs: [Dog] = []
            var visitCounts: [String: Int] = [:]
            
            for (_, dogGroup) in dogGroups {
                if let mostRecentDog = dogGroup.max(by: { $0.arrivalDate < $1.arrivalDate }) {
                    uniqueDogs.append(mostRecentDog)
                    visitCounts[mostRecentDog.id.uuidString] = dogGroup.count
                }
            }
            
            self.allDogs = uniqueDogs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            self.isLoading = false
            print("✅ Loaded \(uniqueDogs.count) unique dogs from database (deduplicated from \(dogs.count) total records)")
            
            // Store visit counts for display
            self.dogVisitCounts = visitCounts
        }
    }
    
    private func permanentlyDeleteDog(_ dog: Dog) async {
        isLoading = true
        errorMessage = nil
        
        await dataManager.permanentlyDeleteDog(dog)
        
        await MainActor.run {
            // Remove from local array
            self.allDogs.removeAll { $0.id == dog.id }
            self.isLoading = false
            print("✅ Permanently deleted dog: \(dog.name)")
        }
    }
    
    private func loadFullDogForEdit(_ dog: Dog) async {
        print("🔍 Loading full dog information for editing: \(dog.name)")
        
        await MainActor.run {
            self.isLoadingEdit = true
        }
        
        // Fetch the complete dog with all records
        guard let fullDog = await dataManager.fetchSpecificDogWithRecords(for: dog.id.uuidString) else {
            print("❌ Failed to load full dog information for \(dog.name)")
            await MainActor.run {
                self.errorMessage = "Failed to load dog information"
                self.isLoadingEdit = false
            }
            return
        }
        
        await MainActor.run {
            self.dogToEdit = fullDog
            self.isLoadingEdit = false
            self.showingEditDog = true
            print("✅ Loaded full dog information for editing: \(fullDog.name)")
        }
    }
    
    private func exportDatabase() async {
        isExporting = true
        errorMessage = nil
        
        do {
            // Get all dogs from the database
            let allDogs = await dataManager.getAllDogsForDatabase()
            
            // Create export data
            let exportData = try JSONEncoder().encode(allDogs)
            let jsonString = String(data: exportData, encoding: .utf8) ?? ""
            
            await MainActor.run {
                self.exportData = jsonString
                self.showingExportSheet = true
                self.isExporting = false
                print("✅ Exported \(allDogs.count) dogs from database")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to export database: \(error.localizedDescription)"
                self.isExporting = false
                print("❌ Failed to export database: \(error)")
            }
        }
    }
    
    private func importDatabase(_ importedDogs: [Dog]) async {
        isImporting = true
        errorMessage = nil
        
        var importedCount = 0
        var skippedCount = 0
        
        for dog in importedDogs {
            // Check if dog already exists (by ID)
            let existingDogs = await dataManager.getAllDogs()
            let dogExists = existingDogs.contains { $0.id == dog.id }
            
            if !dogExists {
                // Import the dog
                await dataManager.addDog(dog)
                importedCount += 1
                print("✅ Imported dog: \(dog.name)")
            } else {
                skippedCount += 1
                print("⏭️ Skipped existing dog: \(dog.name)")
            }
        }
        
        await MainActor.run {
            self.isImporting = false
            self.showingImportSheet = false
            
            if importedCount > 0 {
                self.errorMessage = "Successfully imported \(importedCount) dogs. Skipped \(skippedCount) existing dogs."
            } else {
                self.errorMessage = "No new dogs imported. All \(skippedCount) dogs already exist in database."
            }
            
            // Refresh the database view
            Task {
                await loadAllDogs()
            }
        }
    }
}

struct DatabaseDogRow: View {
    let dog: Dog
    let visitCount: Int
    @Binding var selectedDogForOverlay: Dog?
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile picture
            if let profilePictureData = dog.profilePictureData, let uiImage = UIImage(data: profilePictureData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .onTapGesture {
                        selectedDogForOverlay = dog
                    }
            } else {
                Image(systemName: "dog")
                    .font(.title2)
                    .foregroundStyle(.gray)
                    .frame(width: 50, height: 50)
                    .background(.gray.opacity(0.2))
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(dog.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let ownerName = dog.ownerName {
                    Text("Owner: \(ownerName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Visit count
            HStack(spacing: 4) {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("\(visitCount) visit\(visitCount == 1 ? "" : "s")")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }
            
            Spacer()
            
            // Show status indicators
            HStack(spacing: 4) {
                if dog.isCurrentlyPresent {
                    Text("EXISTS ON MAIN PAGE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.2))
                        .clipShape(Capsule())
                }
                
                if dog.isDeleted {
                    Text("DELETED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.red.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DatabaseView()
        .environmentObject(DataManager.shared)
} 