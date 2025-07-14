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
                self.dogs = localDogs
                if shouldShowLoading {
                    self.isLoading = false
                }
                print("✅ DataManager: Set \(localDogs.count) dogs in local array")
                
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
    
    func addDog(_ dog: Dog) async {
        isLoading = true
        errorMessage = nil
        do {
            let cloudKitDog = dog.toCloudKitDog()
            let addedCloudKitDog = try await cloudKitService.createDog(cloudKitDog)
            let addedDog = addedCloudKitDog.toDog()
            await MainActor.run {
                self.dogs.append(addedDog)
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
    
    func updateDog(_ dog: Dog) async {
        print("🔄 DataManager.updateDog called for: \(dog.name)")
        print("📅 Departure date being set: \(dog.departureDate?.description ?? "nil")")
        
        isLoading = true
        errorMessage = nil
        do {
            var updatedDog = Dog(
                id: dog.id,
                name: dog.name,
                ownerName: dog.ownerName,
                arrivalDate: dog.arrivalDate,
                isBoarding: dog.isBoarding,
                boardingEndDate: dog.boardingEndDate,
                medications: dog.medications,
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
                vaccinationEndDate: dog.vaccinationEndDate,
                isNeuteredOrSpayed: dog.isNeuteredOrSpayed,
                ownerPhoneNumber: dog.ownerPhoneNumber
            )
            // Copy all the records
            updatedDog.feedingRecords = dog.feedingRecords
            updatedDog.medicationRecords = dog.medicationRecords
            updatedDog.pottyRecords = dog.pottyRecords
            updatedDog.walkingRecords = dog.walkingRecords
            // Copy additional properties
            updatedDog.departureDate = dog.departureDate
            updatedDog.updatedAt = Date()
            updatedDog.createdAt = dog.createdAt
            updatedDog.createdBy = dog.createdBy
            updatedDog.lastModifiedBy = dog.lastModifiedBy
            
            print("📅 Updated dog departure date: \(updatedDog.departureDate?.description ?? "nil")")
            print("🔄 Calling CloudKit update...")
            
            _ = try await cloudKitService.updateDog(updatedDog.toCloudKitDog())
            
            print("✅ CloudKit update successful")
            
            // Update local cache
            if let index = dogs.firstIndex(where: { $0.id == dog.id }) {
                dogs[index] = updatedDog
                print("✅ Local cache updated")
            } else {
                print("⚠️ Dog not found in local cache for update")
            }
            
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update dog: \(error.localizedDescription)"
                self.isLoading = false
                print("❌ Failed to update dog: \(error)")
            }
        }
    }
    
    func deleteDog(_ dog: Dog) async {
        isLoading = true
        errorMessage = nil
        
        print("🔄 Starting delete dog: \(dog.name)")
        
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
        
        isLoading = false
    }
    
    func permanentlyDeleteDog(_ dog: Dog) async {
        isLoading = true
        errorMessage = nil
        
        print("🔄 Starting permanent delete dog from database: \(dog.name)")
        
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
            medications: dog.medications,
            specialInstructions: dog.specialInstructions,
            allergiesAndFeedingInstructions: dog.allergiesAndFeedingInstructions,
            needsWalking: dog.needsWalking,
            walkingNotes: dog.walkingNotes,
            isDaycareFed: dog.isDaycareFed,
            notes: dog.notes,
            profilePictureData: dog.profilePictureData,
            isArrivalTimeSet: dog.isArrivalTimeSet
        )
        updatedDog.boardingEndDate = newEndDate
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
    
    func deleteWalkingRecord(_ record: WalkingRecord, from dog: Dog) async {
        isLoading = true
        errorMessage = nil
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].walkingRecords.removeAll { $0.id == record.id }
                self.dogs[index].updatedAt = Date()
            }
        }
        
        // Update CloudKit with only the deletion
        do {
            try await cloudKitService.deleteWalkingRecord(record, for: dog.id.uuidString)
            print("✅ Walking record deleted from CloudKit for \(dog.name)")
        } catch {
            print("❌ Failed to delete walking record from CloudKit: \(error)")
            // Revert local cache if CloudKit update failed
            await MainActor.run {
                if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                    self.dogs[index].walkingRecords.append(record)
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
    
    func addWalkingRecord(to dog: Dog, notes: String?, recordedBy: String?) async {
        isLoading = true
        errorMessage = nil
        
        // Create the new record
        let newRecord = WalkingRecord(
            timestamp: Date(),
            notes: notes,
            recordedBy: recordedBy
        )
        
        // Update local cache immediately for responsive UI
        await MainActor.run {
            if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                self.dogs[index].walkingRecords.append(newRecord)
                self.dogs[index].updatedAt = Date()
            }
        }
        
        // Update CloudKit with only the new record
        do {
            try await cloudKitService.addWalkingRecord(newRecord, for: dog.id.uuidString)
            print("✅ Walking record added to CloudKit for \(dog.name)")
        } catch {
            print("❌ Failed to add walking record to CloudKit: \(error)")
            // Revert local cache if CloudKit update failed
            await MainActor.run {
                if let index = self.dogs.firstIndex(where: { $0.id == dog.id }) {
                    self.dogs[index].walkingRecords.removeLast()
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
        
        // Clear cache to force fresh data
        cloudKitService.clearDogCache()
        
        await fetchDogs()
        await fetchUsers()
    }
    
    // MARK: - History Management
    
    private func recordDailySnapshotIfNeeded() async {
        let today = Calendar.current.startOfDay(for: Date())
        
        // Check if we already recorded a snapshot for today
        let todayRecords = historyService.getHistoryForDate(today)
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
        historyService.recordDailySnapshot(dogs: visibleDogs)
        print("📅 Recorded daily snapshot for \(visibleDogs.count) visible dogs")
    }
    
    func clearCache() {
        cloudKitService.clearDogCache()
        print("🧹 DataManager: Cache cleared")
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
                
                // For walking records, we could optionally archive them
                // For now, we'll keep all records but the UI will filter by date
                
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
            medications: medications,
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
        dog.walkingRecords = walkingRecords
        
        dog.age = Int(age)
        dog.gender = DogGender(rawValue: gender)
        dog.vaccinationEndDate = vaccinationEndDate
        dog.isNeuteredOrSpayed = isNeuteredOrSpayed
        dog.ownerPhoneNumber = ownerPhoneNumber
        
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
            medications: medications,
            allergiesAndFeedingInstructions: allergiesAndFeedingInstructions,
            notes: notes,
            profilePictureData: profilePictureData,
            feedingRecords: feedingRecords,
            medicationRecords: medicationRecords,
            pottyRecords: pottyRecords,
            walkingRecords: walkingRecords,
            isArrivalTimeSet: isArrivalTimeSet,
            isDeleted: isDeleted,
            age: age != nil ? String(age!) : "",
            gender: gender?.rawValue ?? "unknown",
            vaccinationEndDate: vaccinationEndDate,
            isNeuteredOrSpayed: isNeuteredOrSpayed ?? false,
            ownerPhoneNumber: ownerPhoneNumber
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