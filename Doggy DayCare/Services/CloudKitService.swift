import CloudKit
import Foundation
import SwiftUI

@MainActor
class CloudKitService: ObservableObject {
    static let shared = CloudKitService()
    
    private let container = CKContainer.default()
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
    }
    
    // MARK: - Authentication
    
    func authenticate() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let userRecordID = try await container.userRecordID()
            let userRecord = try await privateDatabase.record(for: userRecordID)
            
            // Check if user exists in our system
            if let existingUser = try await fetchUser(by: userRecordID.recordName) {
                currentUser = existingUser
                isAuthenticated = true
                print("✅ User authenticated: \(existingUser.name)")
            } else {
                // Create new user record
                let newUser = CloudKitUser(
                    id: userRecordID.recordName,
                    name: userRecord["name"] as? String ?? "Unknown User",
                    email: userRecord["email"] as? String,
                    isOwner: false,
                    isActive: true,
                    isWorkingToday: false,
                    isOriginalOwner: false
                )
                
                try await createUser(newUser)
                currentUser = newUser
                isAuthenticated = true
                print("✅ New user created and authenticated: \(newUser.name)")
            }
        } catch {
            errorMessage = "Authentication failed: \(error.localizedDescription)"
            print("❌ Authentication error: \(error)")
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - User Management
    
    func createUser(_ user: CloudKitUser) async throws {
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
        
        // Audit fields
        record[UserFields.createdBy] = user.id
        record[UserFields.modifiedBy] = user.id
        record[UserFields.modificationCount] = 1
        
        try await publicDatabase.save(record)
        print("✅ User created: \(user.name)")
    }
    
    func fetchUser(by id: String) async throws -> CloudKitUser? {
        let predicate = NSPredicate(format: "\(UserFields.id) == %@", id)
        let query = CKQuery(recordType: RecordTypes.user, predicate: predicate)
        
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let record = records.first else { return nil }
        
        return CloudKitUser(from: record)
    }
    
    func fetchAllUsers() async throws -> [CloudKitUser] {
        let query = CKQuery(recordType: RecordTypes.user, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: UserFields.name, ascending: true)]
        
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        return records.map { CloudKitUser(from: $0) }
    }
    
    // MARK: - Dog Management
    
    func createDog(_ dog: CloudKitDog) async throws {
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
        
        // Audit fields
        guard let currentUser = currentUser else {
            throw CloudKitError.userNotAuthenticated
        }
        record[DogFields.createdBy] = currentUser.id
        record[DogFields.modifiedBy] = currentUser.id
        record[DogFields.modificationCount] = 1
        
        try await publicDatabase.save(record)
        
        // Create audit trail entry
        try await createDogChange(
            dogID: dog.id,
            changeType: .created,
            fieldName: "dog",
            oldValue: nil,
            newValue: dog.name
        )
        
        print("✅ Dog created: \(dog.name)")
    }
    
    func fetchAllDogs() async throws -> [CloudKitDog] {
        let query = CKQuery(recordType: RecordTypes.dog, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: DogFields.name, ascending: true)]
        
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        return records.map { CloudKitDog(from: $0) }
    }
    
    func updateDog(_ dog: CloudKitDog) async throws {
        // Fetch existing record
        let predicate = NSPredicate(format: "\(DogFields.id) == %@", dog.id)
        let query = CKQuery(recordType: RecordTypes.dog, predicate: predicate)
        
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let record = records.first else {
            throw CloudKitError.recordNotFound
        }
        
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
        
        // Update audit fields
        guard let currentUser = currentUser else {
            throw CloudKitError.userNotAuthenticated
        }
        record[DogFields.modifiedBy] = currentUser.id
        record[DogFields.modificationCount] = (record[DogFields.modificationCount] as? Int ?? 0) + 1
        
        try await publicDatabase.save(record)
        
        // Create audit trail entry
        try await createDogChange(
            dogID: dog.id,
            changeType: .updated,
            fieldName: "dog",
            oldValue: nil,
            newValue: "Updated by \(currentUser.name)"
        )
        
        print("✅ Dog updated: \(dog.name)")
    }
    
    func deleteDog(_ dog: CloudKitDog) async throws {
        let predicate = NSPredicate(format: "\(DogFields.id) == %@", dog.id)
        let query = CKQuery(recordType: RecordTypes.dog, predicate: predicate)
        
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let record = records.first else {
            throw CloudKitError.recordNotFound
        }
        
        try await publicDatabase.deleteRecord(withID: record.recordID)
        
        // Create audit trail entry
        try await createDogChange(
            dogID: dog.id,
            changeType: .deleted,
            fieldName: "dog",
            oldValue: dog.name,
            newValue: nil
        )
        
        print("✅ Dog deleted: \(dog.name)")
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
        
        guard let currentUser = currentUser else {
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
    
    init(
        id: String,
        name: String,
        email: String? = nil,
        isOwner: Bool = false,
        isActive: Bool = true,
        isWorkingToday: Bool = false,
        isOriginalOwner: Bool = false
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.isOwner = isOwner
        self.isActive = isActive
        self.isWorkingToday = isWorkingToday
        self.isOriginalOwner = isOriginalOwner
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastLogin = nil
        self.scheduledDays = nil
        self.scheduleStartTime = nil
        self.scheduleEndTime = nil
        
        // Set permissions based on role
        if isOwner {
            self.canAddDogs = true
            self.canAddFutureBookings = true
            self.canManageStaff = true
            self.canManageMedications = true
            self.canManageFeeding = true
            self.canManageWalking = true
        } else {
            self.canAddDogs = true
            self.canAddFutureBookings = true
            self.canManageStaff = false
            self.canManageMedications = true
            self.canManageFeeding = true
            self.canManageWalking = true
        }
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
        profilePictureData: Data? = nil
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
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    init(from record: CKRecord) {
        self.id = record[CloudKitService.DogFields.id] as? String ?? ""
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