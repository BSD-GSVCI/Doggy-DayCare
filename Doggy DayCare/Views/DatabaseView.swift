import SwiftUI

struct DatabaseView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var authService = AuthenticationService.shared
    @State private var allDogs: [DogWithVisit] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var dogToDelete: DogWithVisit?
    @State private var showingEditDog = false
    @State private var dogToEdit: DogWithVisit?
    @State private var isLoadingEdit = false
    @State private var errorMessage: String?
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var showingAddDogSheet = false
    @State private var exportData: String = ""
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var dogVisitCounts: [String: Int] = [:]
    @State private var selectedDogForOverlay: DogWithVisit?
    
    private var filteredDogs: [DogWithVisit] {
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
                    }
                    .refreshable {
                        dataManager.forceRefreshDatabaseCache()
                        await loadAllDogs()
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
                        DogFormView(dataManager: dataManager, dog: dog, addToDatabaseOnly: true)
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
                    DogFormView(dataManager: dataManager, dog: nil, addToDatabaseOnly: true)
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
}

extension DatabaseView {
    private func loadAllDogs() async {
        isLoading = true
        errorMessage = nil
        
        // Fetch all persistent dogs from the database (uses smart caching)
        await dataManager.fetchAllPersistentDogs()
        
        // Use the allDogs property which now contains cached persistent dogs
        let dogs = dataManager.allDogs
        
        await MainActor.run {
            self.allDogs = dogs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            self.isLoading = false
            #if DEBUG
            print("✅ Loaded \(dogs.count) dogs from current list")
            #endif
            
            // Use actual visit counts from persistent dogs
            self.dogVisitCounts = dogs.reduce(into: [:]) { result, dog in
                result[dog.id.uuidString] = dog.persistentDog.visitCount
            }
        }
    }
    
    private func permanentlyDeleteDog(_ dog: DogWithVisit) async {
        isLoading = true
        errorMessage = nil
        
        await dataManager.deleteDog(dog)
        
        await MainActor.run {
            // Remove from local array
            self.allDogs.removeAll { $0.id == dog.id }
            self.isLoading = false
            #if DEBUG
            print("✅ Permanently deleted dog: \(dog.name)")
            #endif
        }
    }
    
    private func loadFullDogForEdit(_ dog: DogWithVisit) async {
        #if DEBUG
        print("🔍 Loading full dog information for editing: \(dog.name)")
        #endif
        
        await MainActor.run {
            self.isLoadingEdit = true
        }
        
        // For now, use the dog as-is since we're using DogWithVisit
        await MainActor.run {
            self.dogToEdit = dog
            self.isLoadingEdit = false
            self.showingEditDog = true
            #if DEBUG
            print("✅ Loaded dog information for editing: \(dog.name)")
            #endif
        }
    }
    
    private func exportDatabase() async {
        isExporting = true
        errorMessage = nil
        
        do {
            // Fetch all persistent dogs using new architecture
            await dataManager.fetchAllPersistentDogs()
            
            // Get all dogs from database (not just currently present ones)
            let allDogs = dataManager.allDogs
            
            // Create export data
            let exportData = try JSONEncoder().encode(allDogs)
            let jsonString = String(data: exportData, encoding: .utf8) ?? ""
            
            await MainActor.run {
                self.exportData = jsonString
                self.showingExportSheet = true
                self.isExporting = false
                #if DEBUG
                print("✅ Exported \(allDogs.count) dogs from database using new architecture")
                #endif
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to export database: \(error.localizedDescription)"
                self.isExporting = false
                #if DEBUG
                print("❌ Failed to export database: \(error)")
                #endif
            }
        }
    }
    
    private func importDatabase(_ importedDogs: [DogWithVisit]) async {
        isImporting = true
        errorMessage = nil
        
        var importedCount = 0
        var skippedCount = 0
        var errorCount = 0
        
        // Fetch all existing dogs using new architecture
        await dataManager.fetchAllPersistentDogs()
        let existingDogs = dataManager.allDogs
        
        for importedDog in importedDogs {
            // Check if dog already exists (by ID)
            let dogExists = existingDogs.contains { $0.id == importedDog.id }
            
            if !dogExists {
                do {
                    // Create PersistentDog from imported data
                    let persistentDog = PersistentDog(
                        id: importedDog.persistentDog.id,
                        name: importedDog.name,
                        ownerName: importedDog.ownerName,
                        ownerPhoneNumber: importedDog.ownerPhoneNumber,
                        age: importedDog.age,
                        gender: importedDog.gender,
                        isNeuteredOrSpayed: importedDog.isNeuteredOrSpayed,
                        vaccinations: importedDog.vaccinations,
                        needsWalking: importedDog.needsWalking,
                        walkingNotes: importedDog.walkingNotes,
                        isDaycareFed: importedDog.isDaycareFed,
                        notes: importedDog.notes,
                        specialInstructions: importedDog.specialInstructions,
                        allergiesAndFeedingInstructions: importedDog.allergiesAndFeedingInstructions,
                        profilePictureData: importedDog.profilePictureData,
                        visitCount: importedDog.persistentDog.visitCount,
                        lastVisitDate: importedDog.persistentDog.lastVisitDate,
                        createdAt: importedDog.persistentDog.createdAt,
                        updatedAt: Date(),
                        createdBy: importedDog.persistentDog.createdBy,
                        lastModifiedBy: AuthenticationService.shared.currentUser?.name
                    )
                    
                    // Add to database using new architecture
                    try await dataManager.persistentDogService.createPersistentDog(persistentDog)
                    
                    // Update the persistent dog cache
                    await dataManager.incrementallyUpdatePersistentDogCache(add: persistentDog)
                    
                    importedCount += 1
                    #if DEBUG
                    print("✅ Imported dog: \(importedDog.name)")
                    #endif
                } catch {
                    errorCount += 1
                    #if DEBUG
                    print("❌ Failed to import dog \(importedDog.name): \(error)")
                    #endif
                }
            } else {
                skippedCount += 1
                #if DEBUG
                print("⏭️ Skipped existing dog: \(importedDog.name)")
                #endif
            }
        }
        
        await MainActor.run {
            self.isImporting = false
            self.showingImportSheet = false
            
            var message = ""
            if importedCount > 0 {
                message += "Successfully imported \(importedCount) dog\(importedCount == 1 ? "" : "s"). "
            }
            if skippedCount > 0 {
                message += "Skipped \(skippedCount) existing dog\(skippedCount == 1 ? "" : "s"). "
            }
            if errorCount > 0 {
                message += "Failed to import \(errorCount) dog\(errorCount == 1 ? "" : "s"). "
            }
            
            if message.isEmpty {
                message = "No dogs were processed."
            }
            
            self.errorMessage = message
            
            // Refresh the database view
            Task {
                await loadAllDogs()
            }
        }
    }
}

struct DatabaseDogRow: View {
    let dog: DogWithVisit
    let visitCount: Int
    @Binding var selectedDogForOverlay: DogWithVisit?
    @EnvironmentObject var dataManager: DataManager
    
    var isOnMainPage: Bool {
        // Check if this dog exists in the current main dogs list and is currently present
        return dataManager.dogs.filter { $0.isCurrentlyPresent }.contains { $0.id == dog.id }
    }
    
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
                if isOnMainPage {
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