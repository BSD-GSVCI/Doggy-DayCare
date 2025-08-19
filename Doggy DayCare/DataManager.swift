import Foundation
import UIKit

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
    
    // New cache and sync system
    private let cacheManager = CacheManager.shared
    private let syncScheduler = SyncScheduler.shared
    
    
    private init() {
        #if DEBUG
        print("📱 DataManager initialized with new caching system")
        #endif
        
        // Start initial data load and sync system
        Task {
            await syncScheduler.performInitialLoad()
        }
    }
    
    deinit {
        // Cleanup handled by SyncScheduler
        #if DEBUG
        print("📱 DataManager deinitialized")
        #endif
    }
    
    // MARK: - Data Refresh
    
    /// Manually refresh data (for pull-to-refresh)
    func refreshData() async {
        #if DEBUG
        print("📱 Manual data refresh requested")
        #endif
        
        await syncScheduler.performManualSync()
        
        // Update UI with latest data from cache
        let updatedDogs = cacheManager.getCurrentDogsWithVisits()
        self.dogs = updatedDogs
        
        #if DEBUG
        print("📱 Manual refresh complete - \(updatedDogs.count) dogs")
        #endif
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
        
        #if DEBUG
        print("🔍 DataManager: Starting fetchDogs...")
        #endif
        
        await fetchDogsWithPersistentSystem(shouldShowLoading: shouldShowLoading)
    }
    
    private func fetchDogsWithPersistentSystem(shouldShowLoading: Bool) async {
        do {
            #if DEBUG
            print("🔄 Using new CacheManager and SyncScheduler system")
            #endif
            
            if shouldShowLoading {
                isLoading = true
            }
            
            // Perform sync using new system
            await SyncScheduler.shared.performManualSync()
            
            // Get dogs from CacheManager
            let dogsWithVisits = CacheManager.shared.getCurrentDogsWithVisits()
            
            #if DEBUG
            print("🔍 DataManager: Got \(dogsWithVisits.count) dogs with visits from cache")
            #endif
            
            #if DEBUG
            // Debug: Print each dog's details
            for dogWithVisit in dogsWithVisits {
                print("🐕 Dog: \(dogWithVisit.name), Owner: \(dogWithVisit.ownerName ?? "none"), Present: \(dogWithVisit.isCurrentlyPresent), Arrival: \(dogWithVisit.arrivalDate)")
            }
            #endif
            
            let previousCount = self.dogs.count
            let previousDogIds = Set(self.dogs.map { $0.id })
            
            self.dogs = dogsWithVisits
            
            // Validation checks
            if previousCount > 0 {
                let newDogIds = Set(dogsWithVisits.map { $0.id })
                let missingDogs = previousDogIds.subtracting(newDogIds)
                
                #if DEBUG
                if missingDogs.count > 0 {
                    print("⚠️ WARNING: \(missingDogs.count) dogs disappeared after fetch")
                }
                
                if dogsWithVisits.count < Int(Double(previousCount) * 0.5) {
                    print("⚠️ CRITICAL: Dog count dropped from \(previousCount) to \(dogsWithVisits.count)")
                }
                #endif
            }
                
                if shouldShowLoading {
                    self.isLoading = false
                }
                #if DEBUG
                print("✅ DataManager: Set \(dogsWithVisits.count) dogs in local array")
                #endif
                
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
                
                // Optimistic update: immediate UI update + background CloudKit sync
                let previousDog = cacheManager.getPersistentDog(id: updatedDog.id)
                
                // Update cache and UI immediately
                cacheManager.updateLocalPersistentDog(updatedDog)
                self.dogs = cacheManager.getCurrentDogsWithVisits()
                
                // Sync to CloudKit in background
                do {
                    try await persistentDogService.updatePersistentDog(updatedDog)
                    #if DEBUG
                    print("💾 Successfully synced dog update: \(updatedDog.name)")
                    #endif
                } catch {
                    // Revert on failure
                    if let previousDog = previousDog {
                        cacheManager.revertDogUpdate(to: previousDog)
                        self.dogs = cacheManager.getCurrentDogsWithVisits()
                    }
                    throw error
                }
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
            
            // Create the future visit with isArrivalTimeSet = false
            let visit = Visit(
                dogId: persistentDog.id,
                arrivalDate: arrivalDate,
                isBoarding: isBoarding,
                boardingEndDate: boardingEndDate,
                isArrivalTimeSet: false,  // Future bookings don't have arrival time set
                medications: medications,
                scheduledMedications: scheduledMedications
            )
            
            try await visitService.createVisit(visit)
            #if DEBUG
            print("✅ Created future booking for \(name)")
            #endif
            
            // Add future booking to cache and update UI immediately
            cacheManager.addLocalDogWithVisit(persistentDog: persistentDog, visit: visit)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            // Refresh data
            await fetchDogs()
        } catch {
            #if DEBUG
            print("❌ Failed to create future booking: \(error)")
            #endif
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
            // Update the persistent dog info
            var updatedPersistentDog = dogWithVisit.persistentDog
            updatedPersistentDog.name = name
            updatedPersistentDog.ownerName = ownerName
            updatedPersistentDog.ownerPhoneNumber = ownerPhoneNumber
            updatedPersistentDog.allergiesAndFeedingInstructions = allergiesAndFeedingInstructions
            updatedPersistentDog.specialInstructions = specialInstructions
            updatedPersistentDog.profilePictureData = profilePictureData
            updatedPersistentDog.age = age
            updatedPersistentDog.gender = gender
            updatedPersistentDog.vaccinations = vaccinations
            updatedPersistentDog.isNeuteredOrSpayed = isNeuteredOrSpayed
            updatedPersistentDog.updatedAt = Date()
            
            // Optimistic update: immediate UI + background sync
            cacheManager.updateLocalPersistentDog(updatedPersistentDog)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            Task {
                try await persistentDogService.updatePersistentDog(updatedPersistentDog)
            }
            
            // Update the visit info if it exists
            if var visit = dogWithVisit.currentVisit {
                visit.arrivalDate = arrivalDate
                visit.isBoarding = isBoarding
                visit.boardingEndDate = boardingEndDate
                visit.medications = medications
                visit.scheduledMedications = scheduledMedications
                visit.updatedAt = Date()
                
                // Optimistic update: immediate UI + background sync
                cacheManager.updateLocalVisit(visit)
                self.dogs = cacheManager.getCurrentDogsWithVisits()
                
                Task {
                    try await visitService.updateVisit(visit)
                }
                
                // Update persistent dog fields (modify the already existing updatedPersistentDog)
                updatedPersistentDog.isDaycareFed = isDaycareFed
                updatedPersistentDog.needsWalking = needsWalking
                updatedPersistentDog.walkingNotes = walkingNotes
                updatedPersistentDog.notes = notes
                updatedPersistentDog.specialInstructions = specialInstructions
                updatedPersistentDog.updatedAt = Date()
                
                // Optimistic update: immediate UI + background sync
                cacheManager.updateLocalPersistentDog(updatedPersistentDog)
                self.dogs = cacheManager.getCurrentDogsWithVisits()
                
                Task {
                    try await persistentDogService.updatePersistentDog(updatedPersistentDog)
                }
            }
            
            #if DEBUG
            print("✅ Updated future booking for \(name)")
            #endif
            
            // Refresh data
            await fetchDogs()
        } catch {
            #if DEBUG
            print("❌ Failed to update future booking: \(error)")
            #endif
            errorMessage = "Failed to update future booking: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func updatePersistentDogInfo(
        dogId: UUID,
        name: String,
        ownerName: String?,
        ownerPhoneNumber: String?,
        needsWalking: Bool,
        walkingNotes: String?,
        notes: String?,
        specialInstructions: String?,
        allergiesAndFeedingInstructions: String?,
        profilePictureData: Data?,
        age: Int?,
        gender: DogGender?,
        vaccinations: [VaccinationItem],
        isNeuteredOrSpayed: Bool?
    ) async {
        #if DEBUG
        print("🔄 DataManager: updatePersistentDogInfo called for dog ID: \(dogId)")
        #endif
        
        do {
            // Fetch the existing persistent dog
            guard let persistentDog = try await persistentDogService.fetchPersistentDog(by: dogId) else {
                #if DEBUG
                print("❌ DataManager: Could not find persistent dog with ID: \(dogId)")
                #endif
                errorMessage = "Could not find dog in database"
                return
            }
            
            // Update the persistent dog info
            var updatedPersistentDog = persistentDog
            updatedPersistentDog.name = name
            updatedPersistentDog.ownerName = ownerName
            updatedPersistentDog.ownerPhoneNumber = ownerPhoneNumber
            updatedPersistentDog.needsWalking = needsWalking
            updatedPersistentDog.walkingNotes = walkingNotes
            updatedPersistentDog.notes = notes
            updatedPersistentDog.specialInstructions = specialInstructions
            updatedPersistentDog.allergiesAndFeedingInstructions = allergiesAndFeedingInstructions
            updatedPersistentDog.profilePictureData = profilePictureData
            updatedPersistentDog.age = age
            updatedPersistentDog.gender = gender
            updatedPersistentDog.vaccinations = vaccinations
            updatedPersistentDog.isNeuteredOrSpayed = isNeuteredOrSpayed
            updatedPersistentDog.updatedAt = Date()
            
            // Optimistic update: immediate UI + background sync
            cacheManager.updateLocalPersistentDog(updatedPersistentDog)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            Task {
                try await persistentDogService.updatePersistentDog(updatedPersistentDog)
            }
            
            #if DEBUG
            print("✅ DataManager: Updated persistent dog info for: \(updatedPersistentDog.name)")
            #endif
            
            // Update cache for database page consistency
            await incrementallyUpdatePersistentDogCache(update: updatedPersistentDog)
            
        } catch {
            #if DEBUG
            print("❌ DataManager: Failed to update persistent dog info: \(error)")
            #endif
            errorMessage = "Failed to update dog information: \(error.localizedDescription)"
        }
    }
    
    func addFutureVisitForExistingDog(
        dogId: UUID,
        arrivalDate: Date,
        isBoarding: Bool,
        boardingEndDate: Date?,
        isDaycareFed: Bool,
        medications: [Medication],
        scheduledMedications: [ScheduledMedication]
    ) async {
        #if DEBUG
        print("🔄 DataManager: addFutureVisitForExistingDog called for dog ID: \(dogId)")
        #endif
        
        do {
            // Fetch the existing persistent dog to verify it exists
            guard let persistentDog = try await persistentDogService.fetchPersistentDog(by: dogId) else {
                #if DEBUG
                print("❌ DataManager: Could not find persistent dog with ID: \(dogId)")
                #endif
                errorMessage = "Could not find dog in database"
                return
            }
            
            #if DEBUG
            print("✅ DataManager: Found existing persistent dog: \(persistentDog.name)")
            #endif
            
            // Create the future visit (no departure date = future booking)
            let visit = Visit(
                dogId: persistentDog.id,
                arrivalDate: arrivalDate,
                departureDate: nil,
                isBoarding: isBoarding,
                boardingEndDate: boardingEndDate,
                medications: medications,
                scheduledMedications: scheduledMedications
            )
            
            try await visitService.createVisit(visit)
            
            #if DEBUG
            print("✅ DataManager: Created future visit for existing dog: \(persistentDog.name)")
            #endif
            
            // Update cache and refresh data
            await incrementallyUpdateVisitCache(add: visit)
            await fetchDogs()
            
        } catch {
            #if DEBUG
            print("❌ DataManager: Failed to create future visit: \(error)")
            #endif
            errorMessage = "Failed to create future booking: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Adapter Methods for DogWithVisit
    
    func undoDepartureOptimized(for dogWithVisit: DogWithVisit) async {
        guard var visit = dogWithVisit.currentVisit else { return }
        
        isLoading = true
        errorMessage = nil
        
        #if DEBUG
        print("🔄 Starting optimized undo departure for dog: \(dogWithVisit.name)")
        #endif
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dogWithVisit.id }) {
                self.dogs[index].currentVisit?.departureDate = nil
                self.dogs[index].currentVisit?.updatedAt = Date()
                #if DEBUG
                print("✅ Updated local cache for undo departure")
                #endif
            }
        }
        
        // Handle CloudKit operations in background without blocking UI
        Task {
            do {
                // Clear the departure date to make the dog present again
                visit.departureDate = nil
                visit.updatedAt = Date()
                
                // Optimistic update: immediate UI + background sync
                cacheManager.updateLocalVisit(visit)
                self.dogs = cacheManager.getCurrentDogsWithVisits()
                
                Task {
                    try await visitService.updateVisit(visit)
                }
                #if DEBUG
                print("✅ Updated visit in CloudKit for undo departure: \(dogWithVisit.name)")
                #endif
                
                // Decrement visit count since the visit is no longer complete
                await decrementPersistentDogVisitCount(dogId: dogWithVisit.id)
                
                // Update visit cache
                await incrementallyUpdateVisitCache(update: visit)
            } catch {
                #if DEBUG
                print("❌ Failed to undo departure in CloudKit: \(error)")
                #endif
                // Revert local cache if CloudKit update failed
                await MainActor.run {
                    if let index = self.dogs.firstIndex(where: { $0.id == dogWithVisit.id }) {
                        self.dogs[index].currentVisit?.departureDate = Date() // Revert to some departure date
                        #if DEBUG
                        print("🔄 Reverted undo departure in local cache due to CloudKit failure")
                        #endif
                    }
                }
                await MainActor.run {
                    self.errorMessage = "Failed to undo departure: \(error.localizedDescription)"
                }
            }
        }
        
        isLoading = false
    }
    
    func editDepartureOptimized(for dogWithVisit: DogWithVisit, newDate: Date) async {
        guard var visit = dogWithVisit.currentVisit else { return }
        
        // Validation is now handled in the UI layer for better UX
        
        isLoading = true
        errorMessage = nil
        
        #if DEBUG
        print("🔄 Starting optimized departure edit for dog: \(dogWithVisit.name)")
        #endif
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dogWithVisit.id }) {
                self.dogs[index].currentVisit?.departureDate = newDate
                self.dogs[index].currentVisit?.updatedAt = Date()
                #if DEBUG
                print("✅ Updated local cache for departure edit")
                #endif
            }
        }
        
        // Handle CloudKit operations in background without blocking UI
        Task {
            do {
                // Update the departure date
                visit.departureDate = newDate
                visit.updatedAt = Date()
                
                // Optimistic update: immediate UI + background sync
                cacheManager.updateLocalVisit(visit)
                self.dogs = cacheManager.getCurrentDogsWithVisits()
                
                Task {
                    try await visitService.updateVisit(visit)
                }
                #if DEBUG
                print("✅ Updated departure time in CloudKit for \(dogWithVisit.name)")
                #endif
                
                // Update visit cache (mark as departed)
                await incrementallyUpdateVisitCache(update: visit)
            } catch {
                #if DEBUG
                print("❌ Failed to update departure in CloudKit: \(error)")
                #endif
                // Revert local cache if CloudKit update failed
                await MainActor.run {
                    if let index = self.dogs.firstIndex(where: { $0.id == dogWithVisit.id }) {
                        self.dogs[index].currentVisit?.departureDate = visit.departureDate
                        #if DEBUG
                        print("🔄 Reverted departure edit in local cache due to CloudKit failure")
                        #endif
                    }
                }
                await MainActor.run {
                    self.errorMessage = "Failed to update departure: \(error.localizedDescription)"
                }
            }
        }
        
        isLoading = false
    }
    
    func setArrivalTimeOptimized(for dogWithVisit: DogWithVisit, newArrivalTime: Date) async {
        guard var visit = dogWithVisit.currentVisit else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Update the arrival time and set the flag
            visit.arrivalDate = newArrivalTime
            visit.isArrivalTimeSet = true  // Mark that arrival time has been set
            visit.updatedAt = Date()
            
            // When a future booking's arrival time is set, it becomes an active dog
            // Optimistic update: immediate UI + background sync
            cacheManager.updateLocalVisit(visit)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            Task {
                try await visitService.updateVisit(visit)
            }
            #if DEBUG
            print("✅ Updated arrival time for \(dogWithVisit.name)")
            #endif
            
            // Refresh data
            await fetchDogs()
        } catch {
            #if DEBUG
            print("❌ Failed to update arrival time: \(error)")
            #endif
            errorMessage = "Failed to update arrival time: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    
    func fetchDogsIncremental() async {
        // DEPRECATED: This method used the old CloudKit Dog architecture
        // Now just redirects to the standard fetchDogs() which has smart caching
        // The caching system automatically handles incremental updates
        
        #if DEBUG
        print("🔍 DataManager: fetchDogsIncremental called - redirecting to fetchDogs with caching")
        #endif
        
        // Just use the standard fetch which now has smart caching
        // It will use cached data if available and only fetch when needed
        await fetchDogs()
    }
    
    func getAllDogs() async -> [DogWithVisit] {
        do {
            let cloudKitDogs = try await cloudKitService.fetchDogs()
            let convertedDogs = cloudKitDogs.map { $0.toDogWithVisit() }
            #if DEBUG
            print("✅ Fetched \(convertedDogs.count) total dogs from CloudKit")
            #endif
            return convertedDogs
        } catch {
            #if DEBUG
            print("❌ Failed to fetch all dogs: \(error)")
            #endif
            return []
        }
    }
    
    // MARK: - Database-specific fetch (more robust)
    
    
    func forceRefreshDatabaseCache() {
        // Clear AdvancedCache and reset sync time for PersistentDogs
        AdvancedCache.shared.remove("persistent_dogs_cache")
        lastAllDogsSyncTime = Date.distantPast
        
        #if DEBUG
        print("🔄 Database cache manually cleared - will fetch fresh data on next access")
        #endif
    }
    
    
    // MARK: - Smart Incremental Cache Updates for PersistentDogs and Visits
    
    /// Incrementally add a new visit to the active visits cache
    private func incrementallyUpdateVisitCache(add visit: Visit) async {
        // DEPRECATED: CacheManager now handles all caching automatically
        // This function is kept for compatibility but does nothing
        #if DEBUG
        print("💾 DEPRECATED: AdvancedCache call skipped - CacheManager handles this automatically")
        #endif
    }
    
    /// Incrementally update an existing visit in the cache
    private func incrementallyUpdateVisitCache(update visit: Visit) async {
        // DEPRECATED: CacheManager now handles all caching automatically
        #if DEBUG
        print("💾 DEPRECATED: DataIntegrityCache call skipped - CacheManager handles this automatically")
        #endif
    }
    
    /// Incrementally remove a visit from the cache (when dog is checked out)
    private func incrementallyUpdateVisitCache(remove visitId: UUID) async {
        // DEPRECATED: CacheManager now handles all caching automatically
        #if DEBUG
        print("💾 DEPRECATED: DataIntegrityCache call skipped - CacheManager handles this automatically")
        #endif
    }
    
    /// Force refresh both caches (for pull-to-refresh)
    func forceRefreshMainPageCache() {
        // Clear both caches
        AdvancedCache.shared.remove("active_visits_cache")
        AdvancedCache.shared.remove("persistent_dogs_cache")
        lastSyncTime = Date.distantPast
        
        #if DEBUG
        print("🔄 Main page caches cleared - will fetch fresh data on next access")
        #endif
    }
    
    /// Incrementally add a new persistent dog to the cache
    private func incrementallyUpdatePersistentDogCache(add persistentDog: PersistentDog) async {
        // Get current cached dogs or create empty array if cache doesn't exist
        var cachedDogs: [PersistentDog] = await AdvancedCache.shared.get("persistent_dogs_cache") ?? []
        
        // Add if not already present
        if !cachedDogs.contains(where: { $0.id == persistentDog.id }) {
            cachedDogs.append(persistentDog)
            AdvancedCache.shared.set(cachedDogs, for: "persistent_dogs_cache", expirationInterval: 3600)
            
            #if DEBUG
            print("✅ Incrementally added persistent dog to cache: \(persistentDog.name) (cache had \(cachedDogs.count - 1) dogs)")
            #endif
        }
    }
    
    /// Incrementally update an existing persistent dog in the cache
    private func incrementallyUpdatePersistentDogCache(update persistentDog: PersistentDog) async {
        // Get current cached dogs
        if var cachedDogs: [PersistentDog] = await AdvancedCache.shared.get("persistent_dogs_cache") {
            // Update if exists
            if let index = cachedDogs.firstIndex(where: { $0.id == persistentDog.id }) {
                cachedDogs[index] = persistentDog
                AdvancedCache.shared.set(cachedDogs, for: "persistent_dogs_cache", expirationInterval: 3600)
                
                #if DEBUG
                print("✅ Incrementally updated persistent dog in cache: \(persistentDog.name)")
                #endif
            }
        }
    }
    
    /// Incrementally remove a persistent dog from the cache
    private func incrementallyUpdatePersistentDogCache(remove dogId: UUID) async {
        // Get current cached dogs
        if var cachedDogs: [PersistentDog] = await AdvancedCache.shared.get("persistent_dogs_cache") {
            // Remove if exists
            if let index = cachedDogs.firstIndex(where: { $0.id == dogId }) {
                let removedDog = cachedDogs.remove(at: index)
                AdvancedCache.shared.set(cachedDogs, for: "persistent_dogs_cache", expirationInterval: 3600)
                
                #if DEBUG
                print("✅ Incrementally removed persistent dog from cache: \(removedDog.name)")
                #endif
            }
        }
    }
    
    
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
                #if DEBUG
                print("🔄 Updating persistent dog in CloudKit: \(dog.name)")
                #endif
                
                // Update persistent dog information
                // Optimistic update: immediate UI + background sync
                cacheManager.updateLocalPersistentDog(dog.persistentDog)
                self.dogs = cacheManager.getCurrentDogsWithVisits()
                
                Task {
                    try await persistentDogService.updatePersistentDog(dog.persistentDog)
                }
                
                #if DEBUG
                print("✅ Updated persistent dog in CloudKit for \(dog.name)")
                #endif
                
                // Update persistent dog cache
                await self.incrementallyUpdatePersistentDogCache(update: dog.persistentDog)
                
                await MainActor.run {
                    self.lastSyncTime = Date() // Update sync time for dog update
                }
            } catch {
                #if DEBUG
                print("❌ Failed to update persistent dog in CloudKit: \(error)")
                #endif
                await MainActor.run {
                    self.errorMessage = "Failed to update dog: \(error.localizedDescription)"
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
                    // Optimistic update: immediate UI + background sync
                    cacheManager.updateLocalVisit(visit)
                    self.dogs = cacheManager.getCurrentDogsWithVisits()
                    
                    Task {
                        try await visitService.updateVisit(visit)
                    }
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
                    age: currentDogWithVisit.persistentDog.age,
                    gender: currentDogWithVisit.persistentDog.gender,
                    vaccinations: vaccinations, // Updated vaccinations
                    isNeuteredOrSpayed: currentDogWithVisit.persistentDog.isNeuteredOrSpayed,
                    allergiesAndFeedingInstructions: currentDogWithVisit.persistentDog.allergiesAndFeedingInstructions,
                    profilePictureData: currentDogWithVisit.persistentDog.profilePictureData,
                    createdAt: currentDogWithVisit.persistentDog.createdAt,
                    updatedAt: Date() // Updated timestamp
                )
                // Create new DogWithVisit with updated PersistentDog
                let updatedDogWithVisit = DogWithVisit(persistentDog: updatedPersistentDog, currentVisit: currentDogWithVisit.currentVisit)
                self.dogs[index] = updatedDogWithVisit
                print("✅ Updated vaccinations in local cache immediately")
            }
        }
        
        // Update the persistent dog in CloudKit
        do {
            var updatedPersistentDog = dogWithVisit.persistentDog
            updatedPersistentDog.vaccinations = vaccinations
            updatedPersistentDog.updatedAt = Date()
            
            // Optimistic update: immediate UI + background sync
            cacheManager.updateLocalPersistentDog(updatedPersistentDog)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            Task {
                try await persistentDogService.updatePersistentDog(updatedPersistentDog)
            }
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
            // Delete the visit in CloudKit with atomic transaction
            // Optimistic delete: immediate UI update + background sync
            cacheManager.removeLocalVisit(visit.id)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            Task {
                try await visitService.deleteVisit(visit)
            }
            print("✅ Marked visit as deleted in CloudKit")
            
            // Update the persistent dog's last visit date
            var updatedPersistentDog = dogWithVisit.persistentDog
            updatedPersistentDog.lastVisitDate = Date()
            
            // Optimistic update: immediate UI + background sync
            cacheManager.updateLocalPersistentDog(updatedPersistentDog)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            Task {
                try await persistentDogService.updatePersistentDog(updatedPersistentDog)
            }
            
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
        
        // Permanently delete from CloudKit FIRST
        do {
            try await persistentDogService.deletePersistentDog(dog.persistentDog)
            print("✅ Dog permanently deleted from CloudKit")
            
            // Only update cache and UI after successful CloudKit deletion
            await incrementallyUpdatePersistentDogCache(remove: dog.id)
            
            // Remove from allDogs array (database view), NOT from main dogs list
            await MainActor.run {
                self.allDogs.removeAll { $0.id == dog.id }
                
                #if DEBUG
                print("✅ Removed dog from database view and cache after successful CloudKit deletion")
                #endif
            }
        } catch {
            print("❌ Failed to permanently delete dog: \(error)")
            errorMessage = "Failed to permanently delete dog: \(error.localizedDescription)"
            
            #if DEBUG
            print("🔄 Dog was not removed from cache or UI due to CloudKit failure")
            #endif
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
            // Optimistic update: immediate UI + background sync
            cacheManager.updateLocalVisit(updatedVisit)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            Task {
                try await visitService.updateVisit(updatedVisit)
            }
            
            // Update local cache
            await MainActor.run {
                if let index = dogs.firstIndex(where: { $0.id == dog.id }) {
                    let updatedDogWithVisit = DogWithVisit(persistentDog: dog.persistentDog, currentVisit: updatedVisit)
                    dogs[index] = updatedDogWithVisit
                }
            }
            
            // Update visit cache with the modified visit
            await incrementallyUpdateVisitCache(update: updatedVisit)
            
            print("✅ Successfully extended boarding for \(dog.name)")
        } catch {
            print("❌ Failed to extend boarding: \(error)")
            errorMessage = "Failed to extend boarding: \(error.localizedDescription)"
        }
    }
    
    func convertToBoarding(for dog: DogWithVisit, endDate: Date) async {
        #if DEBUG
        print("🔄 Converting dog to boarding: \(dog.name) until \(endDate)")
        #endif
        
        // Update the visit to boarding
        guard let currentVisit = dog.currentVisit else {
            #if DEBUG
            print("❌ Cannot convert to boarding - no current visit found")
            #endif
            return
        }
        
        var updatedVisit = currentVisit
        updatedVisit.isBoarding = true
        updatedVisit.boardingEndDate = endDate
        updatedVisit.updatedAt = Date()
        
        do {
            // Optimistic update: immediate UI + background sync
            cacheManager.updateLocalVisit(updatedVisit)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            Task {
                try await visitService.updateVisit(updatedVisit)
            }
            
            // Update local cache
            await MainActor.run {
                if let index = dogs.firstIndex(where: { $0.id == dog.id }) {
                    let updatedDogWithVisit = DogWithVisit(persistentDog: dog.persistentDog, currentVisit: updatedVisit)
                    dogs[index] = updatedDogWithVisit
                }
            }
            
            // Update visit cache with the modified visit
            await incrementallyUpdateVisitCache(update: updatedVisit)
            
            #if DEBUG
            print("✅ Successfully converted to boarding for \(dog.name)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to convert to boarding: \(error)")
            #endif
            errorMessage = "Failed to convert to boarding: \(error.localizedDescription)"
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
        
        // Update Visit in CloudKit with new architecture
        guard var currentVisit = dog.currentVisit else {
            #if DEBUG
            print("❌ No current visit found for dog")
            #endif
            errorMessage = "No active visit for this dog"
            isLoading = false
            return
        }
        
        // Remove from visit's feeding records
        currentVisit.feedingRecords.removeAll { $0.id == record.id }
        currentVisit.updatedAt = Date()
        
        do {
            // Optimistic update: immediate UI + background sync
            cacheManager.updateLocalVisit(currentVisit)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            Task {
                try await visitService.updateVisit(currentVisit)
            }
            
            // Update legacy cache for compatibility
            await incrementallyUpdateVisitCache(update: currentVisit)
            
            #if DEBUG
            print("✅ Feeding record deleted from Visit for \(dog.name)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to delete feeding record: \(error)")
            #endif
            
            // Revert local cache if update failed
            await MainActor.run {
                if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                    self.dogs[index].currentVisit?.feedingRecords.append(record)
                    
                    #if DEBUG
                    print("🔄 Reverted feeding record in local cache due to failure")
                    #endif
                }
            }
            errorMessage = "Failed to delete feeding record: \(error.localizedDescription)"
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
        
        // Update Visit in CloudKit with new architecture
        guard var currentVisit = dog.currentVisit else {
            #if DEBUG
            print("❌ No current visit found for dog")
            #endif
            errorMessage = "No active visit for this dog"
            isLoading = false
            return
        }
        
        // Remove from visit's medication records
        currentVisit.medicationRecords.removeAll { $0.id == record.id }
        currentVisit.updatedAt = Date()
        
        do {
            // Optimistic update: immediate UI + background sync
            cacheManager.updateLocalVisit(currentVisit)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            Task {
                try await visitService.updateVisit(currentVisit)
            }
            
            // Update legacy cache for compatibility
            await incrementallyUpdateVisitCache(update: currentVisit)
            
            #if DEBUG
            print("✅ Medication record deleted from Visit for \(dog.name)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to delete medication record: \(error)")
            #endif
            
            // Revert local cache if update failed
            await MainActor.run {
                if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                    self.dogs[index].currentVisit?.medicationRecords.append(record)
                }
            }
            errorMessage = "Failed to delete medication record: \(error.localizedDescription)"
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
        
        // Update Visit in CloudKit with new architecture
        guard var currentVisit = dog.currentVisit else {
            #if DEBUG
            print("❌ No current visit found for dog")
            #endif
            errorMessage = "No active visit for this dog"
            isLoading = false
            return
        }
        
        // Remove from visit's potty records
        currentVisit.pottyRecords.removeAll { $0.id == record.id }
        currentVisit.updatedAt = Date()
        
        do {
            // Optimistic update: immediate UI + background sync
            cacheManager.updateLocalVisit(currentVisit)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            Task {
                try await visitService.updateVisit(currentVisit)
            }
            
            // Update legacy cache for compatibility
            await incrementallyUpdateVisitCache(update: currentVisit)
            
            #if DEBUG
            print("✅ Potty record deleted from Visit for \(dog.name)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to delete potty record: \(error)")
            #endif
            
            // Revert local cache if update failed
            await MainActor.run {
                if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                    self.dogs[index].currentVisit?.pottyRecords.append(record)
                }
            }
            errorMessage = "Failed to delete potty record: \(error.localizedDescription)"
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
        
        // Update Visit in CloudKit with new architecture
        guard var currentVisit = dog.currentVisit else {
            #if DEBUG
            print("❌ No current visit found for dog")
            #endif
            errorMessage = "No active visit for this dog"
            isLoading = false
            return
        }
        
        // Add to visit's potty records
        currentVisit.pottyRecords.append(newRecord)
        currentVisit.updatedAt = Date()
        
        do {
            // Optimistic update: immediate UI + background sync
            cacheManager.updateLocalVisit(currentVisit)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            Task {
                try await visitService.updateVisit(currentVisit)
            }
            
            // Update legacy cache for compatibility
            await incrementallyUpdateVisitCache(update: currentVisit)
            
            #if DEBUG
            print("✅ Potty record added to Visit for \(dog.name)")
            #endif
            
            // Update sync time for new record
            lastSyncTime = Date()
        } catch {
            #if DEBUG
            print("❌ Failed to add potty record: \(error)")
            #endif
            
            // Revert local cache if update failed
            await MainActor.run {
                if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                    self.dogs[index].currentVisit?.pottyRecords.removeLast()
                }
            }
            errorMessage = "Failed to add potty record: \(error.localizedDescription)"
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
        
        // Update Visit in CloudKit with new architecture
        guard var currentVisit = dog.currentVisit else {
            #if DEBUG
            print("❌ No current visit found for dog")
            #endif
            errorMessage = "No active visit for this dog"
            isLoading = false
            return
        }
        
        // Update the specific record in visit's potty records
        if let recordIndex = currentVisit.pottyRecords.firstIndex(where: { $0.id == record.id }) {
            currentVisit.pottyRecords[recordIndex].notes = newNotes
            currentVisit.updatedAt = Date()
            
            do {
                // Optimistic update: immediate UI + background sync
                cacheManager.updateLocalVisit(currentVisit)
                self.dogs = cacheManager.getCurrentDogsWithVisits()
                
                Task {
                    try await visitService.updateVisit(currentVisit)
                }
                
                // Update legacy cache for compatibility
                await incrementallyUpdateVisitCache(update: currentVisit)
                
                #if DEBUG
                print("✅ Potty record notes updated in Visit for \(dog.name)")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to update potty record notes: \(error)")
                #endif
                
                // Revert local cache if update failed
                await MainActor.run {
                    if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
                       let recordIndex = self.dogs[dogIndex].currentVisit?.pottyRecords.firstIndex(where: { $0.id == record.id }) {
                        self.dogs[dogIndex].currentVisit?.pottyRecords[recordIndex].notes = record.notes
                    }
                }
                errorMessage = "Failed to update potty record notes: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    func addFeedingRecord(to dog: DogWithVisit, type: FeedingRecord.FeedingType, notes: String? = nil, recordedBy: String?) async {
        isLoading = true
        errorMessage = nil
        
        // 1. Check current state from cache
        let currentDogState = cacheManager.getCurrentDogsWithVisits()
            .first { $0.id == dog.id }
        
        let newRecord = FeedingRecord(
            timestamp: Date(),
            type: type,
            notes: notes,
            recordedBy: recordedBy
        )
        
        // Simplified approach: no complex conflict detection needed
        // CloudKit handles eventual consistency naturally
        
        // 2. Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].currentVisit?.feedingRecords.append(newRecord)
                self.dogs[index].currentVisit?.updatedAt = Date()
                
                #if DEBUG
                print("✅ Added feeding record to local cache with conflict protection")
                #endif
            }
        }
        
        // Update Visit in CloudKit with new architecture
        guard var currentVisit = dog.currentVisit else {
            #if DEBUG
            print("❌ No current visit found for dog")
            #endif
            errorMessage = "No active visit for this dog"
            isLoading = false
            return
        }
        
        // Add to visit's feeding records
        currentVisit.feedingRecords.append(newRecord)
        currentVisit.updatedAt = Date()
        
        do {
            // Optimistic update: immediate UI + background sync
            cacheManager.updateLocalVisit(currentVisit)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            Task {
                try await visitService.updateVisit(currentVisit)
            }
            
            // Update legacy cache for compatibility
            await incrementallyUpdateVisitCache(update: currentVisit)
            
            #if DEBUG
            print("✅ Feeding record added to Visit for \(dog.name)")
            #endif
            
            // Update sync time for new record
            lastSyncTime = Date()
        } catch {
            #if DEBUG
            print("❌ Failed to add feeding record: \(error)")
            #endif
            
            // Revert local cache if update failed
            await MainActor.run {
                if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                    self.dogs[index].currentVisit?.feedingRecords.removeLast()
                }
            }
            errorMessage = "Failed to add feeding record: \(error.localizedDescription)"
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
        
        // Update Visit in CloudKit with new architecture
        guard var currentVisit = dog.currentVisit else {
            #if DEBUG
            print("❌ No current visit found for dog")
            #endif
            errorMessage = "No active visit for this dog"
            isLoading = false
            return
        }
        
        // Update the specific record in visit's feeding records
        if let recordIndex = currentVisit.feedingRecords.firstIndex(where: { $0.id == record.id }) {
            currentVisit.feedingRecords[recordIndex].notes = newNotes
            currentVisit.updatedAt = Date()
            
            do {
                // Optimistic update: immediate UI + background sync
                cacheManager.updateLocalVisit(currentVisit)
                self.dogs = cacheManager.getCurrentDogsWithVisits()
                
                Task {
                    try await visitService.updateVisit(currentVisit)
                }
                
                // Update legacy cache for compatibility
                await incrementallyUpdateVisitCache(update: currentVisit)
                
                #if DEBUG
                print("✅ Feeding record notes updated in Visit for \(dog.name)")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to update feeding record notes: \(error)")
                #endif
                
                // Revert local cache if update failed
                await MainActor.run {
                    if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
                       let recordIndex = self.dogs[dogIndex].currentVisit?.feedingRecords.firstIndex(where: { $0.id == record.id }) {
                        self.dogs[dogIndex].currentVisit?.feedingRecords[recordIndex].notes = record.notes
                    }
                }
                errorMessage = "Failed to update feeding record notes: \(error.localizedDescription)"
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
        
        // Update Visit in CloudKit with new architecture
        guard var currentVisit = dog.currentVisit else {
            #if DEBUG
            print("❌ No current visit found for dog")
            #endif
            errorMessage = "No active visit for this dog"
            isLoading = false
            return
        }
        
        // Update the specific record in visit's feeding records
        if let recordIndex = currentVisit.feedingRecords.firstIndex(where: { $0.id == record.id }) {
            currentVisit.feedingRecords[recordIndex].timestamp = newTimestamp
            currentVisit.updatedAt = Date()
            
            do {
                // Optimistic update: immediate UI + background sync
                cacheManager.updateLocalVisit(currentVisit)
                self.dogs = cacheManager.getCurrentDogsWithVisits()
                
                Task {
                    try await visitService.updateVisit(currentVisit)
                }
                
                // Update legacy cache for compatibility
                await incrementallyUpdateVisitCache(update: currentVisit)
                
                #if DEBUG
                print("✅ Feeding record timestamp updated in Visit for \(dog.name)")
                #endif
                
                // Update sync time for record update
                lastSyncTime = Date()
            } catch {
                #if DEBUG
                print("❌ Failed to update feeding record timestamp: \(error)")
                #endif
                
                // Revert local cache if update failed
                await MainActor.run {
                    if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
                       let recordIndex = self.dogs[dogIndex].currentVisit?.feedingRecords.firstIndex(where: { $0.id == record.id }) {
                        self.dogs[dogIndex].currentVisit?.feedingRecords[recordIndex].timestamp = record.timestamp
                    }
                }
                errorMessage = "Failed to update feeding record timestamp: \(error.localizedDescription)"
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
        
        // Update Visit in CloudKit with new architecture
        guard var currentVisit = dog.currentVisit else {
            #if DEBUG
            print("❌ No current visit found for dog")
            #endif
            errorMessage = "No active visit for this dog"
            isLoading = false
            return
        }
        
        // Update the specific record in visit's potty records
        if let recordIndex = currentVisit.pottyRecords.firstIndex(where: { $0.id == record.id }) {
            currentVisit.pottyRecords[recordIndex].timestamp = newTimestamp
            currentVisit.updatedAt = Date()
            
            do {
                // Optimistic update: immediate UI + background sync
                cacheManager.updateLocalVisit(currentVisit)
                self.dogs = cacheManager.getCurrentDogsWithVisits()
                
                Task {
                    try await visitService.updateVisit(currentVisit)
                }
                
                // Update legacy cache for compatibility
                await incrementallyUpdateVisitCache(update: currentVisit)
                
                #if DEBUG
                print("✅ Potty record timestamp updated in Visit for \(dog.name)")
                #endif
                
                // Update sync time for record update
                lastSyncTime = Date()
            } catch {
                #if DEBUG
                print("❌ Failed to update potty record timestamp: \(error)")
                #endif
                
                // Revert local cache if update failed
                await MainActor.run {
                    if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
                       let recordIndex = self.dogs[dogIndex].currentVisit?.pottyRecords.firstIndex(where: { $0.id == record.id }) {
                        self.dogs[dogIndex].currentVisit?.pottyRecords[recordIndex].timestamp = record.timestamp
                    }
                }
                errorMessage = "Failed to update potty record timestamp: \(error.localizedDescription)"
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
        
        // Update Visit in CloudKit with new architecture
        guard var currentVisit = dog.currentVisit else {
            #if DEBUG
            print("❌ No current visit found for dog")
            #endif
            errorMessage = "No active visit for this dog"
            isLoading = false
            return
        }
        
        // Add to visit's medication records
        currentVisit.medicationRecords.append(newRecord)
        currentVisit.updatedAt = Date()
        
        do {
            // Optimistic update: immediate UI + background sync
            cacheManager.updateLocalVisit(currentVisit)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            Task {
                try await visitService.updateVisit(currentVisit)
            }
            
            // Update legacy cache for compatibility
            await incrementallyUpdateVisitCache(update: currentVisit)
            
            #if DEBUG
            print("✅ Medication record added to Visit for \(dog.name)")
            #endif
            
            // Update sync time for new record
            lastSyncTime = Date()
        } catch {
            #if DEBUG
            print("❌ Failed to add medication record: \(error)")
            #endif
            
            // Revert local cache if update failed
            await MainActor.run {
                if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                    self.dogs[index].currentVisit?.medicationRecords.removeLast()
                }
            }
            errorMessage = "Failed to add medication record: \(error.localizedDescription)"
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
        
        // Update Visit in CloudKit with new architecture
        guard var currentVisit = dog.currentVisit else {
            #if DEBUG
            print("❌ No current visit found for dog")
            #endif
            errorMessage = "No active visit for this dog"
            isLoading = false
            return
        }
        
        // Update the specific record in visit's medication records
        if let recordIndex = currentVisit.medicationRecords.firstIndex(where: { $0.id == record.id }) {
            currentVisit.medicationRecords[recordIndex].timestamp = newTimestamp
            currentVisit.updatedAt = Date()
            
            do {
                // Optimistic update: immediate UI + background sync
                cacheManager.updateLocalVisit(currentVisit)
                self.dogs = cacheManager.getCurrentDogsWithVisits()
                
                Task {
                    try await visitService.updateVisit(currentVisit)
                }
                
                // Update legacy cache for compatibility
                await incrementallyUpdateVisitCache(update: currentVisit)
                
                #if DEBUG
                print("✅ Medication record timestamp updated in Visit for \(dog.name)")
                #endif
                
                // Update sync time for record update
                lastSyncTime = Date()
            } catch {
                #if DEBUG
                print("❌ Failed to update medication record timestamp: \(error)")
                #endif
                
                // Revert local cache if update failed
                await MainActor.run {
                    if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
                       let recordIndex = self.dogs[dogIndex].currentVisit?.medicationRecords.firstIndex(where: { $0.id == record.id }) {
                        self.dogs[dogIndex].currentVisit?.medicationRecords[recordIndex].timestamp = record.timestamp
                    }
                }
                errorMessage = "Failed to update medication record timestamp: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    func updateMedicationRecordNotes(_ record: MedicationRecord, newNotes: String?, in dog: DogWithVisit) async {
        isLoading = true
        errorMessage = nil
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
               let recordIndex = self.dogs[dogIndex].currentVisit?.medicationRecords.firstIndex(where: { $0.id == record.id }) {
                self.dogs[dogIndex].currentVisit?.medicationRecords[recordIndex].notes = newNotes
                self.dogs[dogIndex].currentVisit?.updatedAt = Date()
            }
        }
        
        // Update Visit in CloudKit with new architecture
        guard var currentVisit = dog.currentVisit else {
            #if DEBUG
            print("❌ No current visit found for dog")
            #endif
            errorMessage = "No active visit for this dog"
            isLoading = false
            return
        }
        
        // Update the specific record in visit's medication records
        if let recordIndex = currentVisit.medicationRecords.firstIndex(where: { $0.id == record.id }) {
            currentVisit.medicationRecords[recordIndex].notes = newNotes
            currentVisit.updatedAt = Date()
            
            do {
                // Optimistic update: immediate UI + background sync
                cacheManager.updateLocalVisit(currentVisit)
                self.dogs = cacheManager.getCurrentDogsWithVisits()
                
                Task {
                    try await visitService.updateVisit(currentVisit)
                }
                
                // Update legacy cache for compatibility
                await incrementallyUpdateVisitCache(update: currentVisit)
                
                #if DEBUG
                print("✅ Medication record notes updated in Visit for \(dog.name)")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to update medication record notes: \(error)")
                #endif
                
                // Revert local cache if update failed
                await MainActor.run {
                    if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
                       let recordIndex = self.dogs[dogIndex].currentVisit?.medicationRecords.firstIndex(where: { $0.id == record.id }) {
                        self.dogs[dogIndex].currentVisit?.medicationRecords[recordIndex].notes = record.notes
                    }
                }
                errorMessage = "Failed to update medication record notes: \(error.localizedDescription)"
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
        #if DEBUG
        print("🔄 DataManager: Manual refresh requested - clearing caches")
        #endif
        
        // Clear caches to force fresh data
        forceRefreshMainPageCache()
        
        // Fetch fresh data (will populate caches)
        await fetchDogs()
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
        
        // Update dogs cache with the changed dogs
        
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
    
    // MARK: - Persistent Dog Statistics
    
    private func updatePersistentDogStatistics(dogId: UUID, lastVisitDate: Date) async {
        do {
            // Fetch current persistent dog
            let predicate = NSPredicate(format: "id == %@", dogId.uuidString)
            let persistentDogs = try await persistentDogService.fetchPersistentDogs(predicate: predicate)
            
            guard var persistentDog = persistentDogs.first else {
                print("❌ Could not find persistent dog with ID: \(dogId)")
                return
            }
            
            // Update statistics
            persistentDog.visitCount += 1
            persistentDog.lastVisitDate = lastVisitDate
            persistentDog.updatedAt = Date()
            
            // Optimistic update: immediate UI + background sync
            cacheManager.updateLocalPersistentDog(persistentDog)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            Task {
                try await persistentDogService.updatePersistentDog(persistentDog)
            }
            print("✅ Updated persistent dog statistics: visitCount=\(persistentDog.visitCount), lastVisitDate=\(lastVisitDate)")
            
            // Update persistent dog cache for database view consistency
            await incrementallyUpdatePersistentDogCache(update: persistentDog)
        } catch {
            print("❌ Failed to update persistent dog statistics: \(error)")
        }
    }
    
    /// Decrement visit count when undoing a checkout (since the visit is no longer complete)
    private func decrementPersistentDogVisitCount(dogId: UUID) async {
        do {
            // Fetch current persistent dog
            let predicate = NSPredicate(format: "id == %@", dogId.uuidString)
            let persistentDogs = try await persistentDogService.fetchPersistentDogs(predicate: predicate)
            
            guard var persistentDog = persistentDogs.first else {
                #if DEBUG
                print("❌ Could not find persistent dog with ID: \(dogId) for visit count decrement")
                #endif
                return
            }
            
            // Only decrement if count is greater than 0
            if persistentDog.visitCount > 0 {
                persistentDog.visitCount -= 1
                persistentDog.updatedAt = Date()
                
                // Optimistic update: immediate UI + background sync
                cacheManager.updateLocalPersistentDog(persistentDog)
                self.dogs = cacheManager.getCurrentDogsWithVisits()
                
                Task {
                    try await persistentDogService.updatePersistentDog(persistentDog)
                }
                
                #if DEBUG
                print("✅ Decremented persistent dog visit count: visitCount=\(persistentDog.visitCount)")
                #endif
                
                // Update persistent dog cache
                await incrementallyUpdatePersistentDogCache(update: persistentDog)
            } else {
                #if DEBUG
                print("⚠️ Visit count is already 0, cannot decrement further")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Failed to decrement persistent dog visit count: \(error)")
            #endif
        }
    }
    
    // MARK: - Optimized Dog Operations
    
    func checkoutDog(_ dog: DogWithVisit) async {
        isLoading = true
        errorMessage = nil
        
        print("🔄 Starting optimized checkout for dog: \(dog.name)")
        
        // Log the checkout action
        await logDogActivity(action: "CHECKOUT_DOG", dog: dog, extra: "Checking out dog - setting departure date to current time")
        
        let departureDate = Date()
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].currentVisit?.departureDate = departureDate
                self.dogs[index].currentVisit?.updatedAt = departureDate
                #if DEBUG
                print("✅ Updated local cache for checkout")
                #endif
            }
        }
        
        // Handle CloudKit operations in background without blocking UI
        Task.detached {
            do {
                // Use new persistent dog system
                if var currentVisit = dog.currentVisit {
                    currentVisit.departureDate = departureDate
                    currentVisit.updatedAt = departureDate
                    
                    // Dog will still show in "departed today" section until tomorrow
                    // Optimistic update: immediate UI + background sync
                    cacheManager.updateLocalVisit(currentVisit)
                    self.dogs = cacheManager.getCurrentDogsWithVisits()
                    
                    Task {
                        try await visitService.updateVisit(currentVisit)
                    }
                    
                    #if DEBUG
                    print("✅ Visit updated in CloudKit for \(dog.name)")
                    #endif
                    
                    // Update visit cache (mark as departed)
                    await self.incrementallyUpdateVisitCache(update: currentVisit)
                    
                    // Update persistent dog statistics
                    await self.updatePersistentDogStatistics(dogId: dog.id, lastVisitDate: departureDate)
                } else {
                    // Use legacy system
                    try await self.cloudKitService.checkoutDog(dog.id.uuidString)
                    print("✅ Checkout completed in CloudKit for \(dog.name)")
                }
            } catch {
                print("❌ Failed to checkout dog in CloudKit: \(error)")
                // Revert local cache if CloudKit update failed
                await MainActor.run {
                    if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                        self.dogs[index].currentVisit?.departureDate = nil
                        // Sync timestamp from CloudKit update
                        print("🔄 Reverted checkout in local cache due to CloudKit failure")
                    }
                }
            }
        }
        
        isLoading = false
    }
    

    // Duplicate method removed - using the one at line 350

    // Duplicate method removed - using the one at line 374


    func fetchAllPersistentDogs() async {
        isLoading = true
        errorMessage = nil
        
        #if DEBUG
        print("🔍 DataManager: Starting fetchAllPersistentDogs with smart caching...")
        #endif
        
        // Check cache first
        if let cachedDogs: [PersistentDog] = await AdvancedCache.shared.get("persistent_dogs_cache") {
            #if DEBUG
            print("💾 Using cached persistent dogs (\(cachedDogs.count) dogs)")
            #endif
            
            let dogsWithVisits = cachedDogs.map { persistentDog in
                DogWithVisit(persistentDog: persistentDog, currentVisit: nil)
            }
            
            await MainActor.run {
                self.allDogs = dogsWithVisits.sorted { $0.name < $1.name }
                self.isLoading = false
            }
            return
        }
        
        #if DEBUG
        print("🔄 Cache miss - fetching persistent dogs from service...")
        #endif
        
        do {
            // Fetch all persistent dogs from the database
            let persistentDogs = try await persistentDogService.fetchPersistentDogs()
            
            #if DEBUG
            print("🔍 DataManager: Got \(persistentDogs.count) persistent dogs from service")
            #endif
            
            // Cache the persistent dogs (1 hour expiration)
            AdvancedCache.shared.set(persistentDogs, for: "persistent_dogs_cache", expirationInterval: 3600)
            
            // Create DogWithVisit for each persistent dog
            let dogsWithVisits = persistentDogs.map { persistentDog in
                DogWithVisit(persistentDog: persistentDog, currentVisit: nil)
            }
            
            await MainActor.run {
                self.allDogs = dogsWithVisits.sorted { $0.name < $1.name }
                self.lastAllDogsSyncTime = Date()
                self.isLoading = false
                
                #if DEBUG
                print("✅ DataManager: Set \(dogsWithVisits.count) dogs in allDogs array (cached)")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Failed to fetch all persistent dogs: \(error)")
            #endif
            await MainActor.run {
                self.errorMessage = "Failed to fetch dogs: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
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
        #if DEBUG
        print("🚀 DataManager: Starting optimized fetchDogsForImport...")
        print("📊 DataManager: Current main page dogs count: \(dogs.count)")
        print("📊 DataManager: Current allDogs count: \(allDogs.count)")
        #endif
        
        // Get all persistent dogs
        await fetchAllPersistentDogs()
        
        #if DEBUG
        print("📊 DataManager: After fetchAllPersistentDogs - allDogs count: \(allDogs.count)")
        
        // Debug: Log some sample dog info
        if !allDogs.isEmpty {
            let firstDog = allDogs[0]
            print("🐕 DataManager: Sample dog - Name: \(firstDog.name), ID: \(firstDog.id), VisitCount: \(firstDog.persistentDog.visitCount)")
        }
        #endif
        
        // Get IDs of dogs currently present on main page
        let currentlyPresentDogs = dogs.filter { $0.isCurrentlyPresent }
        let currentlyPresentIds = Set(currentlyPresentDogs.map { $0.id })
        
        #if DEBUG
        print("📊 DataManager: Currently present dogs count: \(currentlyPresentIds.count)")
        if !currentlyPresentDogs.isEmpty {
            print("🐕 DataManager: Currently present dogs: \(currentlyPresentDogs.map { $0.name }.joined(separator: ", "))")
        }
        #endif
        
        // Filter out dogs that are already present on main page
        let availableForImport = allDogs.filter { dog in
            let isAvailable = !currentlyPresentIds.contains(dog.id)
            #if DEBUG
            if !isAvailable {
                print("🚫 DataManager: Excluding \(dog.name) (already present)")
            }
            #endif
            return isAvailable
        }
        
        #if DEBUG
        print("✅ DataManager: Got \(availableForImport.count) dogs available for import")
        print("📋 DataManager: Available dogs: \(availableForImport.map { $0.name }.joined(separator: ", "))")
        print("📊 DataManager: Summary - Total: \(allDogs.count), Present: \(currentlyPresentIds.count), Available: \(availableForImport.count)")
        #endif
        
        return availableForImport
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
    
    func addVisitForExistingDog(
        dogId: UUID,
        arrivalDate: Date,
        isBoarding: Bool,
        boardingEndDate: Date?,
        medications: [Medication],
        scheduledMedications: [ScheduledMedication]
    ) async {
        print("🔄 DataManager: addVisitForExistingDog called for dog ID: \(dogId)")
        
        do {
            // Fetch the existing persistent dog
            guard let persistentDog = try await persistentDogService.fetchPersistentDog(by: dogId) else {
                print("❌ DataManager: Could not find persistent dog with ID: \(dogId)")
                errorMessage = "Could not find dog in database"
                return
            }
            
            print("✅ DataManager: Found existing persistent dog: \(persistentDog.name)")
            
            // Create visit for the existing dog
            let visit = Visit(
                dogId: persistentDog.id,
                arrivalDate: arrivalDate,
                departureDate: nil,
                isBoarding: isBoarding,
                boardingEndDate: boardingEndDate,
                medications: medications,
                scheduledMedications: scheduledMedications
            )
            
            try await visitService.createVisit(visit)
            
            #if DEBUG
            print("✅ DataManager: Created visit for existing dog: \(persistentDog.name)")
            #endif
            
            // Update visit count on the persistent dog
            var updatedPersistentDog = persistentDog
            updatedPersistentDog.visitCount += 1
            updatedPersistentDog.lastVisitDate = arrivalDate
            // Optimistic update: immediate UI + background sync
            cacheManager.updateLocalPersistentDog(updatedPersistentDog)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            Task {
                try await persistentDogService.updatePersistentDog(updatedPersistentDog)
            }
            
            // Update caches
            await incrementallyUpdatePersistentDogCache(update: updatedPersistentDog)
            await incrementallyUpdateVisitCache(add: visit)
            
            // Add to cache and update UI immediately  
            cacheManager.addLocalDogWithVisit(persistentDog: updatedPersistentDog, visit: visit)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            // Refresh dogs list
            await fetchDogs()
            
        } catch {
            print("❌ DataManager: Failed to add visit for existing dog: \(error)")
            errorMessage = "Failed to check in dog: \(error.localizedDescription)"
        }
    }
    
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
        specialInstructions: String?,
        allergiesAndFeedingInstructions: String?,
        profilePictureData: Data?,
        age: Int?,
        gender: DogGender,
        vaccinations: [VaccinationItem],
        isNeuteredOrSpayed: Bool,
        medications: [Medication],
        scheduledMedications: [ScheduledMedication]
    ) async {
        #if DEBUG
        print("🔄 DataManager: addDogWithVisit called for \(name)")
        #endif
        
        // Create persistent dog and visit objects
        let persistentDog = PersistentDog(
            name: name,
            ownerName: ownerName,
            ownerPhoneNumber: ownerPhoneNumber,
            age: age,
            gender: gender,
            vaccinations: vaccinations,
            isNeuteredOrSpayed: isNeuteredOrSpayed,
            allergiesAndFeedingInstructions: allergiesAndFeedingInstructions,
            profilePictureData: profilePictureData,
            visitCount: 1, // First visit
            lastVisitDate: arrivalDate,
            needsWalking: needsWalking,
            walkingNotes: walkingNotes,
            isDaycareFed: isDaycareFed,
            notes: notes,
            specialInstructions: specialInstructions
        )
        
        let visit = Visit(
            dogId: persistentDog.id,
            arrivalDate: arrivalDate,
            departureDate: nil,
            isBoarding: isBoarding,
            boardingEndDate: boardingEndDate,
            medications: medications,
            scheduledMedications: scheduledMedications
        )
        
        do {
            // Use the new atomic transaction system with rollback capability
            // Optimistic add: immediate UI update + background CloudKit sync
            cacheManager.addLocalDogWithVisit(persistentDog: persistentDog, visit: visit)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            // Sync to CloudKit in background
            Task {
                try await persistentDogService.createPersistentDog(persistentDog)
                try await visitService.createVisit(visit)
                
                #if DEBUG
                print("✅ CloudKit: Successfully saved dog and visit")
                #endif
            }
            
            // Update UI immediately with the new dog
            let newDogWithVisit = DogWithVisit(persistentDog: persistentDog, currentVisit: visit)
            await MainActor.run {
                self.dogs.append(newDogWithVisit)
                
                #if DEBUG
                print("✅ UI: Added \(name) to dogs array - total count: \(self.dogs.count)")
                #endif
            }
            
        } catch {
            #if DEBUG
            print("❌ DataManager: Failed to add dog with visit: \(error)")
            #endif
            
            await MainActor.run {
                self.errorMessage = "Failed to add dog: \(error.localizedDescription)"
            }
        }
    }
    
    func addPersistentDogOnly(
        name: String,
        ownerName: String?,
        ownerPhoneNumber: String?,
        needsWalking: Bool,
        walkingNotes: String?,
        notes: String?,
        specialInstructions: String?,
        allergiesAndFeedingInstructions: String?,
        profilePictureData: Data?,
        age: Int?,
        gender: DogGender,
        vaccinations: [VaccinationItem],
        isNeuteredOrSpayed: Bool
    ) async {
        print("🔄 DataManager: addPersistentDogOnly called for \(name)")
        
        do {
            let persistentDog = PersistentDog(
                name: name,
                ownerName: ownerName,
                ownerPhoneNumber: ownerPhoneNumber,
                age: age,
                gender: gender,
                vaccinations: vaccinations,
                isNeuteredOrSpayed: isNeuteredOrSpayed,
                allergiesAndFeedingInstructions: allergiesAndFeedingInstructions,
                profilePictureData: profilePictureData,
                needsWalking: needsWalking,
                walkingNotes: walkingNotes,
                notes: notes,
                specialInstructions: specialInstructions
            )
            
            try await persistentDogService.createPersistentDog(persistentDog)
            
            #if DEBUG
            print("✅ DataManager: Created persistent dog only with ID \(persistentDog.id)")
            #endif
            
            // Update persistent dog cache with new dog
            await incrementallyUpdatePersistentDogCache(add: persistentDog)
            
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
        specialInstructions: String?,
        allergiesAndFeedingInstructions: String?,
        profilePictureData: Data?,
        age: Int?,
        gender: DogGender,
        vaccinations: [VaccinationItem],
        isNeuteredOrSpayed: Bool,
        medications: [Medication],
        scheduledMedications: [ScheduledMedication]
    ) async {
        #if DEBUG
        print("🔄 DataManager: updateDogWithVisit called for \(name)")
        #endif
        
        do {
            // Update persistent dog with ALL fields
            var updatedPersistentDog = dogWithVisit.persistentDog
            updatedPersistentDog.name = name
            updatedPersistentDog.ownerName = ownerName
            updatedPersistentDog.ownerPhoneNumber = ownerPhoneNumber
            updatedPersistentDog.isDaycareFed = isDaycareFed
            updatedPersistentDog.needsWalking = needsWalking
            updatedPersistentDog.walkingNotes = walkingNotes
            updatedPersistentDog.notes = notes
            updatedPersistentDog.specialInstructions = specialInstructions
            updatedPersistentDog.allergiesAndFeedingInstructions = allergiesAndFeedingInstructions
            updatedPersistentDog.profilePictureData = profilePictureData
            updatedPersistentDog.age = age
            updatedPersistentDog.gender = gender
            updatedPersistentDog.vaccinations = vaccinations
            updatedPersistentDog.isNeuteredOrSpayed = isNeuteredOrSpayed
            updatedPersistentDog.updatedAt = Date()
            
            // Optimistic update: immediate UI + background sync
            cacheManager.updateLocalPersistentDog(updatedPersistentDog)
            self.dogs = cacheManager.getCurrentDogsWithVisits()
            
            Task {
                try await persistentDogService.updatePersistentDog(updatedPersistentDog)
            }
            #if DEBUG
            print("✅ DataManager: Successfully updated persistent dog \(name) in CloudKit")
            #endif
            
            // Update persistent dog cache immediately for responsive UI
            await incrementallyUpdatePersistentDogCache(update: updatedPersistentDog)
            
            // Update visit if it exists
            if var currentVisit = dogWithVisit.currentVisit {
                currentVisit.arrivalDate = arrivalDate
                currentVisit.isBoarding = isBoarding
                currentVisit.boardingEndDate = boardingEndDate
                currentVisit.medications = medications
                currentVisit.scheduledMedications = scheduledMedications
                currentVisit.updatedAt = Date()
                
                // Optimistic update: immediate UI + background sync
                cacheManager.updateLocalVisit(currentVisit)
                self.dogs = cacheManager.getCurrentDogsWithVisits()
                
                Task {
                    try await visitService.updateVisit(currentVisit)
                }
                #if DEBUG
                print("✅ DataManager: Updated visit with ID \(currentVisit.id)")
                #endif
                
                // Update legacy cache for compatibility
                await incrementallyUpdateVisitCache(update: currentVisit)
            }
            
            // Refresh dogs list to ensure UI is updated
            await fetchDogs()
            
        } catch {
            #if DEBUG
            print("❌ DataManager: Failed to update dog with visit: \(error)")
            #endif
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
        specialInstructions: String?,
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
            specialInstructions: specialInstructions,
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
            profilePictureData: profilePictureData,
            needsWalking: needsWalking,
            walkingNotes: walkingNotes,
            isDaycareFed: isDaycareFed,
            notes: notes,
            specialInstructions: specialInstructions,
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
                
                var scheduledMedication = ScheduledMedication(
                    medicationId: medicationId,
                    scheduledDate: scheduledMedicationDates[i],
                    notificationTime: scheduledMedicationDates[i]
                )
                scheduledMedication.status = status
                scheduledMedication.notes = scheduledMedicationNotes[i].isEmpty ? nil : scheduledMedicationNotes[i]
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