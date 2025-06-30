import CloudKit
import Foundation
import SwiftUI

@MainActor
class CloudKitService: ObservableObject {
    static let shared = CloudKitService()
    
    private let container = CKContainer(identifier: "iCloud.GreenHouse.Doggy-DayCare")
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    
    // Record type names
    struct RecordTypes {
        static let user = "User"
        static let dog = "Dog"
        static let dogChange = "DogChange"
        static let feedingRecord = "FeedingRecord"
        static let medicationRecord = "MedicationRecord"
        static let pottyRecord = "PottyRecord"
        static let walkingRecord = "WalkingRecord"
    }
    
    // Field names for User
    struct UserFields {
        static let id = "id"
        static let name = "name"
        static let email = "email"
        static let isActive = "isActive"
        static let isOwner = "isOwner"
        static let isWorkingToday = "isWorkingToday"
        static let isOriginalOwner = "isOriginalOwner"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
        static let lastLogin = "lastLogin"
        static let scheduledDays = "scheduledDays"
        static let scheduleStartTime = "scheduleStartTime"
        static let scheduleEndTime = "scheduleEndTime"
        static let canAddDogs = "canAddDogs"
        static let canAddFutureBookings = "canAddFutureBookings"
        static let canManageStaff = "canManageStaff"
        static let canManageMedications = "canManageMedications"
        static let canManageFeeding = "canManageFeeding"
        static let canManageWalking = "canManageWalking"
        static let hashedPassword = "hashedPassword"
        static let cloudKitUserID = "cloudKitUserID"
        
        // Audit fields
        static let createdBy = "createdBy"
        static let modifiedBy = "modifiedBy"
        static let modificationCount = "modificationCount"
    }
    
    // Field names for Dog
    struct DogFields {
        static let id = "id"
        static let name = "name"
        static let ownerName = "ownerName"
        static let arrivalDate = "arrivalDate"
        static let departureDate = "departureDate"
        static let boardingEndDate = "boardingEndDate"
        static let isBoarding = "isBoarding"
        static let isDaycareFed = "isDaycareFed"
        static let needsWalking = "needsWalking"
        static let walkingNotes = "walkingNotes"
        static let medications = "medications"
        static let allergiesAndFeedingInstructions = "allergiesAndFeedingInstructions"
        static let notes = "notes"
        static let profilePictureData = "profilePictureData"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
        static let isArrivalTimeSet = "isArrivalTimeSet"
        static let isDeleted = "isDeleted"  // Added field for deleted status
        
        // Audit fields
        static let createdBy = "createdBy"
        static let modifiedBy = "modifiedBy"
        static let modificationCount = "modificationCount"
    }
    
    // Field names for Records (Feeding, Medication, Potty)
    struct RecordFields {
        static let id = "id"
        static let timestamp = "timestamp"
        static let notes = "notes"
        static let recordedBy = "recordedBy"
        static let dogID = "dogID"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
        
        // Type-specific fields
        static let type = "type" // for potty and feeding records
    }
    
    // Field names for DogChange (audit trail)
    struct DogChangeFields {
        static let id = "id"
        static let timestamp = "timestamp"
        static let changeType = "changeType"
        static let fieldName = "fieldName"
        static let oldValue = "oldValue"
        static let newValue = "newValue"
        static let dogID = "dogID"
        static let modifiedBy = "modifiedBy"
        static let createdAt = "createdAt"
    }
    
    @Published var isAuthenticated = false
    @Published var currentUser: CloudKitUser?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {
        self.publicDatabase = container.publicCloudDatabase
        self.privateDatabase = container.privateCloudDatabase
        
        // Debug information
        print("🔧 CloudKit container: \(container.containerIdentifier ?? "Unknown")")
        print("🔧 Public database: \(publicDatabase)")
        print("🔧 Private database: \(privateDatabase)")
    }
    
    // MARK: - Authentication
    
    func authenticate() async throws {
        isLoading = true
        errorMessage = nil
        do {
            let userRecordID = try await container.userRecordID()
            let userRecord = try await privateDatabase.record(for: userRecordID)

            // Set up CloudKit schema first
            await setupCloudKitSchema()
            await testSchemaAccess()

            // Fetch all users to check for original owner
            let allUsers = try await fetchAllUsers()
            let originalOwner = allUsers.first(where: { $0.isOriginalOwner })

            // Check if user exists in our system
            if let existingUser = try await fetchUser(by: userRecordID.recordName) {
                currentUser = existingUser
                isAuthenticated = true
                print("✅ User authenticated: \(existingUser.name)")
            } else if originalOwner == nil {
                // Only allow creation if no original owner exists
                guard let name = userRecord["name"] as? String, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
                    errorMessage = "Your iCloud account does not have a name set. Please set your name in iCloud settings before using this app."
                    isAuthenticated = false
                    print("❌ Cannot create user: iCloud name is missing.")
                    return
                }
                // Create new original owner
                let newUser = CloudKitUser(
                    id: userRecordID.recordName,
                    name: name,
                    email: userRecord["email"] as? String,
                    isOwner: true,
                    isActive: true,
                    isWorkingToday: true,
                    isOriginalOwner: true
                )
                let createdUser = try await createUser(newUser)
                currentUser = createdUser
                isAuthenticated = true
                print("✅ New original owner created and authenticated: \(createdUser.name)")
            } else {
                // Do not create a new user if an original owner already exists
                errorMessage = "An original owner already exists for this business. Please contact the owner to be added as staff."
                isAuthenticated = false
                print("❌ Cannot create user: original owner already exists.")
            }
        } catch {
            errorMessage = "Authentication failed: \(error.localizedDescription)"
            print("❌ Authentication error: \(error)")
            throw error
        }
        isLoading = false
    }
    
    // MARK: - User Management
    
    func createUser(_ user: CloudKitUser) async throws -> CloudKitUser {
        let record = CKRecord(recordType: RecordTypes.user)
        
        // Set user fields
        record[UserFields.id] = user.id
        record[UserFields.name] = user.name
        record[UserFields.email] = user.email
        record[UserFields.isActive] = user.isActive ? 1 : 0
        record[UserFields.isOwner] = user.isOwner ? 1 : 0
        record[UserFields.isWorkingToday] = user.isWorkingToday ? 1 : 0
        record[UserFields.isOriginalOwner] = user.isOriginalOwner ? 1 : 0
        record[UserFields.createdAt] = user.createdAt
        record[UserFields.updatedAt] = user.updatedAt
        record[UserFields.lastLogin] = user.lastLogin
        record[UserFields.scheduledDays] = user.scheduledDays
        record[UserFields.scheduleStartTime] = user.scheduleStartTime
        record[UserFields.scheduleEndTime] = user.scheduleEndTime
        record[UserFields.canAddDogs] = user.canAddDogs ? 1 : 0
        record[UserFields.canAddFutureBookings] = user.canAddFutureBookings ? 1 : 0
        record[UserFields.canManageStaff] = user.canManageStaff ? 1 : 0
        record[UserFields.canManageMedications] = user.canManageMedications ? 1 : 0
        record[UserFields.canManageFeeding] = user.canManageFeeding ? 1 : 0
        record[UserFields.canManageWalking] = user.canManageWalking ? 1 : 0
        record[UserFields.hashedPassword] = user.hashedPassword
        
        // Audit fields
        record[UserFields.createdBy] = user.id
        record[UserFields.modifiedBy] = user.id
        record[UserFields.modificationCount] = 1
        
        let saved = try await publicDatabase.save(record)
        print("✅ User created: \(user.name)")
        return CloudKitUser(from: saved)
    }
    
    func updateUser(_ user: CloudKitUser) async throws -> CloudKitUser {
        let predicate = NSPredicate(format: "\(UserFields.id) == %@", user.id)
        let query = CKQuery(recordType: RecordTypes.user, predicate: predicate)
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        guard let record = records.first else { throw CloudKitError.recordNotFound }
        
        // Update fields
        record[UserFields.name] = user.name
        record[UserFields.email] = user.email
        record[UserFields.isActive] = user.isActive ? 1 : 0
        record[UserFields.isOwner] = user.isOwner ? 1 : 0
        record[UserFields.isWorkingToday] = user.isWorkingToday ? 1 : 0
        record[UserFields.isOriginalOwner] = user.isOriginalOwner ? 1 : 0
        record[UserFields.updatedAt] = Date()
        record[UserFields.lastLogin] = user.lastLogin
        record[UserFields.scheduledDays] = user.scheduledDays
        record[UserFields.scheduleStartTime] = user.scheduleStartTime
        record[UserFields.scheduleEndTime] = user.scheduleEndTime
        record[UserFields.canAddDogs] = user.canAddDogs ? 1 : 0
        record[UserFields.canAddFutureBookings] = user.canAddFutureBookings ? 1 : 0
        record[UserFields.canManageStaff] = user.canManageStaff ? 1 : 0
        record[UserFields.canManageMedications] = user.canManageMedications ? 1 : 0
        record[UserFields.canManageFeeding] = user.canManageFeeding ? 1 : 0
        record[UserFields.canManageWalking] = user.canManageWalking ? 1 : 0
        record[UserFields.hashedPassword] = user.hashedPassword
        
        // Audit fields
        record[UserFields.modifiedBy] = user.id
        record[UserFields.modificationCount] = (record[UserFields.modificationCount] as? Int64 ?? 0) + 1
        
        let saved = try await publicDatabase.save(record)
        print("✅ User updated: \(user.name)")
        return CloudKitUser(from: saved)
    }
    
    func deleteUser(_ user: CloudKitUser) async throws {
        let predicate = NSPredicate(format: "\(UserFields.id) == %@", user.id)
        let query = CKQuery(recordType: RecordTypes.user, predicate: predicate)
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        guard let record = records.first else { throw CloudKitError.recordNotFound }
        try await publicDatabase.deleteRecord(withID: record.recordID)
        print("✅ User deleted: \(user.name)")
    }
    
    func fetchUser(by id: String) async throws -> CloudKitUser? {
        do {
            print("🔍 Fetching user by ID: \(id)")
            let predicate = NSPredicate(format: "\(UserFields.id) == %@", id)
            let query = CKQuery(recordType: RecordTypes.user, predicate: predicate)
            
            print("🔍 User query: \(query)")
            print("🔍 User predicate: \(predicate)")
            
            let result = try await publicDatabase.records(matching: query)
            let records = result.matchResults.compactMap { try? $0.1.get() }
            
            print("🔍 Found \(records.count) user records")
            
            guard let record = records.first else { 
                print("🔍 No user found with ID: \(id)")
                return nil 
            }
            
            return CloudKitUser(from: record)
        } catch let error as CKError {
            print("❌ Fetch user error: \(error)")
            print("❌ Error code: \(error.code.rawValue)")
            print("❌ Error description: \(error.localizedDescription)")
            
            if error.code == .invalidArguments {
                print("⚠️ CloudKit schema not set up yet. User not found.")
                return nil
            } else {
                throw error
            }
        }
    }
    
    func fetchAllUsers() async throws -> [CloudKitUser] {
        do {
            // Use a predicate that checks for a field that exists and is queryable
            let query = CKQuery(recordType: RecordTypes.user, predicate: NSPredicate(format: "\(UserFields.name) != %@", ""))
            
            print("🔍 Executing CloudKit query: \(query)")
            print("🔍 Record type: \(RecordTypes.user)")
            print("🔍 Predicate: \(query.predicate)")
            
            let result = try await publicDatabase.records(matching: query)
            let records = result.matchResults.compactMap { try? $0.1.get() }
            
            print("✅ Found \(records.count) user records")
            return records.map { CloudKitUser(from: $0) }
        } catch let error as CKError {
            print("❌ CloudKit error: \(error)")
            print("❌ Error code: \(error.code.rawValue)")
            print("❌ Error description: \(error.localizedDescription)")
            
            if error.code == .invalidArguments {
                print("⚠️ CloudKit schema not set up yet. Returning empty users list.")
                return []
            } else {
                throw error
            }
        }
    }
    
    // MARK: - Dog Management
    
    func createDog(_ dog: CloudKitDog) async throws -> CloudKitDog {
        let record = CKRecord(recordType: RecordTypes.dog)
        
        // Set dog fields
        record[DogFields.id] = dog.id
        record[DogFields.name] = dog.name
        record[DogFields.ownerName] = dog.ownerName
        record[DogFields.arrivalDate] = dog.arrivalDate
        record[DogFields.departureDate] = dog.departureDate
        record[DogFields.boardingEndDate] = dog.boardingEndDate
        record[DogFields.isBoarding] = dog.isBoarding ? 1 : 0
        record[DogFields.isDaycareFed] = dog.isDaycareFed ? 1 : 0
        record[DogFields.needsWalking] = dog.needsWalking ? 1 : 0
        record[DogFields.walkingNotes] = dog.walkingNotes
        record[DogFields.medications] = dog.medications
        record[DogFields.allergiesAndFeedingInstructions] = dog.allergiesAndFeedingInstructions
        record[DogFields.notes] = dog.notes
        record[DogFields.profilePictureData] = dog.profilePictureData
        record[DogFields.createdAt] = dog.createdAt
        record[DogFields.updatedAt] = dog.updatedAt
        record[DogFields.isArrivalTimeSet] = dog.isArrivalTimeSet ? 1 : 0
        
        // Get the actual CloudKit user record ID (not our app's user ID)
        let cloudKitUserRecordID = try await container.userRecordID()
        print("🔗 Using CloudKit user record ID: \(cloudKitUserRecordID.recordName)")
        
        // Audit fields - use CloudKit's actual user ID
        record[DogFields.createdBy] = cloudKitUserRecordID.recordName
        record[DogFields.modifiedBy] = cloudKitUserRecordID.recordName
        record[DogFields.modificationCount] = 1
        
        // Save the record (without CKShare for now)
        let saved = try await publicDatabase.save(record)
        
        // Create audit trail entry
        try await createDogChange(
            dogID: dog.id,
            changeType: .created,
            fieldName: "dog",
            oldValue: nil,
            newValue: dog.name
        )
        
        print("✅ Dog created: \(dog.name)")
        return CloudKitDog(from: saved)
    }
    
    func deleteDog(_ dog: CloudKitDog) async throws {
        let predicate = NSPredicate(format: "\(DogFields.id) == %@", dog.id)
        let query = CKQuery(recordType: RecordTypes.dog, predicate: predicate)
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let record = records.first else {
            throw CloudKitError.recordNotFound
        }
        
        // Instead of deleting, mark the dog as deleted and set departure date
        record[DogFields.departureDate] = Date()
        record[DogFields.updatedAt] = Date()
        record[DogFields.isDeleted] = 1  // Mark as deleted
        
        // Update audit fields
        guard let currentUser = AuthenticationService.shared.currentUser else {
            throw CloudKitError.userNotAuthenticated
        }
        record[DogFields.modifiedBy] = currentUser.id
        record[DogFields.modificationCount] = (record[DogFields.modificationCount] as? Int64 ?? 0) + 1
        
        // Save the updated record
        try await publicDatabase.save(record)
        
        // Delete all associated records (feeding, medication, potty, walking)
        try await deleteFeedingRecords(for: dog.id)
        try await deleteMedicationRecords(for: dog.id)
        try await deletePottyRecords(for: dog.id)
        try await deleteWalkingRecords(for: dog.id)
        
        // Create audit trail entry
        try await createDogChange(
            dogID: dog.id,
            changeType: .deleted,
            fieldName: "dog",
            oldValue: dog.name,
            newValue: nil
        )
        
        print("✅ Dog marked as deleted (remains in database): \(dog.name)")
    }
    
    func fetchDogs() async throws -> [CloudKitDog] {
        print("🔍 Starting fetchDogs...")
        // Fetch all dogs and filter out deleted ones locally
        let predicate = NSPredicate(format: "\(DogFields.name) != %@", "")
        let query = CKQuery(recordType: RecordTypes.dog, predicate: predicate)
        
        print("🔍 Executing CloudKit query: \(query)")
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        print("🔍 Found \(records.count) total dog records in CloudKit")
        
        var dogs: [CloudKitDog] = []
        
        for record in records {
            print("🔍 Processing dog record: \(record[DogFields.name] as? String ?? "Unknown")")
            var dog = CloudKitDog(from: record)
            
            // Skip deleted dogs
            if dog.isDeleted {
                print("⏭️ Skipping deleted dog: \(dog.name)")
                continue
            }
            
            // Load records for this dog
            do {
                let (feeding, medication, potty, walking) = try await loadRecords(for: dog.id)
                dog.feedingRecords = feeding
                dog.medicationRecords = medication
                dog.pottyRecords = potty
                dog.walkingRecords = walking
                print("✅ Loaded \(feeding.count) feeding, \(medication.count) medication, \(potty.count) potty, \(walking.count) walking records for \(dog.name)")
            } catch {
                print("⚠️ Failed to load records for dog \(dog.name): \(error)")
            }
            
            dogs.append(dog)
        }
        
        // Sort dogs by creation date locally
        dogs.sort { $0.createdAt > $1.createdAt }
        
        print("✅ Fetched \(dogs.count) active dogs from CloudKit")
        return dogs
    }
    
    func updateDog(_ dog: CloudKitDog) async throws -> CloudKitDog {
        print("🔄 CloudKitService.updateDog called for: \(dog.name)")
        print("📅 CloudKit dog departure date: \(dog.departureDate?.description ?? "nil")")
        
        let predicate = NSPredicate(format: "\(DogFields.id) == %@", dog.id)
        let query = CKQuery(recordType: RecordTypes.dog, predicate: predicate)
        
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let record = records.first else {
            print("❌ Dog record not found in CloudKit")
            throw CloudKitError.recordNotFound
        }
        
        print("📅 Original record departure date: \(record[DogFields.departureDate]?.description ?? "nil")")
        
        // Update fields
        record[DogFields.name] = dog.name
        record[DogFields.ownerName] = dog.ownerName
        record[DogFields.arrivalDate] = dog.arrivalDate
        record[DogFields.departureDate] = dog.departureDate
        record[DogFields.boardingEndDate] = dog.boardingEndDate
        record[DogFields.isBoarding] = dog.isBoarding ? 1 : 0
        record[DogFields.isDaycareFed] = dog.isDaycareFed ? 1 : 0
        record[DogFields.needsWalking] = dog.needsWalking ? 1 : 0
        record[DogFields.walkingNotes] = dog.walkingNotes
        record[DogFields.medications] = dog.medications
        record[DogFields.allergiesAndFeedingInstructions] = dog.allergiesAndFeedingInstructions
        record[DogFields.notes] = dog.notes
        record[DogFields.profilePictureData] = dog.profilePictureData
        record[DogFields.updatedAt] = Date()
        record[DogFields.isArrivalTimeSet] = dog.isArrivalTimeSet ? 1 : 0
        
        print("📅 Updated record departure date: \(record[DogFields.departureDate]?.description ?? "nil")")
        
        // Update audit fields - get current user from AuthenticationService
        guard let currentUser = AuthenticationService.shared.currentUser else {
            print("❌ No authenticated user found in AuthenticationService")
            throw CloudKitError.userNotAuthenticated
        }
        
        print("👤 Using authenticated user: \(currentUser.name) (ID: \(currentUser.id))")
        record[DogFields.modifiedBy] = currentUser.id
        record[DogFields.modificationCount] = (record[DogFields.modificationCount] as? Int64 ?? 0) + 1
        
        print("🔄 Saving record to CloudKit...")
        let saved = try await publicDatabase.save(record)
        
        print("✅ Record saved successfully")
        print("📅 Saved record departure date: \(saved[DogFields.departureDate]?.description ?? "nil")")
        
        // Save individual records
        try await saveFeedingRecords(dog.feedingRecords, for: dog.id)
        try await saveMedicationRecords(dog.medicationRecords, for: dog.id)
        try await savePottyRecords(dog.pottyRecords, for: dog.id)
        try await saveWalkingRecords(dog.walkingRecords, for: dog.id)
        
        // Create audit trail entry
        try await createDogChange(
            dogID: dog.id,
            changeType: .updated,
            fieldName: "dog",
            oldValue: nil,
            newValue: dog.name
        )
        
        print("✅ Dog updated: \(dog.name)")
        return CloudKitDog(from: saved)
    }
    
    // MARK: - Record Management
    
    private func saveFeedingRecords(_ records: [FeedingRecord], for dogID: String) async throws {
        do {
            // First, delete existing records for this dog
            try await deleteFeedingRecords(for: dogID)
            
            // Then save new records
            for record in records {
                let ckRecord = CKRecord(recordType: RecordTypes.feedingRecord)
                ckRecord[RecordFields.id] = record.id.uuidString
                ckRecord[RecordFields.timestamp] = record.timestamp
                ckRecord[RecordFields.type] = record.type.rawValue
                ckRecord[RecordFields.notes] = record.notes
                ckRecord[RecordFields.recordedBy] = record.recordedBy
                ckRecord[RecordFields.dogID] = dogID
                ckRecord[RecordFields.createdAt] = Date()
                ckRecord[RecordFields.updatedAt] = Date()
                
                try await publicDatabase.save(ckRecord)
            }
            print("✅ Saved \(records.count) feeding records for dog: \(dogID)")
        } catch let error as CKError {
            if error.code == .unknownItem {
                print("⚠️ FeedingRecord type doesn't exist yet for dog \(dogID) - records will be saved when schema is created")
            } else {
                throw error
            }
        }
    }
    
    private func saveMedicationRecords(_ records: [MedicationRecord], for dogID: String) async throws {
        do {
            // First, delete existing records for this dog
            try await deleteMedicationRecords(for: dogID)
            
            // Then save new records
            for record in records {
                let ckRecord = CKRecord(recordType: RecordTypes.medicationRecord)
                ckRecord[RecordFields.id] = record.id.uuidString
                ckRecord[RecordFields.timestamp] = record.timestamp
                ckRecord[RecordFields.notes] = record.notes
                ckRecord[RecordFields.recordedBy] = record.recordedBy
                ckRecord[RecordFields.dogID] = dogID
                ckRecord[RecordFields.createdAt] = Date()
                ckRecord[RecordFields.updatedAt] = Date()
                
                try await publicDatabase.save(ckRecord)
            }
            print("✅ Saved \(records.count) medication records for dog: \(dogID)")
        } catch let error as CKError {
            if error.code == .unknownItem {
                print("⚠️ MedicationRecord type doesn't exist yet for dog \(dogID) - records will be saved when schema is created")
            } else {
                throw error
            }
        }
    }
    
    private func savePottyRecords(_ records: [PottyRecord], for dogID: String) async throws {
        do {
            // First, delete existing records for this dog
            try await deletePottyRecords(for: dogID)
            
            // Then save new records
            for record in records {
                let ckRecord = CKRecord(recordType: RecordTypes.pottyRecord)
                ckRecord[RecordFields.id] = record.id.uuidString
                ckRecord[RecordFields.timestamp] = record.timestamp
                ckRecord[RecordFields.type] = record.type.rawValue
                ckRecord[RecordFields.notes] = record.notes
                ckRecord[RecordFields.recordedBy] = record.recordedBy
                ckRecord[RecordFields.dogID] = dogID
                ckRecord[RecordFields.createdAt] = Date()
                ckRecord[RecordFields.updatedAt] = Date()
                
                try await publicDatabase.save(ckRecord)
            }
            print("✅ Saved \(records.count) potty records for dog: \(dogID)")
        } catch let error as CKError {
            if error.code == .unknownItem {
                print("⚠️ PottyRecord type doesn't exist yet for dog \(dogID) - records will be saved when schema is created")
            } else {
                throw error
            }
        }
    }
    
    private func saveWalkingRecords(_ records: [WalkingRecord], for dogID: String) async throws {
        do {
            // First, delete existing records for this dog
            try await deleteWalkingRecords(for: dogID)
            
            // Then save new records
            for record in records {
                let ckRecord = CKRecord(recordType: RecordTypes.walkingRecord)
                ckRecord[RecordFields.id] = record.id.uuidString
                ckRecord[RecordFields.timestamp] = record.timestamp
                ckRecord[RecordFields.notes] = record.notes
                ckRecord[RecordFields.recordedBy] = record.recordedBy
                ckRecord[RecordFields.dogID] = dogID
                ckRecord[RecordFields.createdAt] = Date()
                ckRecord[RecordFields.updatedAt] = Date()
                
                try await publicDatabase.save(ckRecord)
            }
            print("✅ Saved \(records.count) walking records for dog: \(dogID)")
        } catch let error as CKError {
            if error.code == .unknownItem {
                print("⚠️ WalkingRecord type doesn't exist yet for dog \(dogID) - records will be saved when schema is created")
            } else {
                throw error
            }
        }
    }
    
    private func deleteFeedingRecords(for dogID: String) async throws {
        let predicate = NSPredicate(format: "\(RecordFields.dogID) == %@", dogID)
        let query = CKQuery(recordType: RecordTypes.feedingRecord, predicate: predicate)
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        for record in records {
            try await publicDatabase.deleteRecord(withID: record.recordID)
        }
    }
    
    private func deleteMedicationRecords(for dogID: String) async throws {
        let predicate = NSPredicate(format: "\(RecordFields.dogID) == %@", dogID)
        let query = CKQuery(recordType: RecordTypes.medicationRecord, predicate: predicate)
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        for record in records {
            try await publicDatabase.deleteRecord(withID: record.recordID)
        }
    }
    
    private func deletePottyRecords(for dogID: String) async throws {
        let predicate = NSPredicate(format: "\(RecordFields.dogID) == %@", dogID)
        let query = CKQuery(recordType: RecordTypes.pottyRecord, predicate: predicate)
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        for record in records {
            try await publicDatabase.deleteRecord(withID: record.recordID)
        }
    }
    
    private func deleteWalkingRecords(for dogID: String) async throws {
        let predicate = NSPredicate(format: "\(RecordFields.dogID) == %@", dogID)
        let query = CKQuery(recordType: RecordTypes.walkingRecord, predicate: predicate)
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        for record in records {
            try await publicDatabase.deleteRecord(withID: record.recordID)
        }
    }
    
    func loadRecords(for dogID: String) async throws -> (feeding: [FeedingRecord], medication: [MedicationRecord], potty: [PottyRecord], walking: [WalkingRecord]) {
        async let feedingRecords = loadFeedingRecords(for: dogID)
        async let medicationRecords = loadMedicationRecords(for: dogID)
        async let pottyRecords = loadPottyRecords(for: dogID)
        async let walkingRecords = loadWalkingRecords(for: dogID)
        
        do {
            return try await (feedingRecords, medicationRecords, pottyRecords, walkingRecords)
        } catch let error as CKError {
            if error.code == .unknownItem {
                print("⚠️ Some record types don't exist yet for dog \(dogID), returning empty arrays")
                return ([], [], [], [])
            } else {
                throw error
            }
        }
    }
    
    private func loadFeedingRecords(for dogID: String) async throws -> [FeedingRecord] {
        do {
            let predicate = NSPredicate(format: "\(RecordFields.dogID) == %@", dogID)
            let query = CKQuery(recordType: RecordTypes.feedingRecord, predicate: predicate)
            
            let result = try await publicDatabase.records(matching: query)
            let records = result.matchResults.compactMap { try? $0.1.get() }
            
            var feedingRecords: [FeedingRecord] = []
            for record in records {
                guard let timestamp = record[RecordFields.timestamp] as? Date,
                      let typeString = record[RecordFields.type] as? String,
                      let type = FeedingRecord.FeedingType(rawValue: typeString),
                      let idString = record[RecordFields.id] as? String,
                      let id = UUID(uuidString: idString) else {
                    continue
                }
                
                var feedingRecord = FeedingRecord(
                    timestamp: timestamp,
                    type: type,
                    notes: record[RecordFields.notes] as? String,
                    recordedBy: record[RecordFields.recordedBy] as? String
                )
                feedingRecord.id = id  // Preserve the original ID from CloudKit
                feedingRecords.append(feedingRecord)
            }
            
            // Sort records by timestamp locally
            feedingRecords.sort { $0.timestamp > $1.timestamp }
            
            return feedingRecords
        } catch let error as CKError {
            if error.code == .unknownItem {
                print("⚠️ FeedingRecord type doesn't exist yet for dog \(dogID)")
                return []
            } else {
                throw error
            }
        }
    }
    
    private func loadMedicationRecords(for dogID: String) async throws -> [MedicationRecord] {
        do {
            let predicate = NSPredicate(format: "\(RecordFields.dogID) == %@", dogID)
            let query = CKQuery(recordType: RecordTypes.medicationRecord, predicate: predicate)
            
            let result = try await publicDatabase.records(matching: query)
            let records = result.matchResults.compactMap { try? $0.1.get() }
            
            var medicationRecords: [MedicationRecord] = []
            for record in records {
                guard let timestamp = record[RecordFields.timestamp] as? Date,
                      let idString = record[RecordFields.id] as? String,
                      let id = UUID(uuidString: idString) else {
                    continue
                }
                
                var medicationRecord = MedicationRecord(
                    timestamp: timestamp,
                    notes: record[RecordFields.notes] as? String,
                    recordedBy: record[RecordFields.recordedBy] as? String
                )
                medicationRecord.id = id  // Preserve the original ID from CloudKit
                medicationRecords.append(medicationRecord)
            }
            
            // Sort records by timestamp locally
            medicationRecords.sort { $0.timestamp > $1.timestamp }
            
            return medicationRecords
        } catch let error as CKError {
            if error.code == .unknownItem {
                print("⚠️ MedicationRecord type doesn't exist yet for dog \(dogID)")
                return []
            } else {
                throw error
            }
        }
    }
    
    private func loadPottyRecords(for dogID: String) async throws -> [PottyRecord] {
        do {
            let predicate = NSPredicate(format: "\(RecordFields.dogID) == %@", dogID)
            let query = CKQuery(recordType: RecordTypes.pottyRecord, predicate: predicate)
            
            let result = try await publicDatabase.records(matching: query)
            let records = result.matchResults.compactMap { try? $0.1.get() }
            
            var pottyRecords: [PottyRecord] = []
            for record in records {
                guard let timestamp = record[RecordFields.timestamp] as? Date,
                      let typeString = record[RecordFields.type] as? String,
                      let type = PottyRecord.PottyType(rawValue: typeString),
                      let idString = record[RecordFields.id] as? String,
                      let id = UUID(uuidString: idString) else {
                    continue
                }
                
                var pottyRecord = PottyRecord(
                    timestamp: timestamp,
                    type: type,
                    notes: record[RecordFields.notes] as? String,
                    recordedBy: record[RecordFields.recordedBy] as? String
                )
                pottyRecord.id = id  // Preserve the original ID from CloudKit
                pottyRecords.append(pottyRecord)
            }
            
            // Sort records by timestamp locally
            pottyRecords.sort { $0.timestamp > $1.timestamp }
            
            return pottyRecords
        } catch let error as CKError {
            if error.code == .unknownItem {
                print("⚠️ PottyRecord type doesn't exist yet for dog \(dogID)")
                return []
            } else {
                throw error
            }
        }
    }
    
    private func loadWalkingRecords(for dogID: String) async throws -> [WalkingRecord] {
        do {
            let predicate = NSPredicate(format: "\(RecordFields.dogID) == %@", dogID)
            let query = CKQuery(recordType: RecordTypes.walkingRecord, predicate: predicate)
            
            let result = try await publicDatabase.records(matching: query)
            let records = result.matchResults.compactMap { try? $0.1.get() }
            
            var walkingRecords: [WalkingRecord] = []
            for record in records {
                guard let timestamp = record[RecordFields.timestamp] as? Date,
                      let idString = record[RecordFields.id] as? String,
                      let id = UUID(uuidString: idString) else {
                    continue
                }
                
                var walkingRecord = WalkingRecord(
                    timestamp: timestamp,
                    notes: record[RecordFields.notes] as? String,
                    recordedBy: record[RecordFields.recordedBy] as? String
                )
                walkingRecord.id = id  // Preserve the original ID from CloudKit
                walkingRecords.append(walkingRecord)
            }
            
            // Sort records by timestamp locally
            walkingRecords.sort { $0.timestamp > $1.timestamp }
            
            return walkingRecords
        } catch let error as CKError {
            if error.code == .unknownItem {
                print("⚠️ WalkingRecord type doesn't exist yet for dog \(dogID)")
                return []
            } else {
                throw error
            }
        }
    }
    
    // MARK: - Audit Trail
    
    func createDogChange(
        dogID: String,
        changeType: DogChangeType,
        fieldName: String,
        oldValue: String?,
        newValue: String?
    ) async throws {
        let record = CKRecord(recordType: RecordTypes.dogChange)
        
        record[DogChangeFields.id] = UUID().uuidString
        record[DogChangeFields.timestamp] = Date()
        record[DogChangeFields.changeType] = changeType.rawValue
        record[DogChangeFields.fieldName] = fieldName
        record[DogChangeFields.oldValue] = oldValue
        record[DogChangeFields.newValue] = newValue
        record[DogChangeFields.dogID] = dogID
        record[DogChangeFields.createdAt] = Date()
        
        guard let currentUser = AuthenticationService.shared.currentUser else {
            throw CloudKitError.userNotAuthenticated
        }
        record[DogChangeFields.modifiedBy] = currentUser.id
        
        try await publicDatabase.save(record)
        print("✅ Audit trail created for dog: \(dogID)")
    }
    
    func fetchDogChanges(for dogID: String) async throws -> [CloudKitDogChange] {
        let predicate = NSPredicate(format: "\(DogChangeFields.dogID) == %@", dogID)
        let query = CKQuery(recordType: RecordTypes.dogChange, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: DogChangeFields.timestamp, ascending: false)]
        
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        return records.map { CloudKitDogChange(from: $0) }
    }
    
    // MARK: - Schema Setup
    
    func setupCloudKitSchema() async {
        print("🔧 Setting up CloudKit schema...")
        
        // Create record types
        let recordTypes = [
            RecordTypes.user,
            RecordTypes.dog,
            RecordTypes.dogChange,
            RecordTypes.feedingRecord,
            RecordTypes.medicationRecord,
            RecordTypes.pottyRecord,
            RecordTypes.walkingRecord
        ]
        
        for recordType in recordTypes {
            do {
                // Try to create a test record to see if the schema exists
                let testRecord = CKRecord(recordType: recordType)
                
                // Add minimal required fields based on record type
                switch recordType {
                case RecordTypes.user:
                    testRecord[UserFields.id] = "test-id-\(UUID().uuidString)"
                    testRecord[UserFields.name] = "Test User"
                    testRecord[UserFields.isActive] = 1
                    testRecord[UserFields.isOwner] = 0
                case RecordTypes.dog:
                    testRecord[DogFields.id] = "test-id-\(UUID().uuidString)"
                    testRecord[DogFields.name] = "Test Dog"
                    testRecord[DogFields.arrivalDate] = Date()
                    testRecord[DogFields.isBoarding] = 0
                    testRecord[DogFields.isDaycareFed] = 0
                    testRecord[DogFields.needsWalking] = 0
                case RecordTypes.dogChange:
                    testRecord[DogChangeFields.id] = "test-id-\(UUID().uuidString)"
                    testRecord[DogChangeFields.timestamp] = Date()
                    testRecord[DogChangeFields.changeType] = "created"
                    testRecord[DogChangeFields.fieldName] = "test"
                    testRecord[DogChangeFields.dogID] = "test-dog-id"
                case RecordTypes.feedingRecord:
                    testRecord[RecordFields.id] = "test-id-\(UUID().uuidString)"
                    testRecord[RecordFields.timestamp] = Date()
                    testRecord[RecordFields.type] = "breakfast"
                    testRecord[RecordFields.dogID] = "test-dog-id"
                case RecordTypes.medicationRecord:
                    testRecord[RecordFields.id] = "test-id-\(UUID().uuidString)"
                    testRecord[RecordFields.timestamp] = Date()
                    testRecord[RecordFields.dogID] = "test-dog-id"
                case RecordTypes.pottyRecord:
                    testRecord[RecordFields.id] = "test-id-\(UUID().uuidString)"
                    testRecord[RecordFields.timestamp] = Date()
                    testRecord[RecordFields.type] = "pee"
                    testRecord[RecordFields.dogID] = "test-dog-id"
                case RecordTypes.walkingRecord:
                    testRecord[RecordFields.id] = "test-id-\(UUID().uuidString)"
                    testRecord[RecordFields.timestamp] = Date()
                    testRecord[RecordFields.dogID] = "test-dog-id"
                default:
                    break
                }
                
                let savedRecord = try await publicDatabase.save(testRecord)
                print("✅ Successfully created test \(recordType) record")
                
                // Clean up - delete the test record
                try await publicDatabase.deleteRecord(withID: savedRecord.recordID)
                print("✅ Successfully deleted test \(recordType) record")
                
            } catch let error as CKError {
                if error.code == .unknownItem {
                    print("⚠️ \(recordType) record type doesn't exist yet - will be created when first used")
                } else {
                    print("❌ Error testing \(recordType): \(error)")
                }
            } catch {
                print("❌ Unexpected error testing \(recordType): \(error)")
            }
        }
        
        print("🔧 CloudKit schema setup completed")
    }
    
    // MARK: - Schema Verification
    
    func testSchemaAccess() async {
        print("🧪 Testing CloudKit schema access...")
        
        // Test User record type
        do {
            let userQuery = CKQuery(recordType: RecordTypes.user, predicate: NSPredicate(format: "\(UserFields.name) != %@", ""))
            _ = try await publicDatabase.records(matching: userQuery)
            print("✅ User record type is accessible")
        } catch {
            print("❌ User record type error: \(error)")
        }
        
        // Test Dog record type
        do {
            let dogQuery = CKQuery(recordType: RecordTypes.dog, predicate: NSPredicate(format: "\(DogFields.name) != %@", ""))
            _ = try await publicDatabase.records(matching: dogQuery)
            print("✅ Dog record type is accessible")
        } catch {
            print("❌ Dog record type error: \(error)")
        }
        
        // Test DogChange record type
        do {
            let changeQuery = CKQuery(recordType: RecordTypes.dogChange, predicate: NSPredicate(format: "\(DogChangeFields.id) != %@", ""))
            _ = try await publicDatabase.records(matching: changeQuery)
            print("✅ DogChange record type is accessible")
        } catch {
            print("❌ DogChange record type error: \(error)")
        }
        
        // Test FeedingRecord record type
        do {
            let feedingQuery = CKQuery(recordType: RecordTypes.feedingRecord, predicate: NSPredicate(format: "\(RecordFields.dogID) != %@", ""))
            _ = try await publicDatabase.records(matching: feedingQuery)
            print("✅ FeedingRecord record type is accessible")
        } catch {
            print("❌ FeedingRecord record type error: \(error)")
        }
        
        // Test MedicationRecord record type
        do {
            let medicationQuery = CKQuery(recordType: RecordTypes.medicationRecord, predicate: NSPredicate(format: "\(RecordFields.dogID) != %@", ""))
            _ = try await publicDatabase.records(matching: medicationQuery)
            print("✅ MedicationRecord record type is accessible")
        } catch {
            print("❌ MedicationRecord record type error: \(error)")
        }
        
        // Test PottyRecord record type
        do {
            let pottyQuery = CKQuery(recordType: RecordTypes.pottyRecord, predicate: NSPredicate(format: "\(RecordFields.dogID) != %@", ""))
            _ = try await publicDatabase.records(matching: pottyQuery)
            print("✅ PottyRecord record type is accessible")
        } catch {
            print("❌ PottyRecord record type error: \(error)")
        }
        
        // Test WalkingRecord record type
        do {
            let walkingQuery = CKQuery(recordType: RecordTypes.walkingRecord, predicate: NSPredicate(format: "\(RecordFields.dogID) != %@", ""))
            _ = try await publicDatabase.records(matching: walkingQuery)
            print("✅ WalkingRecord record type is accessible")
        } catch {
            print("❌ WalkingRecord record type error: \(error)")
        }
        
        // Test creating a simple record
        do {
            let testRecord = CKRecord(recordType: RecordTypes.user)
            testRecord[UserFields.name] = "Test User"
            testRecord[UserFields.id] = "test-id-\(UUID().uuidString)"
            testRecord[UserFields.isActive] = 1
            testRecord[UserFields.isOwner] = 0
            
            let savedRecord = try await publicDatabase.save(testRecord)
            print("✅ Successfully created test user record")
            
            // Clean up - delete the test record
            try await publicDatabase.deleteRecord(withID: savedRecord.recordID)
            print("✅ Successfully deleted test user record")
        } catch {
            print("❌ Test record creation error: \(error)")
        }
    }
    
    // MARK: - Individual Record Management
    
    func addFeedingRecord(_ record: FeedingRecord, for dogID: String) async throws {
        let ckRecord = CKRecord(recordType: RecordTypes.feedingRecord)
        
        ckRecord[RecordFields.id] = record.id.uuidString
        ckRecord[RecordFields.timestamp] = record.timestamp
        ckRecord[RecordFields.type] = record.type.rawValue
        ckRecord[RecordFields.notes] = record.notes
        ckRecord[RecordFields.recordedBy] = record.recordedBy
        ckRecord[RecordFields.dogID] = dogID
        ckRecord[RecordFields.createdAt] = Date()
        ckRecord[RecordFields.updatedAt] = Date()
        
        let savedRecord = try await publicDatabase.save(ckRecord)
        print("✅ Feeding record saved to CloudKit: \(savedRecord.recordID.recordName)")
    }
    
    func updateFeedingRecordNotes(_ record: FeedingRecord, newNotes: String?, for dogID: String) async throws {
        print("🔄 CloudKit: Updating feeding record notes for record ID: \(record.id)")
        
        let predicate = NSPredicate(format: "\(RecordFields.id) == %@ AND \(RecordFields.dogID) == %@", record.id.uuidString, dogID)
        let query = CKQuery(recordType: RecordTypes.feedingRecord, predicate: predicate)
        
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let recordToUpdate = records.first else {
            print("❌ CloudKit: No feeding record found to update")
            throw CloudKitError.recordNotFound
        }
        
        // Update the notes field
        recordToUpdate[RecordFields.notes] = newNotes
        recordToUpdate[RecordFields.updatedAt] = Date()
        
        let savedRecord = try await publicDatabase.save(recordToUpdate)
        print("✅ Feeding record notes updated in CloudKit: \(savedRecord.recordID.recordName)")
    }
    
    func addMedicationRecord(_ record: MedicationRecord, for dogID: String) async throws {
        let ckRecord = CKRecord(recordType: RecordTypes.medicationRecord)
        
        ckRecord[RecordFields.id] = record.id.uuidString
        ckRecord[RecordFields.timestamp] = record.timestamp
        ckRecord[RecordFields.notes] = record.notes
        ckRecord[RecordFields.recordedBy] = record.recordedBy
        ckRecord[RecordFields.dogID] = dogID
        ckRecord[RecordFields.createdAt] = Date()
        ckRecord[RecordFields.updatedAt] = Date()
        
        let savedRecord = try await publicDatabase.save(ckRecord)
        print("✅ Medication record saved to CloudKit: \(savedRecord.recordID.recordName)")
    }
    
    func addPottyRecord(_ record: PottyRecord, for dogID: String) async throws {
        let ckRecord = CKRecord(recordType: RecordTypes.pottyRecord)
        
        ckRecord[RecordFields.id] = record.id.uuidString
        ckRecord[RecordFields.timestamp] = record.timestamp
        ckRecord[RecordFields.type] = record.type.rawValue
        ckRecord[RecordFields.notes] = record.notes
        ckRecord[RecordFields.recordedBy] = record.recordedBy
        ckRecord[RecordFields.dogID] = dogID
        ckRecord[RecordFields.createdAt] = Date()
        ckRecord[RecordFields.updatedAt] = Date()
        
        let savedRecord = try await publicDatabase.save(ckRecord)
        print("✅ Potty record saved to CloudKit: \(savedRecord.recordID.recordName)")
    }
    
    func updatePottyRecordNotes(_ record: PottyRecord, newNotes: String?, for dogID: String) async throws {
        print("🔄 CloudKit: Updating potty record notes for record ID: \(record.id)")
        
        let predicate = NSPredicate(format: "\(RecordFields.id) == %@ AND \(RecordFields.dogID) == %@", record.id.uuidString, dogID)
        let query = CKQuery(recordType: RecordTypes.pottyRecord, predicate: predicate)
        
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let recordToUpdate = records.first else {
            print("❌ CloudKit: No potty record found to update")
            throw CloudKitError.recordNotFound
        }
        
        // Update the notes field
        recordToUpdate[RecordFields.notes] = newNotes
        recordToUpdate[RecordFields.updatedAt] = Date()
        
        let savedRecord = try await publicDatabase.save(recordToUpdate)
        print("✅ Potty record notes updated in CloudKit: \(savedRecord.recordID.recordName)")
    }
    
    func addWalkingRecord(_ record: WalkingRecord, for dogID: String) async throws {
        let ckRecord = CKRecord(recordType: RecordTypes.walkingRecord)
        
        ckRecord[RecordFields.id] = record.id.uuidString
        ckRecord[RecordFields.timestamp] = record.timestamp
        ckRecord[RecordFields.notes] = record.notes
        ckRecord[RecordFields.recordedBy] = record.recordedBy
        ckRecord[RecordFields.dogID] = dogID
        ckRecord[RecordFields.createdAt] = Date()
        ckRecord[RecordFields.updatedAt] = Date()
        
        let savedRecord = try await publicDatabase.save(ckRecord)
        print("✅ Walking record saved to CloudKit: \(savedRecord.recordID.recordName)")
    }
    
    func deleteFeedingRecord(_ record: FeedingRecord, for dogID: String) async throws {
        print("🔍 CloudKit: Searching for feeding record with ID: \(record.id) for dog: \(dogID)")
        
        let predicate = NSPredicate(format: "\(RecordFields.id) == %@ AND \(RecordFields.dogID) == %@", record.id.uuidString, dogID)
        let query = CKQuery(recordType: RecordTypes.feedingRecord, predicate: predicate)
        
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        print("🔍 CloudKit: Found \(records.count) matching feeding records")
        
        guard let recordToDelete = records.first else {
            print("❌ CloudKit: No feeding record found to delete")
            throw CloudKitError.recordNotFound
        }
        
        print("🗑️ CloudKit: Deleting feeding record with CloudKit ID: \(recordToDelete.recordID)")
        try await publicDatabase.deleteRecord(withID: recordToDelete.recordID)
        print("✅ Feeding record deleted from CloudKit: \(record.id)")
    }
    
    func deleteMedicationRecord(_ record: MedicationRecord, for dogID: String) async throws {
        let predicate = NSPredicate(format: "\(RecordFields.id) == %@ AND \(RecordFields.dogID) == %@", record.id.uuidString, dogID)
        let query = CKQuery(recordType: RecordTypes.medicationRecord, predicate: predicate)
        
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let recordToDelete = records.first else {
            throw CloudKitError.recordNotFound
        }
        
        try await publicDatabase.deleteRecord(withID: recordToDelete.recordID)
        print("✅ Medication record deleted from CloudKit: \(record.id)")
    }
    
    func deletePottyRecord(_ record: PottyRecord, for dogID: String) async throws {
        let predicate = NSPredicate(format: "\(RecordFields.id) == %@ AND \(RecordFields.dogID) == %@", record.id.uuidString, dogID)
        let query = CKQuery(recordType: RecordTypes.pottyRecord, predicate: predicate)
        
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let recordToDelete = records.first else {
            throw CloudKitError.recordNotFound
        }
        
        try await publicDatabase.deleteRecord(withID: recordToDelete.recordID)
        print("✅ Potty record deleted from CloudKit: \(record.id)")
    }
    
    func deleteWalkingRecord(_ record: WalkingRecord, for dogID: String) async throws {
        let predicate = NSPredicate(format: "\(RecordFields.id) == %@ AND \(RecordFields.dogID) == %@", record.id.uuidString, dogID)
        let query = CKQuery(recordType: RecordTypes.walkingRecord, predicate: predicate)
        
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let recordToDelete = records.first else {
            throw CloudKitError.recordNotFound
        }
        
        try await publicDatabase.deleteRecord(withID: recordToDelete.recordID)
        print("✅ Walking record deleted from CloudKit: \(record.id)")
    }
    
    // MARK: - Targeted Dog Operations
    
    func checkoutDog(_ dogID: String) async throws {
        print("🔄 CloudKitService.checkoutDog called for dog ID: \(dogID)")
        
        // Debug: Check user identity
        await debugUserIdentity()
        
        // Fetch the existing dog record
        let predicate = NSPredicate(format: "\(DogFields.id) == %@", dogID)
        let query = CKQuery(recordType: RecordTypes.dog, predicate: predicate)
        
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let dogRecord = records.first else {
            throw CloudKitError.recordNotFound
        }
        
        let departureDate = dogRecord[DogFields.departureDate] as? Date
        print("📅 Original record departure date: \(departureDate?.description ?? "nil")")
        
        // Debug: Check who created this dog
        let createdBy = dogRecord[DogFields.createdBy] as? String
        print("🔍 Dog was created by CloudKit user ID: \(createdBy ?? "nil")")
        
        // Check if current user is the original owner
        guard let currentUser = AuthenticationService.shared.currentUser else {
            print("❌ No authenticated user found in AuthenticationService")
            throw CloudKitError.userNotAuthenticated
        }
        
        // Get the actual CloudKit user record ID
        let cloudKitUserRecordID = try await container.userRecordID()
        print("🔗 Current CloudKit user record ID: \(cloudKitUserRecordID.recordName)")
        print("🔗 App user ID: \(currentUser.id)")
        
        // Update only the departure date
        dogRecord[DogFields.departureDate] = Date()
        dogRecord[DogFields.updatedAt] = Date()
        
        // Update audit fields - use CloudKit's actual user ID
        dogRecord[DogFields.modifiedBy] = cloudKitUserRecordID.recordName
        let currentCount = dogRecord[DogFields.modificationCount] as? Int64 ?? 0
        dogRecord[DogFields.modificationCount] = currentCount + 1
        
        let updatedDepartureDate = dogRecord[DogFields.departureDate] as? Date
        print("📅 Updated record departure date: \(updatedDepartureDate?.description ?? "nil")")
        
        // Save the updated record
        do {
            let savedRecord = try await publicDatabase.save(dogRecord)
            print("✅ Checkout record saved successfully: \(savedRecord.recordID.recordName)")
        } catch let error as CKError {
            print("❌ CloudKit save error: \(error)")
            print("❌ Error code: \(error.code.rawValue)")
            print("❌ Error description: \(error.localizedDescription)")
            
            if error.code == .notAuthenticated {
                throw CloudKitError.userNotAuthenticated
            } else if error.code == .permissionFailure {
                print("❌ PERMISSION ERROR: User cannot modify this record")
                print("❌ This is likely a CloudKit container security setting issue")
                print("❌ Check CloudKit Dashboard → Schema → Security Roles")
                print("❌ OR check Apple Developer Portal → CloudKit → Container Settings")
                throw CloudKitError.permissionDenied
            } else {
                throw CloudKitError.unknownError(error.localizedDescription)
            }
        }
        
        // Create audit trail entry
        try await createDogChange(
            dogID: dogID,
            changeType: .departed,
            fieldName: DogFields.departureDate,
            oldValue: nil,
            newValue: Date().description
        )
    }
    
    func extendBoardingOptimized(_ dogID: String, newEndDate: Date) async throws {
        print("🔄 CloudKitService.extendBoardingOptimized called for dog ID: \(dogID)")
        
        // Fetch the existing dog record
        let predicate = NSPredicate(format: "\(DogFields.id) == %@", dogID)
        let query = CKQuery(recordType: RecordTypes.dog, predicate: predicate)
        
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let dogRecord = records.first else {
            throw CloudKitError.recordNotFound
        }
        
        let oldEndDate = dogRecord[DogFields.boardingEndDate] as? Date
        print("📅 Original boarding end date: \(oldEndDate?.description ?? "nil")")
        
        // Update only the boarding end date
        dogRecord[DogFields.boardingEndDate] = newEndDate
        dogRecord[DogFields.updatedAt] = Date()
        
        // Update audit fields if user is authenticated
        guard let currentUser = AuthenticationService.shared.currentUser else {
            print("❌ No authenticated user found in AuthenticationService")
            throw CloudKitError.userNotAuthenticated
        }
        
        dogRecord[DogFields.modifiedBy] = currentUser.id
        let currentCount = dogRecord[DogFields.modificationCount] as? Int64 ?? 0
        dogRecord[DogFields.modificationCount] = currentCount + 1
        
        let updatedEndDate = dogRecord[DogFields.boardingEndDate] as? Date
        print("📅 Updated boarding end date: \(updatedEndDate?.description ?? "nil")")
        
        // Save the updated record
        let savedRecord = try await publicDatabase.save(dogRecord)
        print("✅ Extend boarding record saved successfully: \(savedRecord.recordID.recordName)")
        
        // Create audit trail entry
        try await createDogChange(
            dogID: dogID,
            changeType: .updated,
            fieldName: DogFields.boardingEndDate,
            oldValue: oldEndDate?.description,
            newValue: newEndDate.description
        )
    }
    
    func boardDogOptimized(_ dogID: String, endDate: Date) async throws {
        print("🔄 CloudKitService.boardDogOptimized called for dog ID: \(dogID)")
        
        // Fetch the existing dog record
        let predicate = NSPredicate(format: "\(DogFields.id) == %@", dogID)
        let query = CKQuery(recordType: RecordTypes.dog, predicate: predicate)
        
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let dogRecord = records.first else {
            throw CloudKitError.recordNotFound
        }
        
        let wasBoarding = dogRecord[DogFields.isBoarding] as? Int64 == 1
        let oldEndDate = dogRecord[DogFields.boardingEndDate] as? Date
        print("📅 Original boarding status: \(wasBoarding), end date: \(oldEndDate?.description ?? "nil")")
        
        // Update only the boarding fields
        dogRecord[DogFields.isBoarding] = 1
        dogRecord[DogFields.boardingEndDate] = endDate
        dogRecord[DogFields.updatedAt] = Date()
        
        // Update audit fields if user is authenticated
        guard let currentUser = AuthenticationService.shared.currentUser else {
            print("❌ No authenticated user found in AuthenticationService")
            throw CloudKitError.userNotAuthenticated
        }
        
        dogRecord[DogFields.modifiedBy] = currentUser.id
        let currentCount = dogRecord[DogFields.modificationCount] as? Int64 ?? 0
        dogRecord[DogFields.modificationCount] = currentCount + 1
        
        let updatedEndDate = dogRecord[DogFields.boardingEndDate] as? Date
        print("📅 Updated boarding status: true, end date: \(updatedEndDate?.description ?? "nil")")
        
        // Save the updated record
        let savedRecord = try await publicDatabase.save(dogRecord)
        print("✅ Board conversion record saved successfully: \(savedRecord.recordID.recordName)")
        
        // Create audit trail entry
        try await createDogChange(
            dogID: dogID,
            changeType: .updated,
            fieldName: DogFields.isBoarding,
            oldValue: wasBoarding ? "true" : "false",
            newValue: "true"
        )
    }

    func undoDepartureOptimized(_ dogID: String) async throws {
        print("🔄 CloudKitService.undoDepartureOptimized called for dog ID: \(dogID)")
        // Fetch the existing dog record
        let predicate = NSPredicate(format: "\(DogFields.id) == %@", dogID)
        let query = CKQuery(recordType: RecordTypes.dog, predicate: predicate)
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        guard let dogRecord = records.first else {
            throw CloudKitError.recordNotFound
        }
        let oldDepartureDate = dogRecord[DogFields.departureDate] as? Date
        print("📅 Original record departure date: \(oldDepartureDate?.description ?? "nil")")
        // Set departureDate to nil
        dogRecord[DogFields.departureDate] = nil
        dogRecord[DogFields.updatedAt] = Date()
        
        // Update audit fields if user is authenticated
        guard let currentUser = AuthenticationService.shared.currentUser else {
            print("❌ No authenticated user found in AuthenticationService")
            throw CloudKitError.userNotAuthenticated
        }
        
        dogRecord[DogFields.modifiedBy] = currentUser.id
        let currentCount = dogRecord[DogFields.modificationCount] as? Int64 ?? 0
        dogRecord[DogFields.modificationCount] = currentCount + 1
        
        print("📅 Departure date undone (set to nil)")
        let savedRecord = try await publicDatabase.save(dogRecord)
        print("✅ Undo departure saved: \(savedRecord.recordID.recordName)")
        try await createDogChange(
            dogID: dogID,
            changeType: .updated,
            fieldName: DogFields.departureDate,
            oldValue: oldDepartureDate?.description,
            newValue: "nil"
        )
    }

    func editDepartureOptimized(_ dogID: String, newDate: Date) async throws {
        print("🔄 CloudKitService.editDepartureOptimized called for dog ID: \(dogID), newDate: \(newDate)")
        // Fetch the existing dog record
        let predicate = NSPredicate(format: "\(DogFields.id) == %@", dogID)
        let query = CKQuery(recordType: RecordTypes.dog, predicate: predicate)
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        guard let dogRecord = records.first else {
            throw CloudKitError.recordNotFound
        }
        let oldDepartureDate = dogRecord[DogFields.departureDate] as? Date
        print("📅 Original record departure date: \(oldDepartureDate?.description ?? "nil")")
        // Set departureDate to newDate
        dogRecord[DogFields.departureDate] = newDate
        dogRecord[DogFields.updatedAt] = Date()
        
        // Update audit fields if user is authenticated
        guard let currentUser = AuthenticationService.shared.currentUser else {
            print("❌ No authenticated user found in AuthenticationService")
            throw CloudKitError.userNotAuthenticated
        }
        
        dogRecord[DogFields.modifiedBy] = currentUser.id
        let currentCount = dogRecord[DogFields.modificationCount] as? Int64 ?? 0
        dogRecord[DogFields.modificationCount] = currentCount + 1
        
        print("📅 Updated record departure date: \(newDate)")
        let savedRecord = try await publicDatabase.save(dogRecord)
        print("✅ Edit departure saved: \(savedRecord.recordID.recordName)")
        try await createDogChange(
            dogID: dogID,
            changeType: .updated,
            fieldName: DogFields.departureDate,
            oldValue: oldDepartureDate?.description,
            newValue: newDate.description
        )
    }

    func setArrivalTimeOptimized(_ dogID: String, newArrivalTime: Date) async throws {
        print("🔄 CloudKitService.setArrivalTimeOptimized called for dog ID: \(dogID), newArrivalTime: \(newArrivalTime)")
        
        // Fetch the existing dog record
        let predicate = NSPredicate(format: "\(DogFields.id) == %@", dogID)
        let query = CKQuery(recordType: RecordTypes.dog, predicate: predicate)
        
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let dogRecord = records.first else {
            throw CloudKitError.recordNotFound
        }
        
        let oldArrivalDate = dogRecord[DogFields.arrivalDate] as? Date
        print("📅 Original record arrival date: \(oldArrivalDate?.description ?? "nil")")
        
        // Update only the arrival date and arrival time set flag
        dogRecord[DogFields.arrivalDate] = newArrivalTime
        dogRecord[DogFields.isArrivalTimeSet] = 1
        dogRecord[DogFields.updatedAt] = Date()
        
        // Update audit fields if user is authenticated
        guard let currentUser = AuthenticationService.shared.currentUser else {
            print("❌ No authenticated user found in AuthenticationService")
            throw CloudKitError.userNotAuthenticated
        }
        
        dogRecord[DogFields.modifiedBy] = currentUser.id
        let currentCount = dogRecord[DogFields.modificationCount] as? Int64 ?? 0
        dogRecord[DogFields.modificationCount] = currentCount + 1
        
        print("📅 Updated record arrival date: \(newArrivalTime)")
        
        // Save the updated record
        let savedRecord = try await publicDatabase.save(dogRecord)
        print("✅ Set arrival time saved successfully: \(savedRecord.recordID.recordName)")
        
        // Create audit trail entry
        try await createDogChange(
            dogID: dogID,
            changeType: .updated,
            fieldName: DogFields.arrivalDate,
            oldValue: oldArrivalDate?.description,
            newValue: newArrivalTime.description
        )
    }
    
    // MARK: - Debug Functions
    
    func debugTestPermissions() async {
        print("🔍 Testing CloudKit permissions...")
        
        // Test 1: Try to create a new dog record
        do {
            let testDog = CloudKitDog(
                name: "TEST_DOG_PERMISSIONS",
                arrivalDate: Date(),
                isBoarding: false
            )
            
            let record = CKRecord(recordType: RecordTypes.dog)
            record[DogFields.id] = testDog.id
            record[DogFields.name] = testDog.name
            record[DogFields.arrivalDate] = testDog.arrivalDate
            record[DogFields.isBoarding] = testDog.isBoarding ? 1 : 0
            record[DogFields.createdAt] = Date()
            record[DogFields.updatedAt] = Date()
            
            let savedRecord = try await publicDatabase.save(record)
            print("✅ SUCCESS: Can create new dog records")
            
            // Try to modify the record we just created
            savedRecord[DogFields.name] = "TEST_DOG_MODIFIED"
            _ = try await publicDatabase.save(savedRecord)
            print("✅ SUCCESS: Can modify records we created")
            
            // Test 3: Try to create a share for this record
            do {
                let share = CKShare(rootRecord: savedRecord)
                share[CKShare.SystemFieldKey.title] = "Test Dog Share"
                share.publicPermission = .readWrite
                
                let saveResult = try await publicDatabase.save(share)
                print("✅ SUCCESS: Can create CKShare for records")
                print("✅ Share ID: \(saveResult.recordID.recordName)")
                
                // Try to modify the shared record
                savedRecord[DogFields.name] = "TEST_DOG_SHARED_MODIFIED"
                _ = try await publicDatabase.save(savedRecord)
                print("✅ SUCCESS: Can modify shared records")
                
                // Clean up
                try await publicDatabase.deleteRecord(withID: saveResult.recordID)
                try await publicDatabase.deleteRecord(withID: savedRecord.recordID)
                print("✅ SUCCESS: Can delete shared records")
                
            } catch {
                print("❌ CKShare test failed: \(error)")
            }
            
        } catch {
            print("❌ FAILED: \(error)")
        }
    }
    
    func debugUserIdentity() async {
        print("🔍 Debugging CloudKit user identity...")
        
        do {
            // Check current CloudKit user
            let userRecordID = try await container.userRecordID()
            print("📱 Current CloudKit User Record ID: \(userRecordID.recordName)")
            
            // Check container identifier
            print("📦 CloudKit Container ID: \(container.containerIdentifier ?? "Unknown")")
            
            // Check if we can access private database
            let privateDatabase = container.privateCloudDatabase
            print("🔒 Private database available: \(privateDatabase)")
            
            // Check if we can fetch our own user record
            let userRecord = try await publicDatabase.record(for: userRecordID)
            print("✅ Can fetch own user record")
            print("📱 User record type: \(userRecord.recordType)")
            
            // Check if we can fetch our own user from our app's user table
            let predicate = NSPredicate(format: "\(UserFields.id) == %@", userRecordID.recordName)
            let query = CKQuery(recordType: RecordTypes.user, predicate: predicate)
            let result = try await publicDatabase.records(matching: query)
            let records = result.matchResults.compactMap { try? $0.1.get() }
            
            if let userRecord = records.first {
                print("✅ Found matching user record in app: \(userRecord[UserFields.name] as? String ?? "Unknown")")
                print("📱 User is owner: \(userRecord[UserFields.isOwner] as? Int64 == 1)")
                print("📱 User is original owner: \(userRecord[UserFields.isOriginalOwner] as? Int64 == 1)")
            } else {
                print("❌ No matching user record found in app's user table")
                print("🔍 This suggests the CloudKit user ID doesn't match any app user")
            }
            
            // Check all users in the app
            let allUsers = try await fetchAllUsers()
            print("👥 All users in app:")
            for user in allUsers {
                print("   - \(user.name) (ID: \(user.id), Owner: \(user.isOwner), Original: \(user.isOriginalOwner))")
            }
            
        } catch {
            print("❌ User identity debug failed: \(error)")
        }
    }
    
    // MARK: - User Identity Management
    
    /// Updates the current user's CloudKit user ID in our app's user table
    func updateCurrentUserCloudKitID() async throws {
        print("🔄 Updating current user's CloudKit ID...")
        
        // Get current CloudKit user ID
        let cloudKitUserID = try await container.userRecordID()
        print("📱 Current CloudKit User ID: \(cloudKitUserID.recordName)")
        
        // Get current app user
        guard let currentUser = AuthenticationService.shared.currentUser else {
            throw CloudKitError.userNotAuthenticated
        }
        
        print("👤 Current app user: \(currentUser.name) (ID: \(currentUser.id))")
        
        // Find the user record in CloudKit
        let predicate = NSPredicate(format: "\(UserFields.id) == %@", currentUser.id)
        let query = CKQuery(recordType: RecordTypes.user, predicate: predicate)
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let userRecord = records.first else {
            print("❌ User record not found in CloudKit")
            throw CloudKitError.recordNotFound
        }
        
        // Update the CloudKit user ID field
        userRecord[UserFields.cloudKitUserID] = cloudKitUserID.recordName
        userRecord[UserFields.updatedAt] = Date()
        
        // Save the updated record
        let savedRecord = try await publicDatabase.save(userRecord)
        print("✅ Updated user's CloudKit ID: \(savedRecord[UserFields.cloudKitUserID] as? String ?? "nil")")
    }

    /// Debug function to check current user's CloudKit ID mapping
    func debugCurrentUserCloudKitID() async {
        print("🔍 Debugging current user's CloudKit ID mapping...")
        
        // Get current CloudKit user ID
        do {
            let cloudKitUserID = try await container.userRecordID()
            print("📱 Current CloudKit User ID: \(cloudKitUserID.recordName)")
        } catch {
            print("❌ Failed to get CloudKit user ID: \(error)")
        }
        
        // Get current app user
        guard let currentUser = AuthenticationService.shared.currentUser else {
            print("❌ No authenticated user found")
            return
        }
        
        print("👤 Current app user: \(currentUser.name) (ID: \(currentUser.id))")
        
        // Check if user has CloudKit ID stored
        if let storedCloudKitID = currentUser.cloudKitUserID {
            print("🔗 Stored CloudKit ID: \(storedCloudKitID)")
        } else {
            print("❌ No CloudKit ID stored for current user")
        }
        
        // Fetch all users to see the mapping
        do {
            let allUsers = try await fetchAllUsers()
            print("📋 All users and their CloudKit IDs:")
            for user in allUsers {
                print("   - \(user.name) (App ID: \(user.id), CloudKit ID: \(user.cloudKitUserID ?? "nil"))")
            }
        } catch {
            print("❌ Failed to fetch users: \(error)")
        }
    }

    func permanentlyDeleteDog(_ dog: CloudKitDog) async throws {
        let predicate = NSPredicate(format: "\(DogFields.id) == %@", dog.id)
        let query = CKQuery(recordType: RecordTypes.dog, predicate: predicate)
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let record = records.first else {
            throw CloudKitError.recordNotFound
        }
        
        // Delete all associated records first
        try await deleteFeedingRecords(for: dog.id)
        try await deleteMedicationRecords(for: dog.id)
        try await deletePottyRecords(for: dog.id)
        try await deleteWalkingRecords(for: dog.id)
        
        // Delete the dog record permanently
        try await publicDatabase.deleteRecord(withID: record.recordID)
        
        // Create audit trail entry
        try await createDogChange(
            dogID: dog.id,
            changeType: .deleted,
            fieldName: "dog",
            oldValue: dog.name,
            newValue: nil
        )
        
        print("✅ Dog permanently deleted from database: \(dog.name)")
    }

    func fetchAllDogsIncludingDeleted() async throws -> [CloudKitDog] {
        print("🔍 Starting fetchAllDogsIncludingDeleted...")
        // Fetch all dogs including deleted ones
        let predicate = NSPredicate(format: "\(DogFields.name) != %@", "")
        let query = CKQuery(recordType: RecordTypes.dog, predicate: predicate)
        
        print("🔍 Executing CloudKit query: \(query)")
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        print("🔍 Found \(records.count) total dog records in CloudKit")
        
        var dogs: [CloudKitDog] = []
        
        for record in records {
            print("🔍 Processing dog record: \(record[DogFields.name] as? String ?? "Unknown")")
            var dog = CloudKitDog(from: record)
            
            // Load records for this dog
            do {
                let (feeding, medication, potty, walking) = try await loadRecords(for: dog.id)
                dog.feedingRecords = feeding
                dog.medicationRecords = medication
                dog.pottyRecords = potty
                dog.walkingRecords = walking
                print("✅ Loaded \(feeding.count) feeding, \(medication.count) medication, \(potty.count) potty, \(walking.count) walking records for \(dog.name)")
            } catch {
                print("⚠️ Failed to load records for dog \(dog.name): \(error)")
            }
            
            dogs.append(dog)
        }
        
        // Sort dogs by creation date locally
        dogs.sort { $0.createdAt > $1.createdAt }
        
        print("✅ Fetched \(dogs.count) total dogs from CloudKit")
        return dogs
    }
}

// MARK: - Error Types

enum CloudKitError: LocalizedError {
    case userNotAuthenticated
    case recordNotFound
    case networkError
    case permissionDenied
    case quotaExceeded
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .recordNotFound:
            return "Record not found"
        case .networkError:
            return "Network error occurred"
        case .permissionDenied:
            return "Permission denied"
        case .quotaExceeded:
            return "CloudKit quota exceeded"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - Data Models

struct CloudKitUser {
    let id: String
    var name: String
    var email: String?
    var isActive: Bool
    var isOwner: Bool
    var isWorkingToday: Bool
    var isOriginalOwner: Bool
    var createdAt: Date
    var updatedAt: Date
    var lastLogin: Date?
    var scheduledDays: [Int64]?
    var scheduleStartTime: Date?
    var scheduleEndTime: Date?
    var canAddDogs: Bool
    var canAddFutureBookings: Bool
    var canManageStaff: Bool
    var canManageMedications: Bool
    var canManageFeeding: Bool
    var canManageWalking: Bool
    var hashedPassword: String?
    var cloudKitUserID: String?
    
    var canWorkToday: Bool {
        // Owners can always work
        if isOwner {
            return true
        }
        
        // Check if user is scheduled to work today
        guard let scheduledDays = scheduledDays else {
            return false
        }
        
        let today = Calendar.current.component(.weekday, from: Date())
        let todayInt64 = Int64(today)
        
        return scheduledDays.contains(todayInt64)
    }
    
    init(
        id: String,
        name: String,
        email: String? = nil,
        isOwner: Bool = false,
        isActive: Bool = true,
        isWorkingToday: Bool = false,
        isOriginalOwner: Bool = false,
        scheduledDays: [Int64]? = nil,
        scheduleStartTime: Date? = nil,
        scheduleEndTime: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastLogin: Date? = nil,
        canAddDogs: Bool = true,
        canAddFutureBookings: Bool = true,
        canManageStaff: Bool = false,
        canManageMedications: Bool = true,
        canManageFeeding: Bool = true,
        canManageWalking: Bool = true,
        hashedPassword: String? = nil,
        cloudKitUserID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.isOwner = isOwner
        self.isActive = isActive
        self.isWorkingToday = isWorkingToday
        self.isOriginalOwner = isOriginalOwner
        self.scheduledDays = scheduledDays
        self.scheduleStartTime = scheduleStartTime
        self.scheduleEndTime = scheduleEndTime
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastLogin = lastLogin
        self.canAddDogs = canAddDogs
        self.canAddFutureBookings = canAddFutureBookings
        self.canManageStaff = canManageStaff
        self.canManageMedications = canManageMedications
        self.canManageFeeding = canManageFeeding
        self.canManageWalking = canManageWalking
        self.hashedPassword = hashedPassword
        self.cloudKitUserID = cloudKitUserID
    }
    
    init(from record: CKRecord) {
        self.id = record[CloudKitService.UserFields.id] as? String ?? ""
        self.name = record[CloudKitService.UserFields.name] as? String ?? ""
        self.email = record[CloudKitService.UserFields.email] as? String
        self.isActive = (record[CloudKitService.UserFields.isActive] as? Int64 ?? 1) == 1
        self.isOwner = (record[CloudKitService.UserFields.isOwner] as? Int64 ?? 0) == 1
        self.isWorkingToday = (record[CloudKitService.UserFields.isWorkingToday] as? Int64 ?? 0) == 1
        self.isOriginalOwner = (record[CloudKitService.UserFields.isOriginalOwner] as? Int64 ?? 0) == 1
        self.createdAt = record[CloudKitService.UserFields.createdAt] as? Date ?? Date()
        self.updatedAt = record[CloudKitService.UserFields.updatedAt] as? Date ?? Date()
        self.lastLogin = record[CloudKitService.UserFields.lastLogin] as? Date
        self.scheduledDays = record[CloudKitService.UserFields.scheduledDays] as? [Int64]
        self.scheduleStartTime = record[CloudKitService.UserFields.scheduleStartTime] as? Date
        self.scheduleEndTime = record[CloudKitService.UserFields.scheduleEndTime] as? Date
        self.canAddDogs = (record[CloudKitService.UserFields.canAddDogs] as? Int64 ?? 0) == 1
        self.canAddFutureBookings = (record[CloudKitService.UserFields.canAddFutureBookings] as? Int64 ?? 0) == 1
        self.canManageStaff = (record[CloudKitService.UserFields.canManageStaff] as? Int64 ?? 0) == 1
        self.canManageMedications = (record[CloudKitService.UserFields.canManageMedications] as? Int64 ?? 0) == 1
        self.canManageFeeding = (record[CloudKitService.UserFields.canManageFeeding] as? Int64 ?? 0) == 1
        self.canManageWalking = (record[CloudKitService.UserFields.canManageWalking] as? Int64 ?? 0) == 1
        self.hashedPassword = record[CloudKitService.UserFields.hashedPassword] as? String
        self.cloudKitUserID = record[CloudKitService.UserFields.cloudKitUserID] as? String
    }
}

struct CloudKitDog {
    let id: String
    var name: String
    var ownerName: String?
    var arrivalDate: Date
    var departureDate: Date?
    var boardingEndDate: Date?
    var isBoarding: Bool
    var isDaycareFed: Bool
    var needsWalking: Bool
    var walkingNotes: String?
    var medications: String?
    var allergiesAndFeedingInstructions: String?
    var notes: String?
    var profilePictureData: Data?
    var createdAt: Date
    var updatedAt: Date
    var isArrivalTimeSet: Bool
    var isDeleted: Bool
    
    // Records
    var feedingRecords: [FeedingRecord] = []
    var medicationRecords: [MedicationRecord] = []
    var pottyRecords: [PottyRecord] = []
    var walkingRecords: [WalkingRecord] = []
    
    var isCurrentlyPresent: Bool {
        // A dog is currently present if they have arrived (arrivalDate is in the past or today)
        // and haven't departed yet (departureDate is nil)
        let now = Date()
        let calendar = Calendar.current
        
        // Check if arrival date is today or in the past
        let hasArrived = calendar.isDate(arrivalDate, inSameDayAs: now) || arrivalDate < now
        
        // Dog is present if they've arrived and haven't departed
        return hasArrived && departureDate == nil
    }
    
    init(
        id: String = UUID().uuidString,
        name: String,
        ownerName: String? = nil,
        arrivalDate: Date,
        departureDate: Date? = nil,
        boardingEndDate: Date? = nil,
        isBoarding: Bool = false,
        isDaycareFed: Bool = false,
        needsWalking: Bool = false,
        walkingNotes: String? = nil,
        medications: String? = nil,
        allergiesAndFeedingInstructions: String? = nil,
        notes: String? = nil,
        profilePictureData: Data? = nil,
        feedingRecords: [FeedingRecord] = [],
        medicationRecords: [MedicationRecord] = [],
        pottyRecords: [PottyRecord] = [],
        walkingRecords: [WalkingRecord] = [],
        isArrivalTimeSet: Bool = true,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.ownerName = ownerName
        self.arrivalDate = arrivalDate
        self.departureDate = departureDate
        self.boardingEndDate = boardingEndDate
        self.isBoarding = isBoarding
        self.isDaycareFed = isDaycareFed
        self.needsWalking = needsWalking
        self.walkingNotes = walkingNotes
        self.medications = medications
        self.allergiesAndFeedingInstructions = allergiesAndFeedingInstructions
        self.notes = notes
        self.profilePictureData = profilePictureData
        self.feedingRecords = feedingRecords
        self.medicationRecords = medicationRecords
        self.pottyRecords = pottyRecords
        self.walkingRecords = walkingRecords
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isArrivalTimeSet = isArrivalTimeSet
        self.isDeleted = isDeleted
    }
    
    init(from record: CKRecord) {
        self.id = record[CloudKitService.DogFields.id] as? String ?? UUID().uuidString
        self.name = record[CloudKitService.DogFields.name] as? String ?? ""
        self.ownerName = record[CloudKitService.DogFields.ownerName] as? String
        self.arrivalDate = record[CloudKitService.DogFields.arrivalDate] as? Date ?? Date()
        self.departureDate = record[CloudKitService.DogFields.departureDate] as? Date
        self.boardingEndDate = record[CloudKitService.DogFields.boardingEndDate] as? Date
        self.isBoarding = (record[CloudKitService.DogFields.isBoarding] as? Int64 ?? 0) == 1
        self.isDaycareFed = (record[CloudKitService.DogFields.isDaycareFed] as? Int64 ?? 0) == 1
        self.needsWalking = (record[CloudKitService.DogFields.needsWalking] as? Int64 ?? 0) == 1
        self.walkingNotes = record[CloudKitService.DogFields.walkingNotes] as? String
        self.medications = record[CloudKitService.DogFields.medications] as? String
        self.allergiesAndFeedingInstructions = record[CloudKitService.DogFields.allergiesAndFeedingInstructions] as? String
        self.notes = record[CloudKitService.DogFields.notes] as? String
        self.profilePictureData = record[CloudKitService.DogFields.profilePictureData] as? Data
        self.createdAt = record[CloudKitService.DogFields.createdAt] as? Date ?? Date()
        self.updatedAt = record[CloudKitService.DogFields.updatedAt] as? Date ?? Date()
        self.isArrivalTimeSet = (record[CloudKitService.DogFields.isArrivalTimeSet] as? Int64 ?? 1) == 1
        self.isDeleted = (record[CloudKitService.DogFields.isDeleted] as? Int64 ?? 0) == 1
        
        // Initialize empty records arrays - they will be loaded separately
        self.feedingRecords = []
        self.medicationRecords = []
        self.pottyRecords = []
        self.walkingRecords = []
    }
}

struct CloudKitDogChange {
    let id: String
    let timestamp: Date
    let changeType: DogChangeType
    let fieldName: String
    let oldValue: String?
    let newValue: String?
    let dogID: String
    let modifiedBy: String
    let createdAt: Date
    
    init(from record: CKRecord) {
        self.id = record[CloudKitService.DogChangeFields.id] as? String ?? ""
        self.timestamp = record[CloudKitService.DogChangeFields.timestamp] as? Date ?? Date()
        self.changeType = DogChangeType(rawValue: record[CloudKitService.DogChangeFields.changeType] as? String ?? "") ?? .updated
        self.fieldName = record[CloudKitService.DogChangeFields.fieldName] as? String ?? ""
        self.oldValue = record[CloudKitService.DogChangeFields.oldValue] as? String
        self.newValue = record[CloudKitService.DogChangeFields.newValue] as? String
        self.dogID = record[CloudKitService.DogChangeFields.dogID] as? String ?? ""
        self.modifiedBy = record[CloudKitService.DogChangeFields.modifiedBy] as? String ?? ""
        self.createdAt = record[CloudKitService.DogChangeFields.createdAt] as? Date ?? Date()
    }
}

enum DogChangeType: String, CaseIterable {
    case created = "created"
    case updated = "updated"
    case deleted = "deleted"
    case arrived = "arrived"
    case departed = "departed"
    case medicationAdded = "medicationAdded"
    case medicationRemoved = "medicationRemoved"
    case walkingStatusChanged = "walkingStatusChanged"
    case feedingStatusChanged = "feedingStatusChanged"
} 