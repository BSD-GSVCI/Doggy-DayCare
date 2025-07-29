import Foundation

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var dogs: [Dog] = []
    @Published var allDogs: [Dog] = []  // Separate array for all dogs including deleted ones
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let cloudKitService = CloudKitService.shared
    private let historyService = HistoryService.shared
    private let cloudKitHistoryService = CloudKitHistoryService.shared
    
    // Incremental sync tracking
    private var lastSyncTime: Date = Date.distantPast
    private var lastAllDogsSyncTime: Date = Date.distantPast
    
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
        do {
            let cloudKitDogs = try await cloudKitService.fetchDogs()
            print("🔍 DataManager: Got \(cloudKitDogs.count) CloudKit dogs")
            
            let localDogs = cloudKitDogs.map { $0.toDog() }
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
                print("❌ DataManager: Failed to fetch dogs: \(error)")
            }
        }
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
                let localDogs = cloudKitDogs.map { $0.toDog() }
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
    
    func getAllDogs() async -> [Dog] {
        do {
            let cloudKitDogs = try await cloudKitService.fetchDogs()
            let convertedDogs = cloudKitDogs.map { $0.toDog() }
            print("✅ Fetched \(convertedDogs.count) total dogs from CloudKit")
            return convertedDogs
        } catch {
            print("❌ Failed to fetch all dogs: \(error)")
            return []
        }
    }
    
    // MARK: - Database-specific fetch (more robust)
    
    func getAllDogsForDatabase() async -> [Dog] {
        do {
            // Bypass cache completely for database view
            let cloudKitDogs = try await cloudKitService.fetchAllDogsIncludingDeleted()
            let convertedDogs = cloudKitDogs.map { $0.toDog() }
            print("✅ Fetched \(convertedDogs.count) total dogs from CloudKit for database")
            return convertedDogs
        } catch {
            print("❌ Failed to fetch all dogs: \(error)")
            // Return cached data as fallback
            return self.allDogs // Return last known good data
        }
    }
    
    func addDog(_ dog: Dog) async {
        isLoading = true
        errorMessage = nil
        
        // Log the add action
        await logDogActivity(action: "ADD_DOG", dog: dog, extra: "Adding new dog to main list")
        
        do {
            let cloudKitDog = dog.toCloudKitDog()
            print("🔄 DataManager.addDog: Original dog has \(dog.medications.count) medications and \(dog.scheduledMedications.count) scheduled medications")
            let addedCloudKitDog = try await cloudKitService.createDog(cloudKitDog)
            let addedDog = addedCloudKitDog.toDog()
            print("🔄 DataManager.addDog: Added dog has \(addedDog.medications.count) medications and \(addedDog.scheduledMedications.count) scheduled medications")
            await MainActor.run {
                self.dogs.append(addedDog)
                self.lastSyncTime = Date() // Update sync time for new dog
                self.isLoading = false
                print("✅ Added dog: \(addedDog.name)")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to add dog: \(error.localizedDescription)"
                self.isLoading = false
                print("❌ Failed to add dog: \(error)")
            }
        }
    }
    
    func addDogToDatabase(_ dog: Dog) async {
        isLoading = true
        errorMessage = nil
        
        // Log the add action
        await logDogActivity(action: "ADD_DOG_TO_DATABASE", dog: dog, extra: "Adding dog to database only")
        
        do {
            let cloudKitDog = dog.toCloudKitDog()
            let addedCloudKitDog = try await cloudKitService.createDog(cloudKitDog)
            let addedDog = addedCloudKitDog.toDog()
            await MainActor.run {
                self.isLoading = false
                print("✅ Added dog to database only: \(addedDog.name)")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to add dog to database: \(error.localizedDescription)"
                self.isLoading = false
                print("❌ Failed to add dog to database: \(error)")
            }
        }
    }
    
    func updateDog(_ dog: Dog) async {
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
                var updatedDog = Dog(
                    id: dog.id,
                    name: dog.name,
                    ownerName: dog.ownerName,
                    arrivalDate: dog.arrivalDate,
                    isBoarding: dog.isBoarding,
                    boardingEndDate: dog.boardingEndDate,
                    specialInstructions: dog.specialInstructions,
                    allergiesAndFeedingInstructions: dog.allergiesAndFeedingInstructions,
                    needsWalking: dog.needsWalking,
                    walkingNotes: dog.walkingNotes,
                    isDaycareFed: dog.isDaycareFed,
                    notes: dog.notes,
                    profilePictureData: dog.profilePictureData,
                    isArrivalTimeSet: dog.isArrivalTimeSet,
                    isDeleted: dog.isDeleted,
                    age: dog.age,
                    gender: dog.gender,
                    vaccinations: dog.vaccinations,
                    isNeuteredOrSpayed: dog.isNeuteredOrSpayed,
                    ownerPhoneNumber: dog.ownerPhoneNumber,
                    medications: dog.medications,
                    scheduledMedications: dog.scheduledMedications
                )
                // Copy all the records
                updatedDog.feedingRecords = dog.feedingRecords
                updatedDog.medicationRecords = dog.medicationRecords
                updatedDog.pottyRecords = dog.pottyRecords
                // Copy additional properties
                updatedDog.departureDate = dog.departureDate
                updatedDog.updatedAt = Date()
                updatedDog.createdAt = dog.createdAt
                updatedDog.createdBy = dog.createdBy
                updatedDog.lastModifiedBy = dog.lastModifiedBy
                
                print("🔄 Calling CloudKit update in background...")
                
                _ = try await self.cloudKitService.updateDog(updatedDog.toCloudKitDog())
                
                print("✅ CloudKit update successful")
                
                // Update cache with the changed dog
                await self.updateDogsCache(with: [updatedDog])
                
                await MainActor.run {
                    self.lastSyncTime = Date() // Update sync time for dog update
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
    
    func updateDogMedications(_ dog: Dog, medications: [Medication], scheduledMedications: [ScheduledMedication]) async {
        print("🔄 DataManager.updateDogMedications called for: \(dog.name)")
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                var updatedDog = self.dogs[index]
                updatedDog.medications = medications
                updatedDog.scheduledMedications = scheduledMedications
                updatedDog.updatedAt = Date()
                self.dogs[index] = updatedDog
                print("✅ Updated medications in local cache immediately")
            }
        }
        
        // Handle CloudKit operations in background
        Task.detached {
            do {
                var updatedDog = dog
                updatedDog.medications = medications
                updatedDog.scheduledMedications = scheduledMedications
                updatedDog.updatedAt = Date()
                
                print("🔄 Calling CloudKit medication update in background...")
                _ = try await self.cloudKitService.updateDog(updatedDog.toCloudKitDog())
                print("✅ CloudKit medication update successful")
                
                // Update cache with the changed dog
                await self.updateDogsCache(with: [updatedDog])
                
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
    
    func updateDogVaccinations(_ dog: Dog, vaccinations: [VaccinationItem]) async {
        print("🔄 DataManager.updateDogVaccinations called for: \(dog.name)")
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                var updatedDog = self.dogs[index]
                updatedDog.vaccinations = vaccinations
                updatedDog.updatedAt = Date()
                self.dogs[index] = updatedDog
                print("✅ Updated vaccinations in local cache immediately")
            }
        }
        
        // Handle CloudKit operations in background
        Task.detached {
            do {
                var updatedDog = dog
                updatedDog.vaccinations = vaccinations
                updatedDog.updatedAt = Date()
                
                print("🔄 Calling CloudKit vaccination update in background...")
                _ = try await self.cloudKitService.updateDog(updatedDog.toCloudKitDog())
                print("✅ CloudKit vaccination update successful")
                
                // Update cache with the changed dog
                await self.updateDogsCache(with: [updatedDog])
                
                await MainActor.run {
                    self.lastSyncTime = Date()
                }
            } catch {
                print("❌ Failed to update vaccinations in CloudKit: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to update vaccinations: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func deleteDog(_ dog: Dog) async {
        isLoading = true
        errorMessage = nil
        
        print("🔄 Starting delete dog: \(dog.name)")
        
        // Log deletion to persistent file for debugging
        await logDeletion(dog: dog, callStack: Thread.callStackSymbols.prefix(5).map { $0.components(separatedBy: " ").last ?? "" }.joined(separator: " -> "))
        
        // Log the delete action to activity log
        await logDogActivity(action: "DELETE_DOG", dog: dog, extra: "Marking dog as deleted")
        
        // Remove from local cache immediately for responsive UI
        await MainActor.run {
            self.dogs.removeAll { $0.id == dog.id }
            print("✅ Removed dog from local cache")
        }
        
        // Mark as deleted in CloudKit (but keep in database)
        do {
            try await cloudKitService.deleteDog(dog.toCloudKitDog())
            print("✅ Dog marked as deleted in CloudKit")
        } catch {
            print("❌ Failed to mark dog as deleted: \(error)")
            errorMessage = "Failed to delete dog: \(error.localizedDescription)"
            
            // Restore to local cache if CloudKit update failed
            await MainActor.run {
                self.dogs.append(dog)
                print("🔄 Restored dog to local cache due to CloudKit failure")
            }
        }
        
        // Update sync time for successful deletion
        lastSyncTime = Date()
        isLoading = false
    }
    
    func permanentlyDeleteDog(_ dog: Dog) async {
        isLoading = true
        errorMessage = nil
        
        print("🔄 Starting permanent delete dog from database: \(dog.name)")
        
        // Log the permanent delete action
        await logDogActivity(action: "PERMANENTLY_DELETE_DOG", dog: dog, extra: "Permanently deleting dog from database")
        
        // Only remove from allDogs array (database view), NOT from main dogs list
        await MainActor.run {
            self.allDogs.removeAll { $0.id == dog.id }
            print("✅ Removed dog from database view only")
        }
        
        // Permanently delete from CloudKit
        do {
            try await cloudKitService.permanentlyDeleteDog(dog.toCloudKitDog())
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
    
    func extendBoarding(for dog: Dog, newEndDate: Date) async {
        // Create a new dog instance with the updated boarding end date
        var updatedDog = Dog(
            id: dog.id,
            name: dog.name,
            ownerName: dog.ownerName,
            arrivalDate: dog.arrivalDate,
            isBoarding: dog.isBoarding,
            boardingEndDate: newEndDate,
            specialInstructions: dog.specialInstructions,
            allergiesAndFeedingInstructions: dog.allergiesAndFeedingInstructions,
            needsWalking: dog.needsWalking,
            walkingNotes: dog.walkingNotes,
            isDaycareFed: dog.isDaycareFed,
            notes: dog.notes,
            profilePictureData: dog.profilePictureData,
            isArrivalTimeSet: dog.isArrivalTimeSet
        )
        updatedDog.departureDate = dog.departureDate
        updatedDog.updatedAt = Date()
        // Note: updateDog is async but doesn't return a value, so we don't need to capture the result
        await updateDog(updatedDog)
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
    
    func deleteFeedingRecord(_ record: FeedingRecord, from dog: Dog) async {
        isLoading = true
        errorMessage = nil
        
        print("🗑️ Attempting to delete feeding record: \(record.id) for dog: \(dog.name)")
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].feedingRecords.removeAll { $0.id == record.id }
                self.dogs[index].updatedAt = Date()
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
                    self.dogs[index].feedingRecords.append(record)
                    print("🔄 Reverted feeding record in local cache due to CloudKit failure")
                }
            }
        }
        
        isLoading = false
    }
    
    func deleteMedicationRecord(_ record: MedicationRecord, from dog: Dog) async {
        isLoading = true
        errorMessage = nil
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].medicationRecords.removeAll { $0.id == record.id }
                self.dogs[index].updatedAt = Date()
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
                    self.dogs[index].medicationRecords.append(record)
                }
            }
        }
        
        isLoading = false
    }
    
    func deletePottyRecord(_ record: PottyRecord, from dog: Dog) async {
        isLoading = true
        errorMessage = nil
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].pottyRecords.removeAll { $0.id == record.id }
                self.dogs[index].updatedAt = Date()
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
                    self.dogs[index].pottyRecords.append(record)
                }
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Record Management
    
    func addPottyRecord(to dog: Dog, type: PottyRecord.PottyType, notes: String? = nil, recordedBy: String?) async {
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
                self.dogs[index].pottyRecords.append(newRecord)
                self.dogs[index].updatedAt = Date()
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
                    self.dogs[index].pottyRecords.removeLast()
                }
            }
        }
        
        isLoading = false
    }
    
    func updatePottyRecordNotes(_ record: PottyRecord, newNotes: String?, in dog: Dog) async {
        isLoading = true
        errorMessage = nil
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
               let recordIndex = self.dogs[dogIndex].pottyRecords.firstIndex(where: { $0.id == record.id }) {
                self.dogs[dogIndex].pottyRecords[recordIndex].notes = newNotes
                self.dogs[dogIndex].updatedAt = Date()
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
                   let recordIndex = self.dogs[dogIndex].pottyRecords.firstIndex(where: { $0.id == record.id }) {
                    self.dogs[dogIndex].pottyRecords[recordIndex].notes = record.notes
                }
            }
        }
        
        isLoading = false
    }
    
    func addFeedingRecord(to dog: Dog, type: FeedingRecord.FeedingType, notes: String? = nil, recordedBy: String?) async {
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
                self.dogs[index].feedingRecords.append(newRecord)
                self.dogs[index].updatedAt = Date()
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
                    self.dogs[index].feedingRecords.removeLast()
                }
            }
        }
        
        isLoading = false
    }
    
    func updateFeedingRecordNotes(_ record: FeedingRecord, newNotes: String?, in dog: Dog) async {
        isLoading = true
        errorMessage = nil
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
               let recordIndex = self.dogs[dogIndex].feedingRecords.firstIndex(where: { $0.id == record.id }) {
                self.dogs[dogIndex].feedingRecords[recordIndex].notes = newNotes
                self.dogs[dogIndex].updatedAt = Date()
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
                   let recordIndex = self.dogs[dogIndex].feedingRecords.firstIndex(where: { $0.id == record.id }) {
                    self.dogs[dogIndex].feedingRecords[recordIndex].notes = record.notes
                }
            }
        }
        
        isLoading = false
    }
    
    func updateFeedingRecordTimestamp(_ record: FeedingRecord, newTimestamp: Date, in dog: Dog) async {
        isLoading = true
        errorMessage = nil
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
               let recordIndex = self.dogs[dogIndex].feedingRecords.firstIndex(where: { $0.id == record.id }) {
                self.dogs[dogIndex].feedingRecords[recordIndex].timestamp = newTimestamp
                self.dogs[dogIndex].updatedAt = Date()
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
                   let recordIndex = self.dogs[dogIndex].feedingRecords.firstIndex(where: { $0.id == record.id }) {
                    self.dogs[dogIndex].feedingRecords[recordIndex].timestamp = record.timestamp
                }
            }
        }
        
        isLoading = false
    }
    
    func updatePottyRecordTimestamp(_ record: PottyRecord, newTimestamp: Date, in dog: Dog) async {
        isLoading = true
        errorMessage = nil
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
               let recordIndex = self.dogs[dogIndex].pottyRecords.firstIndex(where: { $0.id == record.id }) {
                self.dogs[dogIndex].pottyRecords[recordIndex].timestamp = newTimestamp
                self.dogs[dogIndex].updatedAt = Date()
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
                   let recordIndex = self.dogs[dogIndex].pottyRecords.firstIndex(where: { $0.id == record.id }) {
                    self.dogs[dogIndex].pottyRecords[recordIndex].timestamp = record.timestamp
                }
            }
        }
        
        isLoading = false
    }
    
    func addMedicationRecord(to dog: Dog, notes: String?, recordedBy: String?) async {
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
                self.dogs[index].medicationRecords.append(newRecord)
                self.dogs[index].updatedAt = Date()
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
                    self.dogs[index].medicationRecords.removeLast()
                }
            }
        }
        
        isLoading = false
    }
    
    func updateMedicationRecordTimestamp(_ record: MedicationRecord, newTimestamp: Date, in dog: Dog) async {
        isLoading = true
        errorMessage = nil
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let dogIndex = self.dogs.firstIndex(where: { $0.id == dog.id }),
               let recordIndex = self.dogs[dogIndex].medicationRecords.firstIndex(where: { $0.id == record.id }) {
                self.dogs[dogIndex].medicationRecords[recordIndex].timestamp = newTimestamp
                self.dogs[dogIndex].updatedAt = Date()
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
                   let recordIndex = self.dogs[dogIndex].medicationRecords.firstIndex(where: { $0.id == record.id }) {
                    self.dogs[dogIndex].medicationRecords[recordIndex].timestamp = record.timestamp
                }
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Search and Filtering
    
    func searchDogs(query: String) async -> [Dog] {
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
    
    private func updateDogsCache(with changedDogs: [Dog]) async {
        print("🔄 DataManager: Updating cache with \(changedDogs.count) changed dogs")
        
        // Convert to CloudKitDogs for cache update
        let cloudKitDogs = changedDogs.map { $0.toCloudKitDog() }
        
        // Update the CloudKit service cache with only changed dogs
        cloudKitService.updateDogCacheIncremental(cloudKitDogs)
        
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
                var updatedDog = dog
                
                // Clear daily instances but keep totals
                // The totals are calculated from all records, so they'll still be accurate
                // We're just clearing the display lists for the current day
                
                updatedDog.updatedAt = Date()
                updatedDog.lastModifiedBy = AuthenticationService.shared.currentUser
                
                await updateDog(updatedDog)
            }
        }
        
        print("✅ Daily reset completed")
    }
    
    // MARK: - Optimized Dog Operations
    
    func checkoutDog(_ dog: Dog) async {
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
                self.dogs[index].departureDate = Date()
                self.dogs[index].updatedAt = Date()
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
                        self.dogs[index].updatedAt = dog.updatedAt
                        print("🔄 Reverted checkout in local cache due to CloudKit failure")
                    }
                }
            }
        }
        
        #if DEBUG
        isLoading = false
        #endif
    }
    
    func extendBoardingOptimized(for dog: Dog, newEndDate: Date) async {
        isLoading = true
        errorMessage = nil
        
        print("🔄 Starting optimized extend boarding for dog: \(dog.name)")
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].boardingEndDate = newEndDate
                self.dogs[index].updatedAt = Date()
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
                    self.dogs[index].updatedAt = dog.updatedAt
                    print("🔄 Reverted extend boarding in local cache due to CloudKit failure")
                }
            }
        }
        
        isLoading = false
    }
    
    func boardDogOptimized(_ dog: Dog, endDate: Date) async {
        isLoading = true
        errorMessage = nil
        
        print("🔄 Starting optimized board conversion for dog: \(dog.name)")
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].isBoarding = true
                self.dogs[index].boardingEndDate = endDate
                self.dogs[index].updatedAt = Date()
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
                    self.dogs[index].updatedAt = dog.updatedAt
                    print("🔄 Reverted board conversion in local cache due to CloudKit failure")
                }
            }
        }
        
        isLoading = false
    }

    func undoDepartureOptimized(for dog: Dog) async {
        isLoading = true
        errorMessage = nil
        print("🔄 Starting optimized undo departure for dog: \(dog.name)")
        
        // Log the undo departure action
        await logDogActivity(action: "UNDO_DEPARTURE", dog: dog, extra: "Undoing departure - setting departure date to nil")
        
        // Update local cache immediately
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].departureDate = nil
                self.dogs[index].updatedAt = Date()
                print("✅ Local cache updated for undo departure")
            }
        }
        // Update CloudKit
        do {
            try await cloudKitService.undoDepartureOptimized(dog.id.uuidString)
            print("✅ Undo departure completed in CloudKit for \(dog.name)")
        } catch {
            print("❌ Failed to undo departure in CloudKit: \(error)")
            // Revert local cache if CloudKit update failed
            await MainActor.run {
                if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                    self.dogs[index].departureDate = dog.departureDate
                    self.dogs[index].updatedAt = dog.updatedAt
                    print("🔄 Reverted undo departure in local cache due to CloudKit failure")
                }
            }
        }
        isLoading = false
    }

    func editDepartureOptimized(for dog: Dog, newDate: Date) async {
        isLoading = true
        errorMessage = nil
        print("🔄 Starting optimized edit departure for dog: \(dog.name)")
        
        // Log the edit departure action
        await logDogActivity(action: "EDIT_DEPARTURE", dog: dog, extra: "Editing departure date to: \(newDate.formatted())")
        
        // Update local cache immediately
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].departureDate = newDate
                self.dogs[index].updatedAt = Date()
                print("✅ Local cache updated for edit departure")
            }
        }
        // Update CloudKit
        do {
            try await cloudKitService.editDepartureOptimized(dog.id.uuidString, newDate: newDate)
            print("✅ Edit departure completed in CloudKit for \(dog.name)")
        } catch {
            print("❌ Failed to edit departure in CloudKit: \(error)")
            // Revert local cache if CloudKit update failed
            await MainActor.run {
                if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                    self.dogs[index].departureDate = dog.departureDate
                    self.dogs[index].updatedAt = dog.updatedAt
                    print("🔄 Reverted edit departure in local cache due to CloudKit failure")
                }
            }
        }
        isLoading = false
    }

    func setArrivalTimeOptimized(for dog: Dog, newArrivalTime: Date) async {
        isLoading = true
        errorMessage = nil
        
        print("🔄 Starting optimized set arrival time for dog: \(dog.name)")
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].arrivalDate = newArrivalTime
                self.dogs[index].isArrivalTimeSet = true
                self.dogs[index].updatedAt = Date()
                print("✅ Updated local cache for set arrival time")
            }
        }
        
        // Update CloudKit with only the arrival time
        do {
            try await cloudKitService.setArrivalTimeOptimized(dog.id.uuidString, newArrivalTime: newArrivalTime)
            print("✅ Set arrival time completed in CloudKit for \(dog.name)")
        } catch {
            print("❌ Failed to set arrival time in CloudKit: \(error)")
            // Revert local cache if CloudKit update failed
            await MainActor.run {
                if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                    self.dogs[index].arrivalDate = dog.arrivalDate
                    self.dogs[index].isArrivalTimeSet = dog.isArrivalTimeSet
                    self.dogs[index].updatedAt = dog.updatedAt
                    print("🔄 Reverted set arrival time in local cache due to CloudKit failure")
                }
            }
        }
        
        isLoading = false
    }

    func fetchAllDogsIncludingDeleted() async {
        isLoading = true
        errorMessage = nil
        
        print("🔍 DataManager: Starting fetchAllDogsIncludingDeleted...")
        
        do {
            let cloudKitDogs = try await cloudKitService.fetchAllDogsIncludingDeleted()
            print("🔍 DataManager: Got \(cloudKitDogs.count) CloudKit dogs (including deleted)")
            
            let localDogs = cloudKitDogs.map { $0.toDog() }
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
            let changedLocalDogs = changedCloudKitDogs.map { $0.toDog() }
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
    
    func fetchDogsForImport() async -> [Dog] {
        print("🚀 DataManager: Starting optimized fetchDogsForImport...")
        
        // Check cache first
        let cachedCloudKitDogs = cloudKitService.getCachedDogs()
        if !cachedCloudKitDogs.isEmpty {
            print("✅ DataManager: Using cached dogs (\(cachedCloudKitDogs.count) dogs)")
            return cachedCloudKitDogs.map { $0.toDog() }
        }
        
        do {
            let cloudKitDogs = try await cloudKitService.fetchDogsForImport()
            print("✅ DataManager: Got \(cloudKitDogs.count) optimized CloudKit dogs")
            
            // Update cache
            cloudKitService.updateDogCache(cloudKitDogs)
            
            let localDogs = cloudKitDogs.map { $0.toDog() }
            print("✅ DataManager: Converted to \(localDogs.count) local dogs")
            
            return localDogs
        } catch {
            print("❌ DataManager: Failed to fetch dogs for import: \(error)")
            return []
        }
    }
    
    func fetchSpecificDogWithRecords(for dogID: String) async -> Dog? {
        print("🔍 DataManager: Fetching specific dog with records: \(dogID)")
        
        do {
            guard let cloudKitDog = try await cloudKitService.fetchDogWithRecords(for: dogID) else {
                print("❌ DataManager: Dog not found: \(dogID)")
                return nil
            }
            
            let localDog = cloudKitDog.toDog()
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
    
    func logDogActivity(action: String, dog: Dog, extra: String = "") async {
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

    private func logDeletion(dog: Dog, callStack: String) async {
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
}

// MARK: - Conversion Extensions

extension CloudKitDog {
    func toDog() -> Dog {
        var dog = Dog(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            ownerName: ownerName,
            arrivalDate: arrivalDate,
            isBoarding: isBoarding,

            specialInstructions: nil, // This field doesn't exist in CloudKitDog
            allergiesAndFeedingInstructions: allergiesAndFeedingInstructions,
            needsWalking: needsWalking,
            walkingNotes: walkingNotes,
            isDaycareFed: isDaycareFed,
            notes: notes,
            profilePictureData: profilePictureData,
            isArrivalTimeSet: isArrivalTimeSet,
            isDeleted: isDeleted
        )
        // Copy additional properties
        dog.departureDate = departureDate
        dog.boardingEndDate = boardingEndDate
        dog.createdAt = createdAt
        dog.updatedAt = updatedAt
        // Copy all records
        dog.feedingRecords = feedingRecords
        dog.medicationRecords = medicationRecords
        dog.pottyRecords = pottyRecords
        dog.age = Int(age)
        dog.gender = DogGender(rawValue: gender)
        dog.isNeuteredOrSpayed = isNeuteredOrSpayed
        dog.ownerPhoneNumber = ownerPhoneNumber
        // Build vaccinations array from explicit fields
        dog.vaccinations = [
            VaccinationItem(name: "Bordetella", endDate: bordetellaEndDate),
            VaccinationItem(name: "DHPP", endDate: dhppEndDate),
            VaccinationItem(name: "Rabies", endDate: rabiesEndDate),
            VaccinationItem(name: "CIV", endDate: civEndDate),
            VaccinationItem(name: "Leptospirosis", endDate: leptospirosisEndDate)
        ]
        
        // Reconstruct medications from CloudKit arrays
        var reconstructedMedications: [Medication] = []
        for i in 0..<medicationNames.count {
            if i < medicationTypes.count && i < medicationNotes.count && i < medicationIds.count {
                let type = Medication.MedicationType(rawValue: medicationTypes[i]) ?? .daily
                let medication = Medication(
                    name: medicationNames[i],
                    type: type,
                    notes: medicationNotes[i].isEmpty ? nil : medicationNotes[i]
                )
                // Manually set the ID to preserve the original ID from CloudKit
                var medicationWithId = medication
                medicationWithId.id = UUID(uuidString: medicationIds[i]) ?? UUID()
                reconstructedMedications.append(medicationWithId)
            }
        }
        dog.medications = reconstructedMedications
        
        // Reconstruct scheduled medications from CloudKit arrays
        var reconstructedScheduledMedications: [ScheduledMedication] = []
        for i in 0..<scheduledMedicationDates.count {
            if i < scheduledMedicationStatuses.count && i < scheduledMedicationNotes.count && i < scheduledMedicationIds.count {
                let status = ScheduledMedication.ScheduledMedicationStatus(rawValue: scheduledMedicationStatuses[i]) ?? .pending
                let medicationId = UUID(uuidString: scheduledMedicationIds[i]) ?? UUID()
                
                let scheduledMedication = ScheduledMedication(
                    medicationId: medicationId, // Use the preserved medication ID
                    scheduledDate: scheduledMedicationDates[i],
                    notificationTime: scheduledMedicationDates[i], // Use scheduled date as notification time for now
                    status: status,
                    notes: scheduledMedicationNotes[i].isEmpty ? nil : scheduledMedicationNotes[i]
                )
                reconstructedScheduledMedications.append(scheduledMedication)
            }
        }
        dog.scheduledMedications = reconstructedScheduledMedications
        
        return dog
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

extension Dog {
    func toCloudKitDog() -> CloudKitDog {
        // Extract end dates from vaccinations array
        func endDate(for name: String) -> Date? {
            vaccinations.first(where: { $0.name == name })?.endDate
        }
        
        // Convert medications to CloudKit arrays
        let medicationNames = medications.map { $0.name }
        let medicationTypes = medications.map { $0.type.rawValue }
        let medicationNotes = medications.map { $0.notes ?? "" }
        let medicationIds = medications.map { $0.id.uuidString }
        
        // Convert scheduled medications to CloudKit arrays
        let scheduledMedicationDates = scheduledMedications.map { $0.scheduledDate }
        let scheduledMedicationStatuses = scheduledMedications.map { $0.status.rawValue }
        let scheduledMedicationNotes = scheduledMedications.map { $0.notes ?? "" }
        let scheduledMedicationIds = scheduledMedications.map { $0.medicationId.uuidString }
        
        return CloudKitDog(
            id: id.uuidString,
            name: name,
            ownerName: ownerName,
            arrivalDate: arrivalDate,
            departureDate: departureDate,
            boardingEndDate: boardingEndDate,
            isBoarding: isBoarding,
            isDaycareFed: isDaycareFed,
            needsWalking: needsWalking,
            walkingNotes: walkingNotes,
            allergiesAndFeedingInstructions: allergiesAndFeedingInstructions,
            notes: notes,
            profilePictureData: profilePictureData,
            feedingRecords: feedingRecords,
            medicationRecords: medicationRecords,
            pottyRecords: pottyRecords,
            isArrivalTimeSet: isArrivalTimeSet,
            isDeleted: isDeleted,
            age: age != nil ? String(age!) : "",
            gender: gender?.rawValue ?? "unknown",
            bordetellaEndDate: endDate(for: "Bordetella"),
            dhppEndDate: endDate(for: "DHPP"),
            rabiesEndDate: endDate(for: "Rabies"),
            civEndDate: endDate(for: "CIV"),
            leptospirosisEndDate: endDate(for: "Leptospirosis"),
            isNeuteredOrSpayed: isNeuteredOrSpayed ?? false,
            ownerPhoneNumber: ownerPhoneNumber,
            medicationNames: medicationNames,
            medicationTypes: medicationTypes,
            medicationNotes: medicationNotes,
            medicationIds: medicationIds,
            scheduledMedicationDates: scheduledMedicationDates,
            scheduledMedicationStatuses: scheduledMedicationStatuses,
            scheduledMedicationNotes: scheduledMedicationNotes,
            scheduledMedicationIds: scheduledMedicationIds
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