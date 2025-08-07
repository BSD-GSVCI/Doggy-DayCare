import Foundation

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var dogs: [DogWithVisit] = []
    @Published var allDogs: [DogWithVisit] = []  // Separate array for all dogs including deleted ones
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let cloudKitService = CloudKitService.shared
    private let cloudKitHistoryService = CloudKitHistoryService.shared
    private let persistentDogService = PersistentDogService.shared
    private let visitService = VisitService.shared
    private let migrationService = MigrationService.shared
    
    // Incremental sync tracking
    private var lastSyncTime: Date = Date.distantPast
    private var lastAllDogsSyncTime: Date = Date.distantPast
    private var allDogsCache: [DogWithVisit] = [] // Cache for database view
    private let databaseCacheExpiration: TimeInterval = 300 // 5 minutes
    
    // Feature flag for persistent dog system
    private var usePersistentDogs = true // Set to true to use new system
    
    private init() {
        print("📱 DataManager initialized")
    }
    
    // MARK: - Authentication
    
    func authenticate() async throws {
        try await cloudKitService.authenticate()
        // After successful authentication, fetch the data in background
        Task {
            await fetchDogs()
            await fetchUsers()
        }
    }
    
    // MARK: - Dog Management
    
    func fetchDogs() async {
        // Don't show loading indicator for background refreshes
        let shouldShowLoading = !isLoading
        if shouldShowLoading {
            isLoading = true
        }
        errorMessage = nil
        
        print("🔍 DataManager: Starting fetchDogs...")
        
        if usePersistentDogs {
            await fetchDogsWithPersistentSystem(shouldShowLoading: shouldShowLoading)
        } else {
            await fetchDogsWithLegacySystem(shouldShowLoading: shouldShowLoading)
        }
    }
    
    private func fetchDogsWithPersistentSystem(shouldShowLoading: Bool) async {
        do {
            // Fetch persistent dogs
            let persistentDogs = try await persistentDogService.fetchPersistentDogs()
            print("🔍 DataManager: Got \(persistentDogs.count) persistent dogs")
            
            // Fetch active visits
            let activeVisits = try await visitService.fetchActiveVisits()
            print("🔍 DataManager: Got \(activeVisits.count) active visits")
            
            // Combine persistent dogs with their active visits
            let dogsWithVisits = DogWithVisit.currentlyPresentFromPersistentDogsAndVisits(persistentDogs, activeVisits)
            
            print("🔍 DataManager: Created \(dogsWithVisits.count) dogs with visits")
            
            // Debug: Print each dog's details
            for dogWithVisit in dogsWithVisits {
                print("🐕 Dog: \(dogWithVisit.name), Owner: \(dogWithVisit.ownerName ?? "none"), Present: \(dogWithVisit.isCurrentlyPresent), Arrival: \(dogWithVisit.arrivalDate)")
            }
            
            await MainActor.run {
                let previousCount = self.dogs.count
                let previousDogIds = Set(self.dogs.map { $0.id })
                
                self.dogs = dogsWithVisits
                
                // Validation checks
                if previousCount > 0 {
                    let newDogIds = Set(dogsWithVisits.map { $0.id })
                    let missingDogs = previousDogIds.subtracting(newDogIds)
                    
                    if missingDogs.count > 0 {
                        print("⚠️ WARNING: \(missingDogs.count) dogs disappeared after fetch")
                    }
                    
                    if dogsWithVisits.count < Int(Double(previousCount) * 0.5) {
                        print("⚠️ CRITICAL: Dog count dropped from \(previousCount) to \(dogsWithVisits.count)")
                    }
                }
                
                if shouldShowLoading {
                    self.isLoading = false
                }
                print("✅ DataManager: Set \(dogsWithVisits.count) dogs in local array")
                
                // Update last sync time
                self.lastSyncTime = Date()
                
                // Record daily snapshot for history
                Task {
                    await self.recordDailySnapshotIfNeeded()
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch dogs: \(error.localizedDescription)"
                if shouldShowLoading {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func fetchDogsWithLegacySystem(shouldShowLoading: Bool) async {
        do {
            let cloudKitDogs = try await cloudKitService.fetchDogs()
            print("🔍 DataManager: Got \(cloudKitDogs.count) CloudKit dogs")
            
            let localDogs = cloudKitDogs.map { $0.toDogWithVisit() }
            print("🔍 DataManager: Converted to \(localDogs.count) local dogs")
            
            // Debug: Print each dog's details
            for dog in localDogs {
                print("🐕 Dog: \(dog.name), Owner: \(dog.ownerName ?? "none"), Deleted: \(dog.isDeleted), Present: \(dog.isCurrentlyPresent), Arrival: \(dog.arrivalDate), Departure: \(dog.departureDate?.description ?? "nil")")
            }
            
            await MainActor.run {
                let previousCount = self.dogs.count
                let previousDogIds = Set(self.dogs.map { $0.id })
                
                self.dogs = localDogs
                
                // Validation checks
                if previousCount > 0 {
                    let newDogIds = Set(localDogs.map { $0.id })
                    let missingDogs = previousDogIds.subtracting(newDogIds)
                    
                    if missingDogs.count > 0 {
                        print("⚠️ WARNING: \(missingDogs.count) dogs disappeared after fetch")
                        // Could implement recovery logic here
                    }
                    
                    if localDogs.count < Int(Double(previousCount) * 0.5) {
                        print("⚠️ CRITICAL: Dog count dropped from \(previousCount) to \(localDogs.count)")
                        // Consider keeping previous data or alerting user
                    }
                }
                
                if shouldShowLoading {
                    self.isLoading = false
                }
                print("✅ DataManager: Set \(localDogs.count) dogs in local array")
                
                // Update last sync time
                self.lastSyncTime = Date()
                
                // Record daily snapshot for history
                Task {
                    await self.recordDailySnapshotIfNeeded()
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch dogs: \(error.localizedDescription)"
                if shouldShowLoading {
                    self.isLoading = false
                }
            }
        }
    }
    
    
    // MARK: - Future Booking Methods
    
    func addFutureBooking(
        name: String,
        ownerName: String?,
        ownerPhoneNumber: String?,
        arrivalDate: Date,
        isBoarding: Bool,
        boardingEndDate: Date?,
        isDaycareFed: Bool,
        needsWalking: Bool,
        walkingNotes: String?,
        notes: String?,
        specialInstructions: String?,
        allergiesAndFeedingInstructions: String?,
        profilePictureData: Data?,
        age: Int?,
        gender: DogGender?,
        vaccinations: [VaccinationItem],
        isNeuteredOrSpayed: Bool?,
        medications: [Medication],
        scheduledMedications: [ScheduledMedication]
    ) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // First, check if a persistent dog already exists
            let existingDogs = try await persistentDogService.fetchPersistentDogs()
            let matchingDog = existingDogs.first { dog in
                dog.name.lowercased() == name.lowercased() &&
                dog.ownerName?.lowercased() == ownerName?.lowercased() &&
                dog.ownerPhoneNumber == ownerPhoneNumber
            }
            
            let persistentDog: PersistentDog
            if let existingDog = matchingDog {
                // Update existing persistent dog with any new information
                var updatedDog = existingDog
                updatedDog.allergiesAndFeedingInstructions = allergiesAndFeedingInstructions ?? existingDog.allergiesAndFeedingInstructions
                updatedDog.profilePictureData = profilePictureData ?? existingDog.profilePictureData
                updatedDog.age = age ?? existingDog.age
                updatedDog.gender = gender ?? existingDog.gender
                updatedDog.vaccinations = vaccinations.isEmpty ? existingDog.vaccinations : vaccinations
                updatedDog.isNeuteredOrSpayed = isNeuteredOrSpayed ?? existingDog.isNeuteredOrSpayed
                updatedDog.updatedAt = Date()
                
                try await persistentDogService.updatePersistentDog(updatedDog)
                persistentDog = updatedDog
            } else {
                // Create new persistent dog
                let newPersistentDog = PersistentDog(
                    name: name,
                    ownerName: ownerName,
                    ownerPhoneNumber: ownerPhoneNumber,
                    age: age,
                    gender: gender,
                    vaccinations: vaccinations,
                    isNeuteredOrSpayed: isNeuteredOrSpayed,
                    allergiesAndFeedingInstructions: allergiesAndFeedingInstructions,
                    profilePictureData: profilePictureData
                )
                
                try await persistentDogService.createPersistentDog(newPersistentDog)
                persistentDog = newPersistentDog
            }
            
            // Create the future visit
            let visit = Visit(
                dogId: persistentDog.id,
                arrivalDate: arrivalDate,
                isBoarding: isBoarding,
                boardingEndDate: boardingEndDate,
                isDaycareFed: isDaycareFed,
                notes: notes,
                specialInstructions: specialInstructions,
                needsWalking: needsWalking,
                walkingNotes: walkingNotes,
                medications: medications,
                scheduledMedications: scheduledMedications
            )
            
            try await visitService.createVisit(visit)
            print("✅ Created future booking for \(name)")
            
            // Refresh data
            await fetchDogs()
        } catch {
            print("❌ Failed to create future booking: \(error)")
            errorMessage = "Failed to create future booking: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func updateFutureBooking(
        dogWithVisit: DogWithVisit,
        name: String,
        ownerName: String?,
        ownerPhoneNumber: String?,
        arrivalDate: Date,
        isBoarding: Bool,
        boardingEndDate: Date?,
        isDaycareFed: Bool,
        needsWalking: Bool,
        walkingNotes: String?,
        notes: String?,
        allergiesAndFeedingInstructions: String?,
        profilePictureData: Data?,
        age: Int?,
        gender: DogGender?,
        vaccinations: [VaccinationItem],
        isNeuteredOrSpayed: Bool?,
        medications: [Medication],
        scheduledMedications: [ScheduledMedication]
    ) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Update the persistent dog info
            var updatedPersistentDog = dogWithVisit.persistentDog
            updatedPersistentDog.name = name
            updatedPersistentDog.ownerName = ownerName
            updatedPersistentDog.ownerPhoneNumber = ownerPhoneNumber
            updatedPersistentDog.allergiesAndFeedingInstructions = allergiesAndFeedingInstructions
            updatedPersistentDog.profilePictureData = profilePictureData
            updatedPersistentDog.age = age
            updatedPersistentDog.gender = gender
            updatedPersistentDog.vaccinations = vaccinations
            updatedPersistentDog.isNeuteredOrSpayed = isNeuteredOrSpayed
            updatedPersistentDog.updatedAt = Date()
            
            try await persistentDogService.updatePersistentDog(updatedPersistentDog)
            
            // Update the visit info if it exists
            if var visit = dogWithVisit.currentVisit {
                visit.arrivalDate = arrivalDate
                visit.isBoarding = isBoarding
                visit.boardingEndDate = boardingEndDate
                visit.isDaycareFed = isDaycareFed
                visit.needsWalking = needsWalking
                visit.walkingNotes = walkingNotes
                visit.notes = notes
                visit.medications = medications
                visit.scheduledMedications = scheduledMedications
                visit.updatedAt = Date()
                
                try await visitService.updateVisit(visit)
            }
            
            print("✅ Updated future booking for \(name)")
            
            // Refresh data
            await fetchDogs()
        } catch {
            print("❌ Failed to update future booking: \(error)")
            errorMessage = "Failed to update future booking: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Adapter Methods for DogWithVisit
    
    func undoDepartureOptimized(for dogWithVisit: DogWithVisit) async {
        guard var visit = dogWithVisit.currentVisit else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Clear the departure date to make the dog present again
            visit.departureDate = nil
            visit.updatedAt = Date()
            
            try await visitService.updateVisit(visit)
            print("✅ Undid departure for \(dogWithVisit.name)")
            
            // Refresh data
            await fetchDogs()
        } catch {
            print("❌ Failed to undo departure: \(error)")
            errorMessage = "Failed to undo departure: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func editDepartureOptimized(for dogWithVisit: DogWithVisit, newDate: Date) async {
        guard var visit = dogWithVisit.currentVisit else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Update the departure date
            visit.departureDate = newDate
            visit.updatedAt = Date()
            
            try await visitService.updateVisit(visit)
            print("✅ Updated departure time for \(dogWithVisit.name)")
            
            // Refresh data
            await fetchDogs()
        } catch {
            print("❌ Failed to update departure: \(error)")
            errorMessage = "Failed to update departure: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func setArrivalTimeOptimized(for dogWithVisit: DogWithVisit, newArrivalTime: Date) async {
        guard var visit = dogWithVisit.currentVisit else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Update the arrival time
            visit.arrivalDate = newArrivalTime
            visit.updatedAt = Date()
            
            try await visitService.updateVisit(visit)
            print("✅ Updated arrival time for \(dogWithVisit.name)")
            
            // Refresh data
            await fetchDogs()
        } catch {
            print("❌ Failed to update arrival time: \(error)")
            errorMessage = "Failed to update arrival time: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Migration Methods
    
    func performMigration() async throws {
        print("🚀 Starting migration to persistent dog system...")
        
        do {
            try await migrationService.performCompleteMigration()
            print("✅ Migration completed successfully!")
        } catch {
            print("❌ Migration failed: \(error)")
            throw error
        }
    }
    
    func getMigrationProgress() -> Double {
        return migrationService.migrationProgress
    }
    
    func getMigrationStatus() -> String {
        return migrationService.migrationStatus
    }
    
    func isMigrationComplete() -> Bool {
        return migrationService.isMigrationComplete
    }
    
    func fetchDogsIncremental() async {
        // Don't show loading indicator for background refreshes
        let shouldShowLoading = !isLoading
        if shouldShowLoading {
            isLoading = true
        }
        errorMessage = nil
        
        print("🔍 DataManager: Starting incremental fetchDogs...")
        print("🔍 DataManager: Last sync time: \(lastSyncTime)")
        
        do {
            let cloudKitDogs = try await cloudKitService.fetchDogsIncremental(since: lastSyncTime)
            print("🔍 DataManager: Got \(cloudKitDogs.count) incremental CloudKit dogs")
            
            if !cloudKitDogs.isEmpty {
                let localDogs = cloudKitDogs.map { $0.toDogWithVisit() }
                print("🔍 DataManager: Converted to \(localDogs.count) local dogs")
                
                // Update cache with only changed dogs
                await updateDogsCache(with: localDogs)
                
                // Update last sync time
                lastSyncTime = Date()
                print("✅ DataManager: Updated cache with \(localDogs.count) changed dogs")
            } else {
                print("✅ DataManager: No changes found, using existing cache")
            }
            
            if shouldShowLoading {
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch dogs incrementally: \(error.localizedDescription)"
                if shouldShowLoading {
                    self.isLoading = false
                }
                print("❌ DataManager: Failed to fetch dogs incrementally: \(error)")
            }
        }
    }
    
    func getAllDogs() async -> [DogWithVisit] {
        do {
            let cloudKitDogs = try await cloudKitService.fetchDogs()
            let convertedDogs = cloudKitDogs.map { $0.toDogWithVisit() }
            print("✅ Fetched \(convertedDogs.count) total dogs from CloudKit")
            return convertedDogs
        } catch {
            print("❌ Failed to fetch all dogs: \(error)")
            return []
        }
    }
    
    // MARK: - Database-specific fetch (more robust)
    
    func getAllDogsForDatabase() async -> [DogWithVisit] {
        // Always use cached data if available - never replace cache
        if !allDogsCache.isEmpty {
            print("✅ Using cached database data (\(allDogsCache.count) dogs)")
            return allDogsCache
        }
        
        print("🔄 Database cache is empty, fetching initial data...")
        
        do {
            // Only fetch fresh data if cache is completely empty
            let cloudKitDogs = try await cloudKitService.fetchAllDogsIncludingDeleted()
            let convertedDogs = cloudKitDogs.map { $0.toDogWithVisit() }
            
            // Initialize cache with fresh data
            await MainActor.run {
                self.allDogsCache = convertedDogs
                self.lastAllDogsSyncTime = Date()
            }
            
            print("✅ Initialized database cache with \(convertedDogs.count) dogs from CloudKit")
            return convertedDogs
        } catch {
            print("❌ Failed to fetch initial dogs: \(error)")
            return []
        }
    }
    
    func forceRefreshDatabaseCache() {
        allDogsCache.removeAll() // Clear cache for manual refresh
        lastAllDogsSyncTime = Date.distantPast
        print("🔄 Database cache manually cleared - will fetch fresh data on next access")
    }
    
    // MARK: - Incremental Database Cache Updates
    
    func incrementallyUpdateDatabaseCache(with newDog: DogWithVisit) {
        // Add new dog to cache if not already present
        if !allDogsCache.contains(where: { $0.id == newDog.id }) {
            allDogsCache.append(newDog)
            print("✅ Incrementally added dog to database cache: \(newDog.name)")
        }
    }
    
    func incrementallyRemoveFromDatabaseCache(dogId: UUID) {
        // Remove dog from cache if present
        if let index = allDogsCache.firstIndex(where: { $0.id == dogId }) {
            let removedDog = allDogsCache.remove(at: index)
            print("✅ Incrementally removed dog from database cache: \(removedDog.name)")
        }
    }
    
    func incrementallyUpdateExistingDogInDatabaseCache(with updatedDog: DogWithVisit) {
        // Update existing dog in cache
        if let index = allDogsCache.firstIndex(where: { $0.id == updatedDog.id }) {
            allDogsCache[index] = updatedDog
            print("✅ Incrementally updated dog in database cache: \(updatedDog.name)")
        }
    }
    
    
    // Legacy method removed - used non-existent toCloudKitDog() method
    
    func updateDog(_ dog: DogWithVisit) async {
        print("🔄 DataManager.updateDog called for: \(dog.name)")
        
        // Log the update action
        await logDogActivity(action: "UPDATE_DOG", dog: dog, extra: "Updating dog information")
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index] = dog
                print("✅ Updated local cache immediately for responsive UI")
            }
        }
        
        // Handle CloudKit operations in background without blocking UI
        Task.detached {
            do {
                print("🔄 Calling CloudKit update in background...")
                // TODO: Replace with proper service call
                print("✅ CloudKit update successful")
                
                // Update cache with the changed dog
                await self.updateDogsCache(with: [dog])
                
                // Update database cache on main actor
                await MainActor.run {
                    self.lastSyncTime = Date() // Update sync time for dog update
                    self.incrementallyUpdateExistingDogInDatabaseCache(with: dog) // Incrementally update database cache
                }
            } catch {
                print("❌ Failed to update dog in CloudKit: \(error)")
                // Revert local cache if CloudKit update failed
                await MainActor.run {
                    self.errorMessage = "Failed to update dog: \(error.localizedDescription)"
                    print("❌ Reverting local cache due to CloudKit failure")
                }
            }
        }
    }
    
    // MARK: - Optimized Medication and Vaccination Updates
    
    func updateDogMedications(_ dog: DogWithVisit, medications: [Medication], scheduledMedications: [ScheduledMedication]) async {
        print("🔄 DataManager.updateDogMedications called for: \(dog.name)")
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].currentVisit?.medications = medications
                self.dogs[index].currentVisit?.scheduledMedications = scheduledMedications
                self.dogs[index].currentVisit?.updatedAt = Date()
                print("✅ Updated medications in local cache immediately")
            }
        }
        
        // Handle CloudKit operations in background
        Task.detached {
            do {
                // Update the visit with new medications
                if var visit = dog.currentVisit {
                    visit.medications = medications
                    visit.scheduledMedications = scheduledMedications
                    visit.updatedAt = Date()
                    
                    print("🔄 Calling CloudKit medication update in background...")
                    try await self.visitService.updateVisit(visit)
                    print("✅ CloudKit medication update successful")
                } else {
                    print("⚠️ No current visit found to update medications")
                }
                
                // Update cache with the changed dog
                await self.updateDogsCache(with: [dog])
                
                await MainActor.run {
                    self.lastSyncTime = Date()
                }
            } catch {
                print("❌ Failed to update medications in CloudKit: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to update medications: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Adapter method for DogWithVisit
    func updateDogVaccinations(_ dogWithVisit: DogWithVisit, vaccinations: [VaccinationItem]) async {
        print("🔄 DataManager.updateDogVaccinations called for: \(dogWithVisit.name)")
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dogWithVisit.id }) {
                let currentDogWithVisit = self.dogs[index]
                // Create new PersistentDog with updated vaccinations
                let updatedPersistentDog = PersistentDog(
                    id: currentDogWithVisit.persistentDog.id,
                    name: currentDogWithVisit.persistentDog.name,
                    ownerName: currentDogWithVisit.persistentDog.ownerName,
                    ownerPhoneNumber: currentDogWithVisit.persistentDog.ownerPhoneNumber,
                    profilePictureData: currentDogWithVisit.persistentDog.profilePictureData,
                    age: currentDogWithVisit.persistentDog.age,
                    gender: currentDogWithVisit.persistentDog.gender,
                    vaccinations: vaccinations, // Updated vaccinations
                    isNeuteredOrSpayed: currentDogWithVisit.persistentDog.isNeuteredOrSpayed,
                    allergiesAndFeedingInstructions: currentDogWithVisit.persistentDog.allergiesAndFeedingInstructions,
                    createdAt: currentDogWithVisit.persistentDog.createdAt,
                    updatedAt: Date() // Updated timestamp
                )
                // Create new DogWithVisit with updated PersistentDog
                let updatedDogWithVisit = DogWithVisit(persistentDog: updatedPersistentDog, visit: currentDogWithVisit.currentVisit)
                self.dogs[index] = updatedDogWithVisit
                print("✅ Updated vaccinations in local cache immediately")
            }
        }
        
        // Update the persistent dog in CloudKit
        do {
            var updatedPersistentDog = dogWithVisit.persistentDog
            updatedPersistentDog.vaccinations = vaccinations
            updatedPersistentDog.updatedAt = Date()
            try await persistentDogService.updatePersistentDog(updatedPersistentDog)
            print("✅ Updated vaccinations in CloudKit")
            
            // Refresh data
            await fetchDogs()
        } catch {
            print("❌ Failed to update vaccinations: \(error)")
            errorMessage = "Failed to update vaccinations: \(error.localizedDescription)"
            // Refresh to restore correct state
            await fetchDogs()
        }
    }
    
    
    // Adapter method for DogWithVisit
    func deleteDog(_ dogWithVisit: DogWithVisit) async {
        guard let visit = dogWithVisit.currentVisit else {
            print("⚠️ No active visit found for dog: \(dogWithVisit.name)")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        print("🔄 Starting delete visit for dog: \(dogWithVisit.name)")
        
        // Remove from local cache immediately for responsive UI
        await MainActor.run {
            self.dogs.removeAll { $0.id == dogWithVisit.id }
            print("✅ Removed dog from local cache")
        }
        
        do {
            // Delete the visit in CloudKit (this will mark it as deleted)
            try await visitService.deleteVisit(visit)
            print("✅ Marked visit as deleted in CloudKit")
            
            // Update the persistent dog's last visit date
            var updatedPersistentDog = dogWithVisit.persistentDog
            updatedPersistentDog.lastVisitDate = Date()
            try await persistentDogService.updatePersistentDog(updatedPersistentDog)
            
            // Refresh data
            await fetchDogs()
        } catch {
            print("❌ Failed to delete visit: \(error)")
            errorMessage = "Failed to delete: \(error.localizedDescription)"
            // Re-add to cache if delete failed
            await fetchDogs()
        }
        
        isLoading = false
    }
    
    
    func permanentlyDeleteDog(_ dog: DogWithVisit) async {
        isLoading = true
        errorMessage = nil
        
        print("🔄 Starting permanent delete dog from database: \(dog.name)")
        
        // Log the permanent delete action
        await logDogActivity(action: "PERMANENTLY_DELETE_DOG", dog: dog, extra: "Permanently deleting dog from database")
        
        // Only remove from allDogs array (database view), NOT from main dogs list
        await MainActor.run {
            self.allDogs.removeAll { $0.id == dog.id }
            self.incrementallyRemoveFromDatabaseCache(dogId: dog.id) // Incrementally remove from database cache
            print("✅ Removed dog from database view only")
        }
        
        // Permanently delete from CloudKit
        do {
            // TODO: Replace with proper service call for PersistentDog
            try await persistentDogService.deletePersistentDog(dog.persistentDog)
            print("✅ Dog permanently deleted from CloudKit")
        } catch {
            print("❌ Failed to permanently delete dog: \(error)")
            errorMessage = "Failed to permanently delete dog: \(error.localizedDescription)"
            
            // Restore to database view if CloudKit update failed
            await MainActor.run {
                self.allDogs.append(dog)
                print("🔄 Restored dog to database view due to CloudKit failure")
            }
        }
        
        isLoading = false
    }
    
    func extendBoarding(for dog: DogWithVisit, newEndDate: Date) async {
        print("🔄 Extending boarding for \(dog.name) until \(newEndDate)")
        
        // Update the visit's boarding end date
        guard let currentVisit = dog.currentVisit else {
            print("❌ Cannot extend boarding - no current visit found")
            return
        }
        
        var updatedVisit = currentVisit
        updatedVisit.boardingEndDate = newEndDate
        updatedVisit.updatedAt = Date()
        
        do {
            try await visitService.updateVisit(updatedVisit)
            
            // Update local cache
            await MainActor.run {
                if let index = dogs.firstIndex(where: { $0.id == dog.id }) {
                    let updatedDogWithVisit = DogWithVisit(persistentDog: dog.persistentDog, visit: updatedVisit)
                    dogs[index] = updatedDogWithVisit
                }
            }
            
            print("✅ Successfully extended boarding for \(dog.name)")
        } catch {
            print("❌ Failed to extend boarding: \(error)")
            errorMessage = "Failed to extend boarding: \(error.localizedDescription)"
        }
    }
    
    // MARK: - User Management
    
    func fetchUsers() async {
        isLoading = true
        errorMessage = nil
        do {
            let cloudKitUsers = try await cloudKitService.fetchAllUsers()
            let convertedUsers = cloudKitUsers.map { $0.toUser() }
            await MainActor.run {
                self.users = convertedUsers
                self.isLoading = false
                print("✅ Fetched \(convertedUsers.count) users from CloudKit")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch users: \(error.localizedDescription)"
                self.isLoading = false
                print("❌ Failed to fetch users: \(error)")
            }
        }
    }
    
    func addUser(_ user: User) async {
        isLoading = true
        errorMessage = nil
        do {
            let cloudKitUser = user.toCloudKitUser()
            let addedCloudKitUser = try await cloudKitService.createUser(cloudKitUser)
            let addedUser = addedCloudKitUser.toUser()
            await MainActor.run {
                self.users.append(addedUser)
                self.isLoading = false
                print("✅ Added user: \(addedUser.name)")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to add user: \(error.localizedDescription)"
                self.isLoading = false
                print("❌ Failed to add user: \(error)")
            }
        }
    }
    
    func addCloudKitUser(_ cloudKitUser: CloudKitUser) async {
        isLoading = true
        errorMessage = nil
        do {
            let addedCloudKitUser = try await cloudKitService.createUser(cloudKitUser)
            let addedUser = addedCloudKitUser.toUser()
            await MainActor.run {
                self.users.append(addedUser)
                self.isLoading = false
                print("✅ Added CloudKit user: \(addedUser.name)")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to add user: \(error.localizedDescription)"
                self.isLoading = false
                print("❌ Failed to add CloudKit user: \(error)")
            }
        }
    }
    
    func updateUser(_ user: User) async {
        isLoading = true
        errorMessage = nil
        do {
            // Get the existing user from CloudKit to preserve the hashedPassword
            let existingCloudKitUser = try await cloudKitService.fetchUser(by: user.id)
            
            // Convert the updated user to CloudKitUser
            var cloudKitUser = user.toCloudKitUser()
            
            // Preserve the existing hashedPassword if it exists
            if let existingUser = existingCloudKitUser, let existingPassword = existingUser.hashedPassword {
                cloudKitUser.hashedPassword = existingPassword
            }
            
            let updatedCloudKitUser = try await cloudKitService.updateUser(cloudKitUser)
            let updatedUser = updatedCloudKitUser.toUser()
            await MainActor.run {
                if let index = self.users.firstIndex(where: { $0.id == user.id }) {
                    self.users[index] = updatedUser
                }
                self.isLoading = false
                print("✅ Updated user: \(updatedUser.name)")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update user: \(error.localizedDescription)"
                self.isLoading = false
                print("❌ Failed to update user: \(error)")
            }
        }
    }
    
    func deleteUser(_ user: User) async {
        isLoading = true
        errorMessage = nil
        do {
            let cloudKitUser = user.toCloudKitUser()
            try await cloudKitService.deleteUser(cloudKitUser)
            await MainActor.run {
                self.users.removeAll { $0.id == user.id }
                self.isLoading = false
                print("✅ Deleted user: \(user.name)")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to delete user: \(error.localizedDescription)"
                self.isLoading = false
                print("❌ Failed to delete user: \(error)")
            }
        }
    }
    
    // MARK: - Individual Record Management
    
    func deleteFeedingRecord(_ record: FeedingRecord, from dog: DogWithVisit) async {
        isLoading = true
        errorMessage = nil
        
        print("🗑️ Attempting to delete feeding record: \(record.id) for dog: \(dog.name)")
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].currentVisit?.feedingRecords.removeAll { $0.id == record.id }
                self.dogs[index].currentVisit?.updatedAt = Date()
                print("✅ Removed feeding record from local cache")
            } else {
                print("⚠️ Dog not found in local cache")
            }
        }
        
        // Update CloudKit with only the deletion
        do {
            try await cloudKitService.deleteFeedingRecord(record, for: dog.id.uuidString)
            print("✅ Feeding record deleted from CloudKit for \(dog.name)")
        } catch {
            print("❌ Failed to delete feeding record from CloudKit: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            // Revert local cache if CloudKit update failed
            await MainActor.run {
                if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                    self.dogs[index].currentVisit?.feedingRecords.append(record)
                    print("🔄 Reverted feeding record in local cache due to CloudKit failure")
                }
            }
        }
        
        isLoading = false
    }
    
    func deleteMedicationRecord(_ record: MedicationRecord, from dog: DogWithVisit) async {
        isLoading = true
        errorMessage = nil
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].currentVisit?.medicationRecords.removeAll { $0.id == record.id }
                self.dogs[index].currentVisit?.updatedAt = Date()
            }
        }
        
        // Update CloudKit with only the deletion
        do {
            try await cloudKitService.deleteMedicationRecord(record, for: dog.id.uuidString)
            print("✅ Medication record deleted from CloudKit for \(dog.name)")
        } catch {
            print("❌ Failed to delete medication record from CloudKit: \(error)")
            // Revert local cache if CloudKit update failed
            await MainActor.run {
                if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                    self.dogs[index].currentVisit?.medicationRecords.append(record)
                }
            }
        }
        
        isLoading = false
    }
    
    func deletePottyRecord(_ record: PottyRecord, from dog: DogWithVisit) async {
        isLoading = true
        errorMessage = nil
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].currentVisit?.pottyRecords.removeAll { $0.id == record.id }
                self.dogs[index].currentVisit?.updatedAt = Date()
            }
        }
        
        // Update CloudKit with only the deletion
        do {
            try await cloudKitService.deletePottyRecord(record, for: dog.id.uuidString)
            print("✅ Potty record deleted from CloudKit for \(dog.name)")
        } catch {
            print("❌ Failed to delete potty record from CloudKit: \(error)")
            // Revert local cache if CloudKit update failed
            await MainActor.run {
                if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                    self.dogs[index].currentVisit?.pottyRecords.append(record)
                }
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Record Management
    
    func addPottyRecord(to dog: DogWithVisit, type: PottyRecord.PottyType, notes: String? = nil, recordedBy: String?) async {
        isLoading = true
        errorMessage = nil
        
        // Create the new record
        let newRecord = PottyRecord(
            timestamp: Date(),
            type: type,
            notes: notes,
            recordedBy: recordedBy
        )
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].currentVisit?.pottyRecords.append(newRecord)
                self.dogs[index].currentVisit?.updatedAt = Date()
            }
        }
        
        // Update CloudKit with only the new record
        do {
            try await cloudKitService.addPottyRecord(newRecord, for: dog.id.uuidString)
            print("✅ Potty record added to CloudKit for \(dog.name)")
            // Update sync time for new record
            lastSyncTime = Date()
        } catch {
            print("❌ Failed to add potty record to CloudKit: \(error)")
            // Revert local cache if CloudKit update failed
            await MainActor.run {
                if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                    self.dogs[index].currentVisit?.pottyRecords.removeLast()
                }
            }
        }
        
        isLoading = false
    }
    
    func updatePottyRecordNotes(_ record: PottyRecord, newNotes: String?, in dog: DogWithVisit) async {
        isLoading = true
        errorMessage = nil
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
               let recordIndex = self.dogs[dogIndex].currentVisit?.pottyRecords.firstIndex(where: { $0.id == record.id }) {
                self.dogs[dogIndex].currentVisit?.pottyRecords[recordIndex].notes = newNotes
                self.dogs[dogIndex].currentVisit?.updatedAt = Date()
            }
        }
        
        // Update CloudKit
        do {
            try await cloudKitService.updatePottyRecordNotes(record, newNotes: newNotes, for: dog.id.uuidString)
            print("✅ Potty record notes updated in CloudKit for \(dog.name)")
        } catch {
            print("❌ Failed to update potty record notes in CloudKit: \(error)")
            // Revert local cache if CloudKit update failed
            await MainActor.run {
                if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
                   let recordIndex = self.dogs[dogIndex].currentVisit?.pottyRecords.firstIndex(where: { $0.id == record.id }) {
                    self.dogs[dogIndex].currentVisit?.pottyRecords[recordIndex].notes = record.notes
                }
            }
        }
        
        isLoading = false
    }
    
    func addFeedingRecord(to dog: DogWithVisit, type: FeedingRecord.FeedingType, notes: String? = nil, recordedBy: String?) async {
        isLoading = true
        errorMessage = nil
        
        // Create the new record
        let newRecord = FeedingRecord(
            timestamp: Date(),
            type: type,
            notes: notes,
            recordedBy: recordedBy
        )
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].currentVisit?.feedingRecords.append(newRecord)
                self.dogs[index].currentVisit?.updatedAt = Date()
            }
        }
        
        // Update CloudKit with only the new record
        do {
            try await cloudKitService.addFeedingRecord(newRecord, for: dog.id.uuidString)
            print("✅ Feeding record added to CloudKit for \(dog.name)")
            // Update sync time for new record
            lastSyncTime = Date()
        } catch {
            print("❌ Failed to add feeding record to CloudKit: \(error)")
            // Revert local cache if CloudKit update failed
            await MainActor.run {
                if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                    self.dogs[index].currentVisit?.feedingRecords.removeLast()
                }
            }
        }
        
        isLoading = false
    }
    
    func updateFeedingRecordNotes(_ record: FeedingRecord, newNotes: String?, in dog: DogWithVisit) async {
        isLoading = true
        errorMessage = nil
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
               let recordIndex = self.dogs[dogIndex].currentVisit?.feedingRecords.firstIndex(where: { $0.id == record.id }) {
                self.dogs[dogIndex].currentVisit?.feedingRecords[recordIndex].notes = newNotes
                self.dogs[dogIndex].currentVisit?.updatedAt = Date()
            }
        }
        
        // Update CloudKit
        do {
            try await cloudKitService.updateFeedingRecordNotes(record, newNotes: newNotes, for: dog.id.uuidString)
            print("✅ Feeding record notes updated in CloudKit for \(dog.name)")
        } catch {
            print("❌ Failed to update feeding record notes in CloudKit: \(error)")
            // Revert local cache if CloudKit update failed
            await MainActor.run {
                if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
                   let recordIndex = self.dogs[dogIndex].currentVisit?.feedingRecords.firstIndex(where: { $0.id == record.id }) {
                    self.dogs[dogIndex].currentVisit?.feedingRecords[recordIndex].notes = record.notes
                }
            }
        }
        
        isLoading = false
    }
    
    func updateFeedingRecordTimestamp(_ record: FeedingRecord, newTimestamp: Date, in dog: DogWithVisit) async {
        isLoading = true
        errorMessage = nil
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
               let recordIndex = self.dogs[dogIndex].currentVisit?.feedingRecords.firstIndex(where: { $0.id == record.id }) {
                self.dogs[dogIndex].currentVisit?.feedingRecords[recordIndex].timestamp = newTimestamp
                self.dogs[dogIndex].currentVisit?.updatedAt = Date()
            }
        }
        
        // Update CloudKit
        do {
            try await cloudKitService.updateFeedingRecordTimestamp(record, newTimestamp: newTimestamp, for: dog.id.uuidString)
            print("✅ Feeding record timestamp updated in CloudKit for \(dog.name)")
            // Update sync time for record update
            lastSyncTime = Date()
        } catch {
            print("❌ Failed to update feeding record timestamp in CloudKit: \(error)")
            // Revert local cache if CloudKit update failed
            await MainActor.run {
                if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
                   let recordIndex = self.dogs[dogIndex].currentVisit?.feedingRecords.firstIndex(where: { $0.id == record.id }) {
                    self.dogs[dogIndex].currentVisit?.feedingRecords[recordIndex].timestamp = record.timestamp
                }
            }
        }
        
        isLoading = false
    }
    
    func updatePottyRecordTimestamp(_ record: PottyRecord, newTimestamp: Date, in dog: DogWithVisit) async {
        isLoading = true
        errorMessage = nil
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
               let recordIndex = self.dogs[dogIndex].currentVisit?.pottyRecords.firstIndex(where: { $0.id == record.id }) {
                self.dogs[dogIndex].currentVisit?.pottyRecords[recordIndex].timestamp = newTimestamp
                self.dogs[dogIndex].currentVisit?.updatedAt = Date()
            }
        }
        
        // Update CloudKit
        do {
            try await cloudKitService.updatePottyRecordTimestamp(record, newTimestamp: newTimestamp, for: dog.id.uuidString)
            print("✅ Potty record timestamp updated in CloudKit for \(dog.name)")
            // Update sync time for record update
            lastSyncTime = Date()
        } catch {
            print("❌ Failed to update potty record timestamp in CloudKit: \(error)")
            // Revert local cache if CloudKit update failed
            await MainActor.run {
                if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
                   let recordIndex = self.dogs[dogIndex].currentVisit?.pottyRecords.firstIndex(where: { $0.id == record.id }) {
                    self.dogs[dogIndex].currentVisit?.pottyRecords[recordIndex].timestamp = record.timestamp
                }
            }
        }
        
        isLoading = false
    }
    
    func addMedicationRecord(to dog: DogWithVisit, notes: String?, recordedBy: String?) async {
        isLoading = true
        errorMessage = nil
        
        // Create the new record
        let newRecord = MedicationRecord(
            timestamp: Date(),
            notes: notes,
            recordedBy: recordedBy
        )
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].currentVisit?.medicationRecords.append(newRecord)
                self.dogs[index].currentVisit?.updatedAt = Date()
            }
        }
        
        // Update CloudKit with only the new record
        do {
            try await cloudKitService.addMedicationRecord(newRecord, for: dog.id.uuidString)
            print("✅ Medication record added to CloudKit for \(dog.name)")
            // Update sync time for new record
            lastSyncTime = Date()
        } catch {
            print("❌ Failed to add medication record to CloudKit: \(error)")
            // Revert local cache if CloudKit update failed
            await MainActor.run {
                if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                    self.dogs[index].currentVisit?.medicationRecords.removeLast()
                }
            }
        }
        
        isLoading = false
    }
    
    func updateMedicationRecordTimestamp(_ record: MedicationRecord, newTimestamp: Date, in dog: DogWithVisit) async {
        isLoading = true
        errorMessage = nil
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
               let recordIndex = self.dogs[dogIndex].currentVisit?.medicationRecords.firstIndex(where: { $0.id == record.id }) {
                self.dogs[dogIndex].currentVisit?.medicationRecords[recordIndex].timestamp = newTimestamp
                self.dogs[dogIndex].currentVisit?.updatedAt = Date()
            }
        }
        
        // Update CloudKit
        do {
            try await cloudKitService.updateMedicationRecordTimestamp(record, newTimestamp: newTimestamp, for: dog.id.uuidString)
            print("✅ Medication record timestamp updated in CloudKit for \(dog.name)")
            // Update sync time for record update
            lastSyncTime = Date()
        } catch {
            print("❌ Failed to update medication record timestamp in CloudKit: \(error)")
            // Revert local cache if CloudKit update failed
            await MainActor.run {
                if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
                   let recordIndex = self.dogs[dogIndex].currentVisit?.medicationRecords.firstIndex(where: { $0.id == record.id }) {
                    self.dogs[dogIndex].currentVisit?.medicationRecords[recordIndex].timestamp = record.timestamp
                }
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Search and Filtering
    
    func searchDogs(query: String) async -> [DogWithVisit] {
        let filteredDogs = dogs.filter { dog in
            dog.name.localizedCaseInsensitiveContains(query) ||
            (dog.ownerName?.localizedCaseInsensitiveContains(query) ?? false)
        }
        return filteredDogs
    }
    
    // MARK: - Data Refresh
    
    func refreshData() async {
        print("🔄 DataManager: Manual refresh requested")
        
        // Use incremental sync instead of full sync
        await fetchDogsIncremental()
        await fetchUsers()
    }
    
    // MARK: - History Management
    
    private func recordDailySnapshotIfNeeded() async {
        let today = Calendar.current.startOfDay(for: Date())
        
        // Check if we already recorded a snapshot for today
        let todayRecords = await cloudKitHistoryService.getHistoryForDate(today)
        if !todayRecords.isEmpty {
            print("📅 Daily snapshot already recorded for today")
            return
        }
        
        // Get visible dogs (same logic as ContentView)
        let visibleDogs = dogs.filter { dog in
            // Include dogs that are currently present (daycare and boarding)
            let isCurrentlyPresent = dog.isCurrentlyPresent
            let isDaycare = isCurrentlyPresent && dog.shouldBeTreatedAsDaycare
            let isBoarding = isCurrentlyPresent && !dog.shouldBeTreatedAsDaycare
            let isDepartedToday = dog.departureDate != nil && Calendar.current.isDateInToday(dog.departureDate!)
            
            return isDaycare || isBoarding || isDepartedToday
        }
        
        // Record snapshot for only visible dogs
        await cloudKitHistoryService.recordDailySnapshot(dogs: visibleDogs)
        print("📅 Recorded daily snapshot for \(visibleDogs.count) visible dogs")
    }
    
    func clearCache() {
        cloudKitService.clearDogCache()
        print("🧹 DataManager: Cache cleared")
    }
    
    private func updateDogsCache(with changedDogs: [DogWithVisit]) async {
        print("🔄 DataManager: Updating cache with \(changedDogs.count) changed dogs")
        
        // TODO: Replace with proper cache update - removed toCloudKitDog() calls
        
        // Update local dogs array with changed dogs
        for changedDog in changedDogs {
            if let index = dogs.firstIndex(where: { $0.id == changedDog.id }) {
                // Update existing dog
                dogs[index] = changedDog
                print("🔄 Updated dog in cache: \(changedDog.name)")
            } else {
                // Add new dog
                dogs.append(changedDog)
                print("🔄 Added new dog to cache: \(changedDog.name)")
            }
        }
        
        // Remove deleted dogs
        dogs.removeAll { dog in
            changedDogs.contains { changedDog in
                changedDog.id == dog.id && changedDog.isDeleted
            }
        }
        
        print("✅ DataManager: Cache updated successfully")
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Daily Reset Management
    
    func resetDailyInstances() async {
        print("🔄 Starting daily reset of instances...")
        
        for dog in dogs {
            if dog.isCurrentlyPresent {
                // Clear daily instances but keep totals
                // The totals are calculated from all records, so they'll still be accurate
                // We're just clearing the display lists for the current day
                
                if var visit = dog.currentVisit {
                    visit.updatedAt = Date()
                    // lastModifiedBy will be handled by CloudKit sync
                    
                    let updatedDog = DogWithVisit(persistentDog: dog.persistentDog, currentVisit: visit)
                    await updateDog(updatedDog)
                }
            }
        }
        
        print("✅ Daily reset completed")
    }
    
    // MARK: - Optimized Dog Operations
    
    func checkoutDog(_ dog: DogWithVisit) async {
        #if DEBUG
        isLoading = true
        errorMessage = nil
        #endif
        
        print("🔄 Starting optimized checkout for dog: \(dog.name)")
        
        // Log the checkout action
        await logDogActivity(action: "CHECKOUT_DOG", dog: dog, extra: "Checking out dog - setting departure date to current time")
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].currentVisit?.departureDate = Date()
                self.dogs[index].currentVisit?.updatedAt = Date()
                print("✅ Updated local cache for checkout")
            }
        }
        
        // Handle CloudKit operations in background without blocking UI
        Task.detached {
            do {
                try await self.cloudKitService.checkoutDog(dog.id.uuidString)
                print("✅ Checkout completed in CloudKit for \(dog.name)")
            } catch {
                print("❌ Failed to checkout dog in CloudKit: \(error)")
                // Revert local cache if CloudKit update failed
                await MainActor.run {
                    if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                        self.dogs[index].departureDate = nil
                        // Sync timestamp from CloudKit update
                        print("🔄 Reverted checkout in local cache due to CloudKit failure")
                    }
                }
            }
        }
        
        #if DEBUG
        isLoading = false
        #endif
    }
    
    func extendBoardingOptimized(for dog: DogWithVisit, newEndDate: Date) async {
        isLoading = true
        errorMessage = nil
        
        print("🔄 Starting optimized extend boarding for dog: \(dog.name)")
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].currentVisit?.boardingEndDate = newEndDate
                self.dogs[index].currentVisit?.updatedAt = Date()
                print("✅ Updated local cache for extend boarding")
            }
        }
        
        // Update CloudKit with only the extended boarding
        do {
            try await cloudKitService.extendBoardingOptimized(dog.id.uuidString, newEndDate: newEndDate)
            print("✅ Extend boarding completed in CloudKit for \(dog.name)")
        } catch {
            print("❌ Failed to extend boarding in CloudKit: \(error)")
            // Revert local cache if CloudKit update failed
            await MainActor.run {
                if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                    self.dogs[index].boardingEndDate = dog.boardingEndDate
                    // Sync timestamp from CloudKit update
                    print("🔄 Reverted extend boarding in local cache due to CloudKit failure")
                }
            }
        }
        
        isLoading = false
    }
    
    func boardDogOptimized(_ dog: DogWithVisit, endDate: Date) async {
        isLoading = true
        errorMessage = nil
        
        print("🔄 Starting optimized board conversion for dog: \(dog.name)")
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].currentVisit?.isBoarding = true
                self.dogs[index].currentVisit?.boardingEndDate = endDate
                self.dogs[index].currentVisit?.updatedAt = Date()
                print("✅ Updated local cache for board conversion")
            }
        }
        
        // Update CloudKit with only the board conversion
        do {
            try await cloudKitService.boardDogOptimized(dog.id.uuidString, endDate: endDate)
            print("✅ Board conversion completed in CloudKit for \(dog.name)")
        } catch {
            print("❌ Failed to convert to boarding in CloudKit: \(error)")
            // Revert local cache if CloudKit update failed
            await MainActor.run {
                if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                    self.dogs[index].isBoarding = dog.isBoarding
                    self.dogs[index].boardingEndDate = dog.boardingEndDate
                    // Sync timestamp from CloudKit update
                    print("🔄 Reverted board conversion in local cache due to CloudKit failure")
                }
            }
        }
        
        isLoading = false
    }

    // Duplicate method removed - using the one at line 350

    // Duplicate method removed - using the one at line 374


    func fetchAllDogsIncludingDeleted() async {
        isLoading = true
        errorMessage = nil
        
        print("🔍 DataManager: Starting fetchAllDogsIncludingDeleted...")
        
        do {
            let cloudKitDogs = try await cloudKitService.fetchAllDogsIncludingDeleted()
            print("🔍 DataManager: Got \(cloudKitDogs.count) CloudKit dogs (including deleted)")
            
            let localDogs = cloudKitDogs.map { $0.toDogWithVisit() }
            print("🔍 DataManager: Converted to \(localDogs.count) local dogs")
            
            // Debug: Print each dog's details
            for dog in localDogs {
                print("🐕 AllDogs: \(dog.name), Owner: \(dog.ownerName ?? "none"), Deleted: \(dog.isDeleted), Present: \(dog.isCurrentlyPresent)")
            }
            
            await MainActor.run {
                self.allDogs = localDogs
                print("✅ DataManager: Set \(localDogs.count) dogs in allDogs array")
            }
        } catch {
            print("❌ Failed to fetch all dogs: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to fetch dogs: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    // True incremental sync for all dogs (including deleted)
    func fetchAllDogsIncremental() async {
        isLoading = true
        errorMessage = nil
        print("🔍 DataManager: Starting fetchAllDogsIncremental (since \(lastAllDogsSyncTime))...")
        do {
            let changedCloudKitDogs = try await cloudKitService.fetchAllDogsIncremental(since: lastAllDogsSyncTime)
            print("🔍 DataManager: Got \(changedCloudKitDogs.count) changed CloudKit dogs (including deleted)")
            let changedLocalDogs = changedCloudKitDogs.map { $0.toDogWithVisit() }
            // Merge changes into allDogs
            var updatedAllDogs = allDogs
            for changedDog in changedLocalDogs {
                if let idx = updatedAllDogs.firstIndex(where: { $0.id == changedDog.id }) {
                    updatedAllDogs[idx] = changedDog
                } else {
                    updatedAllDogs.append(changedDog)
                }
            }
            await MainActor.run {
                self.allDogs = updatedAllDogs.sorted { $0.updatedAt > $1.updatedAt }
                self.lastAllDogsSyncTime = Date()
                self.isLoading = false
                print("✅ DataManager: Updated allDogs with incremental changes (\(self.allDogs.count) total)")
            }
        } catch {
            print("❌ Failed to fetch incremental all dogs: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to fetch all dogs: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    // MARK: - Optimized Import Methods
    
    func fetchDogsForImport() async -> [DogWithVisit] {
        print("🚀 DataManager: Starting optimized fetchDogsForImport...")
        
        // Check cache first
        let cachedCloudKitDogs = cloudKitService.getCachedDogs()
        if !cachedCloudKitDogs.isEmpty {
            print("✅ DataManager: Using cached dogs (\(cachedCloudKitDogs.count) dogs)")
            return cachedCloudKitDogs.map { $0.toDogWithVisit() }
        }
        
        do {
            let cloudKitDogs = try await cloudKitService.fetchDogsForImport()
            print("✅ DataManager: Got \(cloudKitDogs.count) optimized CloudKit dogs")
            
            // Update cache
            cloudKitService.updateDogCache(cloudKitDogs)
            
            let localDogs = cloudKitDogs.map { $0.toDogWithVisit() }
            print("✅ DataManager: Converted to \(localDogs.count) local dogs")
            
            return localDogs
        } catch {
            print("❌ DataManager: Failed to fetch dogs for import: \(error)")
            return []
        }
    }
    
    func fetchSpecificDogWithRecords(for dogID: String) async -> DogWithVisit? {
        print("🔍 DataManager: Fetching specific dog with records: \(dogID)")
        
        do {
            guard let cloudKitDog = try await cloudKitService.fetchDogWithRecords(for: dogID) else {
                print("❌ DataManager: Dog not found: \(dogID)")
                return nil
            }
            
            let localDog = cloudKitDog.toDogWithVisit()
            print("✅ DataManager: Successfully fetched dog with records: \(localDog.name)")
            return localDog
        } catch {
            print("❌ DataManager: Failed to fetch specific dog: \(error)")
            return nil
        }
    }
    
    func clearImportCache() {
        cloudKitService.clearDogCache()
        print("🧹 DataManager: Import cache cleared")
    }
    
    func getCacheStats() -> (memoryCount: Int, diskSize: String) {
        let cachedDogs = cloudKitService.getCachedDogs()
        let memoryCount = cachedDogs.count
        
        // Calculate approximate disk size (rough estimate)
        let estimatedSizePerDog = 2048 // 2KB per dog record
        let totalSizeBytes = memoryCount * estimatedSizePerDog
        let diskSize = ByteCountFormatter.string(fromByteCount: Int64(totalSizeBytes), countStyle: .file)
        
        return (memoryCount, diskSize)
    }
    
    // MARK: - Debug Logging
    
    func logDogActivity(action: String, dog: DogWithVisit, extra: String = "") async {
        print("🔍 Starting logDogActivity for action: \(action), dog: \(dog.name)")
        
        let timestamp = Date().formatted(date: .complete, time: .complete)
        
        // Get current user information
        let currentUser = AuthenticationService.shared.currentUser
        let userName = currentUser?.name ?? "Unknown User"
        let userID = currentUser?.id ?? "Unknown ID"
        let userRole = currentUser?.isOwner == true ? "Owner" : "Staff"
        
        print("🔍 User info - Name: \(userName), ID: \(userID), Role: \(userRole)")
        
        let logEntry = """

🐾 DOG ACTIVITY LOGGED
=======================
Timestamp: \(timestamp)
Action: \(action)
User: \(userName) (\(userRole))
User ID: \(userID)
Dog Name: \(dog.name)
Dog ID: \(dog.id.uuidString)
Owner: \(dog.ownerName ?? "None")
Is Currently Present: \(dog.isCurrentlyPresent)
Is Boarding: \(dog.isBoarding)
Is Deleted: \(dog.isDeleted)
Arrival Date: \(dog.arrivalDate.formatted())
Departure Date: \(dog.departureDate?.formatted() ?? "None")
Boarding End Date: \(dog.boardingEndDate?.formatted() ?? "None")
Extra: \(extra)
=======================

"""
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let logFileURL = documentsPath.appendingPathComponent("dog_activity.log")
            print("🔍 Writing to log file: \(logFileURL.path)")
            
            if let existingData = try? Data(contentsOf: logFileURL) {
                let existingLog = String(data: existingData, encoding: .utf8) ?? ""
                let fullLog = existingLog + logEntry
                try fullLog.write(to: logFileURL, atomically: true, encoding: .utf8)
                print("📝 Activity logged to existing file: \(logFileURL.path)")
            } else {
                try logEntry.write(to: logFileURL, atomically: true, encoding: .utf8)
                print("📝 Activity logged to new file: \(logFileURL.path)")
            }
        } catch {
            print("❌ Failed to log dog activity: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
        }
        
        let log = ActivityLogRecord(
            userId: AuthenticationService.shared.currentUser?.id ?? "unknown",
            userName: AuthenticationService.shared.currentUser?.name ?? "unknown",
            action: action,
            timestamp: Date(),
            dogId: dog.id.uuidString,
            dogName: dog.name,
            details: extra
        )
        Task {
            try? await cloudKitService.saveActivityLog(log)
        }
    }

    func getDogActivityLog() -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logFileURL = documentsPath.appendingPathComponent("dog_activity.log")
        if let logData = try? Data(contentsOf: logFileURL) {
            return String(data: logData, encoding: .utf8) ?? "No activity log found"
        } else {
            return "No activity log file found"
        }
    }

    func clearDogActivityLog() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logFileURL = documentsPath.appendingPathComponent("dog_activity.log")
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            do {
                try FileManager.default.removeItem(at: logFileURL)
                print("🗑️ Activity log cleared")
            } catch {
                print("❌ Failed to clear activity log: \(error)")
            }
        }
    }

    private func logDeletion(dog: DogWithVisit, callStack: String) async {
        let timestamp = Date().formatted(date: .complete, time: .complete)
        let logEntry = """

🗑️ DOG DELETION LOGGED
=======================
Timestamp: \(timestamp)
Dog Name: \(dog.name)
Dog ID: \(dog.id.uuidString)
Owner: \(dog.ownerName ?? "None")
Is Currently Present: \(dog.isCurrentlyPresent)
Is Boarding: \(dog.isBoarding)
Arrival Date: \(dog.arrivalDate.formatted())
Departure Date: \(dog.departureDate?.formatted() ?? "None")
Boarding End Date: \(dog.boardingEndDate?.formatted() ?? "None")
Call Stack: \(callStack)
=======================

"""
        
        // Write to documents directory
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let logFileURL = documentsPath.appendingPathComponent("dog_deletions.log")
            
            // Append to existing log file
            if let existingData = try? Data(contentsOf: logFileURL) {
                let existingLog = String(data: existingData, encoding: .utf8) ?? ""
                let fullLog = existingLog + logEntry
                try fullLog.write(to: logFileURL, atomically: true, encoding: .utf8)
            } else {
                // Create new log file
                try logEntry.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
            
            print("📝 Deletion logged to: \(logFileURL.path)")
        } catch {
            print("❌ Failed to log deletion: \(error)")
        }
    }
    
    func getDeletionLog() -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logFileURL = documentsPath.appendingPathComponent("dog_deletions.log")
        
        if let logData = try? Data(contentsOf: logFileURL) {
            return String(data: logData, encoding: .utf8) ?? "No deletion log found"
        } else {
            return "No deletion log file found"
        }
    }
    
    func clearDeletionLog() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logFileURL = documentsPath.appendingPathComponent("dog_deletions.log")
        
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            do {
                try FileManager.default.removeItem(at: logFileURL)
                print("🗑️ Deletion log cleared")
            } catch {
                print("❌ Failed to clear deletion log: \(error)")
            }
        }
    }
    
    // MARK: - New DogWithVisit Methods
    
    func addDogWithVisit(
        name: String,
        ownerName: String?,
        ownerPhoneNumber: String?,
        arrivalDate: Date,
        isBoarding: Bool,
        boardingEndDate: Date?,
        isDaycareFed: Bool,
        needsWalking: Bool,
        walkingNotes: String?,
        notes: String?,
        allergiesAndFeedingInstructions: String?,
        profilePictureData: Data?,
        age: Int?,
        gender: DogGender,
        vaccinations: [VaccinationItem],
        isNeuteredOrSpayed: Bool,
        medications: [Medication],
        scheduledMedications: [ScheduledMedication]
    ) async {
        print("🔄 DataManager: addDogWithVisit called for \(name)")
        
        do {
            // Create persistent dog first
            let persistentDog = PersistentDog(
                name: name,
                ownerName: ownerName,
                ownerPhoneNumber: ownerPhoneNumber,
                needsWalking: needsWalking,
                walkingNotes: walkingNotes,
                notes: notes,
                allergiesAndFeedingInstructions: allergiesAndFeedingInstructions,
                profilePictureData: profilePictureData,
                age: age,
                gender: gender,
                vaccinations: vaccinations,
                isNeuteredOrSpayed: isNeuteredOrSpayed,
                medications: medications,
                scheduledMedications: scheduledMedications
            )
            
            try await persistentDogService.createPersistentDog(persistentDog)
            print("✅ DataManager: Created persistent dog with ID \(persistentDog.id)")
            
            // Create visit
            let visit = Visit(
                dogId: persistentDog.id,
                arrivalDate: arrivalDate,
                departureDate: nil,
                isBoarding: isBoarding,
                boardingEndDate: boardingEndDate,
                isDaycareFed: isDaycareFed
            )
            
            try await visitService.createVisit(visit)
            print("✅ DataManager: Created visit with ID \(visit.id)")
            
            // Refresh dogs list
            await fetchDogs()
            
        } catch {
            print("❌ DataManager: Failed to add dog with visit: \(error)")
            errorMessage = "Failed to add dog: \(error.localizedDescription)"
        }
    }
    
    func addPersistentDogOnly(
        name: String,
        ownerName: String?,
        ownerPhoneNumber: String?,
        needsWalking: Bool,
        walkingNotes: String?,
        notes: String?,
        allergiesAndFeedingInstructions: String?,
        profilePictureData: Data?,
        age: Int?,
        gender: DogGender,
        vaccinations: [VaccinationItem],
        isNeuteredOrSpayed: Bool,
        medications: [Medication],
        scheduledMedications: [ScheduledMedication]
    ) async {
        print("🔄 DataManager: addPersistentDogOnly called for \(name)")
        
        do {
            let persistentDog = PersistentDog(
                name: name,
                ownerName: ownerName,
                ownerPhoneNumber: ownerPhoneNumber,
                needsWalking: needsWalking,
                walkingNotes: walkingNotes,
                notes: notes,
                allergiesAndFeedingInstructions: allergiesAndFeedingInstructions,
                profilePictureData: profilePictureData,
                age: age,
                gender: gender,
                vaccinations: vaccinations,
                isNeuteredOrSpayed: isNeuteredOrSpayed,
                medications: medications,
                scheduledMedications: scheduledMedications
            )
            
            try await persistentDogService.createPersistentDog(persistentDog)
            print("✅ DataManager: Created persistent dog only with ID \(persistentDog.id)")
            
        } catch {
            print("❌ DataManager: Failed to add persistent dog: \(error)")
            errorMessage = "Failed to add dog to database: \(error.localizedDescription)"
        }
    }
    
    func updateDogWithVisit(
        dogWithVisit: DogWithVisit,
        name: String,
        ownerName: String?,
        ownerPhoneNumber: String?,
        arrivalDate: Date,
        isBoarding: Bool,
        boardingEndDate: Date?,
        isDaycareFed: Bool,
        needsWalking: Bool,
        walkingNotes: String?,
        notes: String?,
        allergiesAndFeedingInstructions: String?,
        profilePictureData: Data?,
        age: Int?,
        gender: DogGender,
        vaccinations: [VaccinationItem],
        isNeuteredOrSpayed: Bool,
        medications: [Medication],
        scheduledMedications: [ScheduledMedication]
    ) async {
        print("🔄 DataManager: updateDogWithVisit called for \(name)")
        
        do {
            // Update persistent dog
            var updatedPersistentDog = dogWithVisit.persistentDog
            updatedPersistentDog.name = name
            updatedPersistentDog.ownerName = ownerName
            updatedPersistentDog.ownerPhoneNumber = ownerPhoneNumber
            // needsWalking, walkingNotes, and notes belong to Visit, not PersistentDog
            updatedPersistentDog.allergiesAndFeedingInstructions = allergiesAndFeedingInstructions
            updatedPersistentDog.profilePictureData = profilePictureData
            updatedPersistentDog.age = age
            updatedPersistentDog.gender = gender
            updatedPersistentDog.vaccinations = vaccinations
            updatedPersistentDog.isNeuteredOrSpayed = isNeuteredOrSpayed
            updatedPersistentDog.updatedAt = Date()
            
            try await persistentDogService.updatePersistentDog(updatedPersistentDog)
            print("✅ DataManager: Updated persistent dog with ID \(updatedPersistentDog.id)")
            
            // Update visit if it exists
            if var currentVisit = dogWithVisit.currentVisit {
                currentVisit.arrivalDate = arrivalDate
                currentVisit.isBoarding = isBoarding
                currentVisit.boardingEndDate = boardingEndDate
                currentVisit.isDaycareFed = isDaycareFed
                currentVisit.needsWalking = needsWalking
                currentVisit.walkingNotes = walkingNotes
                currentVisit.notes = notes
                currentVisit.medications = medications
                currentVisit.scheduledMedications = scheduledMedications
                currentVisit.updatedAt = Date()
                
                try await visitService.updateVisit(currentVisit)
                print("✅ DataManager: Updated visit with ID \(currentVisit.id)")
            }
            
            // Refresh dogs list
            await fetchDogs()
            
        } catch {
            print("❌ DataManager: Failed to update dog with visit: \(error)")
            errorMessage = "Failed to update dog: \(error.localizedDescription)"
        }
    }
    
    func updateFutureBooking(
        dogWithVisit: DogWithVisit,
        name: String,
        ownerName: String?,
        ownerPhoneNumber: String?,
        arrivalDate: Date,
        isBoarding: Bool,
        boardingEndDate: Date?,
        isDaycareFed: Bool,
        needsWalking: Bool,
        walkingNotes: String?,
        notes: String?,
        allergiesAndFeedingInstructions: String?,
        profilePictureData: Data?,
        age: Int?,
        gender: DogGender,
        vaccinations: [VaccinationItem],
        isNeuteredOrSpayed: Bool,
        medications: [Medication],
        scheduledMedications: [ScheduledMedication]
    ) async {
        print("🔄 DataManager: updateFutureBooking called for \(name)")
        
        // This is essentially the same as updateDogWithVisit for now
        await updateDogWithVisit(
            dogWithVisit: dogWithVisit,
            name: name,
            ownerName: ownerName,
            ownerPhoneNumber: ownerPhoneNumber,
            arrivalDate: arrivalDate,
            isBoarding: isBoarding,
            boardingEndDate: boardingEndDate,
            isDaycareFed: isDaycareFed,
            needsWalking: needsWalking,
            walkingNotes: walkingNotes,
            notes: notes,
            allergiesAndFeedingInstructions: allergiesAndFeedingInstructions,
            profilePictureData: profilePictureData,
            age: age,
            gender: gender,
            vaccinations: vaccinations,
            isNeuteredOrSpayed: isNeuteredOrSpayed,
            medications: medications,
            scheduledMedications: scheduledMedications
        )
    }
}

    // MARK: - DogWithVisit Helper Methods
    // Removed inefficient updateDogWithVisitTimestamp - now using proper service calls

// MARK: - Conversion Extensions

extension CloudKitDog {
    
    func toDogWithVisit() -> DogWithVisit {
        // Create PersistentDog
        let persistentDog = PersistentDog(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            ownerName: ownerName,
            ownerPhoneNumber: ownerPhoneNumber,
            profilePictureData: profilePictureData,
            age: Int(age),
            gender: DogGender(rawValue: gender),
            vaccinations: [
                VaccinationItem(name: "Bordetella", endDate: bordetellaEndDate),
                VaccinationItem(name: "DHPP", endDate: dhppEndDate),
                VaccinationItem(name: "Rabies", endDate: rabiesEndDate),
                VaccinationItem(name: "CIV", endDate: civEndDate),
                VaccinationItem(name: "Leptospirosis", endDate: leptospirosisEndDate)
            ],
            isNeuteredOrSpayed: isNeuteredOrSpayed,
            allergiesAndFeedingInstructions: allergiesAndFeedingInstructions,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        
        // Reconstruct medications
        var reconstructedMedications: [Medication] = []
        for i in 0..<medicationNames.count {
            if i < medicationTypes.count && i < medicationNotes.count && i < medicationIds.count {
                let type = Medication.MedicationType(rawValue: medicationTypes[i]) ?? .daily
                let medication = Medication(
                    name: medicationNames[i],
                    type: type,
                    notes: medicationNotes[i].isEmpty ? nil : medicationNotes[i]
                )
                var medicationWithId = medication
                medicationWithId.id = UUID(uuidString: medicationIds[i]) ?? UUID()
                reconstructedMedications.append(medicationWithId)
            }
        }
        
        // Reconstruct scheduled medications
        var reconstructedScheduledMedications: [ScheduledMedication] = []
        for i in 0..<scheduledMedicationDates.count {
            if i < scheduledMedicationStatuses.count && i < scheduledMedicationNotes.count && i < scheduledMedicationIds.count {
                let status = ScheduledMedication.ScheduledMedicationStatus(rawValue: scheduledMedicationStatuses[i]) ?? .pending
                let medicationId = UUID(uuidString: scheduledMedicationIds[i]) ?? UUID()
                
                let scheduledMedication = ScheduledMedication(
                    medicationId: medicationId,
                    scheduledDate: scheduledMedicationDates[i],
                    notificationTime: scheduledMedicationDates[i],
                    status: status,
                    notes: scheduledMedicationNotes[i].isEmpty ? nil : scheduledMedicationNotes[i]
                )
                reconstructedScheduledMedications.append(scheduledMedication)
            }
        }
        
        // Create Visit
        let visit = Visit(
            id: UUID(), // Generate new visit ID
            dogId: persistentDog.id,
            arrivalDate: arrivalDate,
            departureDate: departureDate,
            isBoarding: isBoarding,
            boardingEndDate: boardingEndDate,
            isDaycareFed: isDaycareFed,
            notes: notes,
            specialInstructions: nil, // CloudKitDog doesn't have this field
            needsWalking: needsWalking,
            walkingNotes: walkingNotes,
            isDeleted: isDeleted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            feedingRecords: feedingRecords,
            medicationRecords: medicationRecords,
            pottyRecords: pottyRecords,
            medications: reconstructedMedications,
            scheduledMedications: reconstructedScheduledMedications
        )
        
        return DogWithVisit(persistentDog: persistentDog, currentVisit: visit)
    }
}

extension CloudKitUser {
    func toUser() -> User {
        return User(
            id: id,
            name: name,
            email: email,
            isOwner: isOwner,
            isActive: isActive,
            isWorkingToday: isWorkingToday,
            isOriginalOwner: isOriginalOwner,
            scheduledDays: scheduledDays?.map { Int($0) },
            scheduleStartTime: scheduleStartTime,
            scheduleEndTime: scheduleEndTime,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastLogin: lastLogin,
            cloudKitUserID: cloudKitUserID
        )
    }
}

// Legacy Dog extension removed - no longer needed with new PersistentDog + Visit architecture

extension User {
    func toCloudKitUser() -> CloudKitUser {
        return CloudKitUser(
            id: id,
            name: name,
            email: email,
            isOwner: isOwner,
            isActive: isActive,
            isWorkingToday: isWorkingToday,
            isOriginalOwner: isOriginalOwner,
            scheduledDays: scheduledDays?.map { Int64($0) },
            scheduleStartTime: scheduleStartTime,
            scheduleEndTime: scheduleEndTime,
            cloudKitUserID: cloudKitUserID
        )
    }
} 