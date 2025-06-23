import Foundation

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var dogs: [Dog] = []
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let cloudKitService = CloudKitService.shared
    
    private init() {
        print("📱 DataManager initialized")
    }
    
    // MARK: - Authentication
    
    func authenticate() async throws {
        try await cloudKitService.authenticate()
        // After successful authentication, fetch the data
        await fetchDogs()
        await fetchUsers()
    }
    
    // MARK: - Dog Management
    
    func fetchDogs() async {
        isLoading = true
        errorMessage = nil
        
        print("🔍 DataManager: Starting fetchDogs...")
        do {
            let cloudKitDogs = try await cloudKitService.fetchDogs()
            print("🔍 DataManager: Got \(cloudKitDogs.count) CloudKit dogs")
            
            let localDogs = cloudKitDogs.map { $0.toDog() }
            print("🔍 DataManager: Converted to \(localDogs.count) local dogs")
            
            await MainActor.run {
                self.dogs = localDogs
                self.isLoading = false
                print("✅ DataManager: Set \(localDogs.count) dogs in local array")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch dogs: \(error.localizedDescription)"
                self.isLoading = false
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
        isLoading = true
        errorMessage = nil
        do {
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
            // Copy all the records
            updatedDog.feedingRecords = dog.feedingRecords
            updatedDog.medicationRecords = dog.medicationRecords
            updatedDog.pottyRecords = dog.pottyRecords
            updatedDog.walkingRecords = dog.walkingRecords
            // Copy additional properties
            updatedDog.boardingEndDate = dog.boardingEndDate
            updatedDog.departureDate = dog.departureDate
            updatedDog.updatedAt = Date()
            updatedDog.createdAt = dog.createdAt
            updatedDog.createdBy = dog.createdBy
            updatedDog.lastModifiedBy = dog.lastModifiedBy
            _ = try await cloudKitService.updateDog(updatedDog.toCloudKitDog())
            // Update local cache
            if let index = dogs.firstIndex(where: { $0.id == dog.id }) {
                dogs[index] = updatedDog
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
        do {
            let cloudKitDog = dog.toCloudKitDog()
            try await cloudKitService.deleteDog(cloudKitDog)
            await MainActor.run {
                self.dogs.removeAll { $0.id == dog.id }
                self.isLoading = false
                print("✅ Deleted dog: \(dog.name)")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to delete dog: \(error.localizedDescription)"
                self.isLoading = false
                print("❌ Failed to delete dog: \(error)")
            }
        }
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
    
    func updateUser(_ user: User) async {
        isLoading = true
        errorMessage = nil
        do {
            let cloudKitUser = user.toCloudKitUser()
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
        var updatedDog = dog
        updatedDog.feedingRecords.removeAll { $0.id == record.id }
        await updateDog(updatedDog)
        
        // Also delete from CloudKit
        do {
            try await cloudKitService.deleteFeedingRecord(record, for: dog.id.uuidString)
        } catch {
            print("❌ Failed to delete feeding record from CloudKit: \(error)")
        }
    }
    
    func deleteMedicationRecord(_ record: MedicationRecord, from dog: Dog) async {
        isLoading = true
        errorMessage = nil
        var updatedDog = dog
        updatedDog.medicationRecords.removeAll { $0.id == record.id }
        await updateDog(updatedDog)
        
        // Also delete from CloudKit
        do {
            try await cloudKitService.deleteMedicationRecord(record, for: dog.id.uuidString)
        } catch {
            print("❌ Failed to delete medication record from CloudKit: \(error)")
        }
    }
    
    func deletePottyRecord(_ record: PottyRecord, from dog: Dog) async {
        isLoading = true
        errorMessage = nil
        var updatedDog = dog
        updatedDog.pottyRecords.removeAll { $0.id == record.id }
        await updateDog(updatedDog)
        
        // Also delete from CloudKit
        do {
            try await cloudKitService.deletePottyRecord(record, for: dog.id.uuidString)
        } catch {
            print("❌ Failed to delete potty record from CloudKit: \(error)")
        }
    }
    
    func deleteWalkingRecord(_ record: WalkingRecord, from dog: Dog) async {
        isLoading = true
        errorMessage = nil
        var updatedDog = dog
        updatedDog.walkingRecords.removeAll { $0.id == record.id }
        await updateDog(updatedDog)
        
        // Also delete from CloudKit
        do {
            try await cloudKitService.deleteWalkingRecord(record, for: dog.id.uuidString)
        } catch {
            print("❌ Failed to delete walking record from CloudKit: \(error)")
        }
    }
    
    // MARK: - Record Management
    
    func addPottyRecord(to dog: Dog, type: PottyRecord.PottyType, recordedBy: String?) async {
        isLoading = true
        errorMessage = nil
        var updatedDog = dog
        updatedDog.addPottyRecord(type: type, recordedBy: nil)
        await updateDog(updatedDog)
    }
    
    func addFeedingRecord(to dog: Dog, type: FeedingRecord.FeedingType, recordedBy: String?) async {
        isLoading = true
        errorMessage = nil
        var updatedDog = dog
        updatedDog.addFeedingRecord(type: type, recordedBy: nil)
        await updateDog(updatedDog)
    }
    
    func addMedicationRecord(to dog: Dog, notes: String?, recordedBy: String?) async {
        isLoading = true
        errorMessage = nil
        var updatedDog = dog
        updatedDog.addMedicationRecord(notes: notes, recordedBy: nil)
        await updateDog(updatedDog)
    }
    
    func addWalkingRecord(to dog: Dog, notes: String?, recordedBy: String?) async {
        isLoading = true
        errorMessage = nil
        var updatedDog = dog
        updatedDog.addWalkingRecord(notes: notes, recordedBy: nil)
        await updateDog(updatedDog)
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
        await fetchDogs()
        await fetchUsers()
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
            isArrivalTimeSet: isArrivalTimeSet
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
            isOriginalOwner: isOriginalOwner
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
            isArrivalTimeSet: isArrivalTimeSet
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
            isOriginalOwner: isOriginalOwner
        )
    }
} 