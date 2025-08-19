import CloudKit
import Foundation

@MainActor
class PersistentDogService: ObservableObject {
    static let shared = PersistentDogService()
    
    private let container = CKContainer(identifier: "iCloud.GreenHouse.Doggy-DayCare")
    private let publicDatabase: CKDatabase
    
    // Record type names
    struct RecordTypes {
        static let persistentDog = "PersistentDog"
    }
    
    // Field names for PersistentDog
    struct PersistentDogFields {
        static let id = "id"
        static let name = "name"
        static let ownerName = "ownerName"
        static let ownerPhoneNumber = "ownerPhoneNumber"
        static let age = "age"
        static let gender = "gender"
        // Individual vaccination fields
        static let bordetellaEndDate = "bordetellaEndDate"
        static let dhppEndDate = "dhppEndDate"
        static let rabiesEndDate = "rabiesEndDate"
        static let civEndDate = "civEndDate"
        static let leptospirosisEndDate = "leptospirosisEndDate"
        static let isNeuteredOrSpayed = "isNeuteredOrSpayed"
        static let allergiesAndFeedingInstructions = "allergiesAndFeedingInstructions"
        static let profilePictureData = "profilePictureData"
        static let visitCount = "visitCount"
        static let lastVisitDate = "lastVisitDate"
        static let needsWalking = "needsWalking"
        static let walkingNotes = "walkingNotes"
        static let isDaycareFed = "isDaycareFed"
        static let notes = "notes"
        static let specialInstructions = "specialInstructions"
        static let isDeleted = "isDeleted"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
        static let createdBy = "createdBy"
        static let lastModifiedBy = "lastModifiedBy"
    }
    
    private init() {
        self.publicDatabase = container.publicCloudDatabase
        #if DEBUG
        print("🔧 PersistentDogService initialized")
        #endif
    }
    
    // MARK: - CRUD Operations
    
    func createPersistentDog(_ dog: PersistentDog) async throws {
        #if DEBUG
        print("📝 Creating persistent dog: \(dog.name)")
        #endif
        
        let record = CKRecord(recordType: RecordTypes.persistentDog)
        
        // Set basic fields
        record[PersistentDogFields.id] = dog.id.uuidString
        record[PersistentDogFields.name] = dog.name
        record[PersistentDogFields.ownerName] = dog.ownerName
        record[PersistentDogFields.ownerPhoneNumber] = dog.ownerPhoneNumber
        record[PersistentDogFields.age] = dog.age
        record[PersistentDogFields.gender] = dog.gender?.rawValue
        record[PersistentDogFields.isNeuteredOrSpayed] = dog.isNeuteredOrSpayed
        record[PersistentDogFields.allergiesAndFeedingInstructions] = dog.allergiesAndFeedingInstructions
        record[PersistentDogFields.profilePictureData] = dog.profilePictureData
        record[PersistentDogFields.visitCount] = dog.visitCount
        record[PersistentDogFields.lastVisitDate] = dog.lastVisitDate
        record[PersistentDogFields.needsWalking] = dog.needsWalking ? 1 : 0
        record[PersistentDogFields.walkingNotes] = dog.walkingNotes
        record[PersistentDogFields.isDaycareFed] = dog.isDaycareFed ? 1 : 0
        record[PersistentDogFields.notes] = dog.notes
        record[PersistentDogFields.specialInstructions] = dog.specialInstructions
        record[PersistentDogFields.isDeleted] = dog.isDeleted ? 1 : 0
        record[PersistentDogFields.createdAt] = dog.createdAt
        record[PersistentDogFields.updatedAt] = dog.updatedAt
        record[PersistentDogFields.createdBy] = dog.createdBy
        record[PersistentDogFields.lastModifiedBy] = dog.lastModifiedBy
        
        // Set individual vaccination fields
        record[PersistentDogFields.bordetellaEndDate] = dog.vaccinations.first(where: { $0.name == "Bordetella" })?.endDate
        record[PersistentDogFields.dhppEndDate] = dog.vaccinations.first(where: { $0.name == "DHPP" })?.endDate
        record[PersistentDogFields.rabiesEndDate] = dog.vaccinations.first(where: { $0.name == "Rabies" })?.endDate
        record[PersistentDogFields.civEndDate] = dog.vaccinations.first(where: { $0.name == "CIV" })?.endDate
        record[PersistentDogFields.leptospirosisEndDate] = dog.vaccinations.first(where: { $0.name == "Leptospirosis" })?.endDate
        
        try await publicDatabase.save(record)
        #if DEBUG
        print("✅ Created persistent dog: \(dog.name)")
        #endif
    }
    
    func updatePersistentDog(_ dog: PersistentDog) async throws {
        #if DEBUG
        print("📝 Updating persistent dog: \(dog.name)")
        #endif
        
        let predicate = NSPredicate(format: "\(PersistentDogFields.id) == %@", dog.id.uuidString)
        let query = CKQuery(recordType: RecordTypes.persistentDog, predicate: predicate)
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let record = records.first else {
            throw CloudKitError.recordNotFound
        }
        
        // Update fields
        record[PersistentDogFields.name] = dog.name
        record[PersistentDogFields.ownerName] = dog.ownerName
        record[PersistentDogFields.ownerPhoneNumber] = dog.ownerPhoneNumber
        record[PersistentDogFields.age] = dog.age
        record[PersistentDogFields.gender] = dog.gender?.rawValue
        record[PersistentDogFields.isNeuteredOrSpayed] = dog.isNeuteredOrSpayed
        record[PersistentDogFields.allergiesAndFeedingInstructions] = dog.allergiesAndFeedingInstructions
        record[PersistentDogFields.profilePictureData] = dog.profilePictureData
        record[PersistentDogFields.visitCount] = dog.visitCount
        record[PersistentDogFields.lastVisitDate] = dog.lastVisitDate
        record[PersistentDogFields.needsWalking] = dog.needsWalking ? 1 : 0
        record[PersistentDogFields.walkingNotes] = dog.walkingNotes
        record[PersistentDogFields.isDaycareFed] = dog.isDaycareFed ? 1 : 0
        record[PersistentDogFields.notes] = dog.notes
        record[PersistentDogFields.specialInstructions] = dog.specialInstructions
        record[PersistentDogFields.isDeleted] = dog.isDeleted ? 1 : 0
        record[PersistentDogFields.updatedAt] = Date()
        record[PersistentDogFields.lastModifiedBy] = dog.lastModifiedBy
        
        // Update individual vaccination fields
        record[PersistentDogFields.bordetellaEndDate] = dog.vaccinations.first(where: { $0.name == "Bordetella" })?.endDate
        record[PersistentDogFields.dhppEndDate] = dog.vaccinations.first(where: { $0.name == "DHPP" })?.endDate
        record[PersistentDogFields.rabiesEndDate] = dog.vaccinations.first(where: { $0.name == "Rabies" })?.endDate
        record[PersistentDogFields.civEndDate] = dog.vaccinations.first(where: { $0.name == "CIV" })?.endDate
        record[PersistentDogFields.leptospirosisEndDate] = dog.vaccinations.first(where: { $0.name == "Leptospirosis" })?.endDate
        
        try await publicDatabase.save(record)
        #if DEBUG
        print("✅ Updated persistent dog: \(dog.name)")
        #endif
    }
    
    func fetchPersistentDog(by id: UUID) async throws -> PersistentDog? {
        #if DEBUG
        print("🔍 Fetching persistent dog by ID: \(id)")
        #endif
        
        let predicate = NSPredicate(format: "%K == %@", PersistentDogFields.id, id.uuidString)
        let dogs = try await fetchPersistentDogs(predicate: predicate)
        return dogs.first
    }
    
    func fetchPersistentDogs(predicate: NSPredicate? = nil, modifiedAfter: Date? = nil) async throws -> [PersistentDog] {
        #if DEBUG
        if let modifiedAfter = modifiedAfter {
            print("🔍 Fetching persistent dogs modified after: \(modifiedAfter)")
        } else {
            print("🔍 Fetching all persistent dogs...")
        }
        #endif
        
        var finalPredicate = predicate ?? NSPredicate(value: true)
        
        // Add timestamp filter for incremental sync
        if let modifiedAfter = modifiedAfter {
            let timestampPredicate = NSPredicate(format: "%K > %@", PersistentDogFields.updatedAt, modifiedAfter as NSDate)
            
            if predicate != nil {
                // Combine existing predicate with timestamp filter
                finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [finalPredicate, timestampPredicate])
            } else {
                finalPredicate = timestampPredicate
            }
            
            #if DEBUG
            print("🔍 Added timestamp filter: updatedAt > \(modifiedAfter)")
            #endif
        }
        
        let query = CKQuery(recordType: RecordTypes.persistentDog, predicate: finalPredicate)
        query.sortDescriptors = [NSSortDescriptor(key: PersistentDogFields.name, ascending: true)]
        
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        var persistentDogs: [PersistentDog] = []
        
        for record in records {
            guard let idString = record[PersistentDogFields.id] as? String,
                  let id = UUID(uuidString: idString),
                  let name = record[PersistentDogFields.name] as? String else {
                continue
            }
            
            let ownerName = record[PersistentDogFields.ownerName] as? String
            let ownerPhoneNumber = record[PersistentDogFields.ownerPhoneNumber] as? String
            let age = record[PersistentDogFields.age] as? Int
            let genderString = record[PersistentDogFields.gender] as? String
            let gender = genderString != nil ? DogGender(rawValue: genderString!) : nil
            let isNeuteredOrSpayed = record[PersistentDogFields.isNeuteredOrSpayed] as? Bool
            let allergiesAndFeedingInstructions = record[PersistentDogFields.allergiesAndFeedingInstructions] as? String
            let profilePictureData = record[PersistentDogFields.profilePictureData] as? Data
            let visitCount = record[PersistentDogFields.visitCount] as? Int ?? 0
            let lastVisitDate = record[PersistentDogFields.lastVisitDate] as? Date
            let needsWalking = (record[PersistentDogFields.needsWalking] as? Int64 ?? 0) == 1
            let walkingNotes = record[PersistentDogFields.walkingNotes] as? String
            let isDaycareFed = (record[PersistentDogFields.isDaycareFed] as? Int64 ?? 0) == 1
            let notes = record[PersistentDogFields.notes] as? String
            let specialInstructions = record[PersistentDogFields.specialInstructions] as? String
            let isDeleted = (record[PersistentDogFields.isDeleted] as? Int64 ?? 0) == 1
            let createdAt = record[PersistentDogFields.createdAt] as? Date ?? Date()
            let updatedAt = record[PersistentDogFields.updatedAt] as? Date ?? Date()
            let createdBy = record[PersistentDogFields.createdBy] as? String
            let lastModifiedBy = record[PersistentDogFields.lastModifiedBy] as? String
            
            // Reconstruct vaccinations from individual fields
            let bordetellaEndDate = record[PersistentDogFields.bordetellaEndDate] as? Date
            let dhppEndDate = record[PersistentDogFields.dhppEndDate] as? Date
            let rabiesEndDate = record[PersistentDogFields.rabiesEndDate] as? Date
            let civEndDate = record[PersistentDogFields.civEndDate] as? Date
            let leptospirosisEndDate = record[PersistentDogFields.leptospirosisEndDate] as? Date
            
            let vaccinations = [
                VaccinationItem(name: "Bordetella", endDate: bordetellaEndDate),
                VaccinationItem(name: "DHPP", endDate: dhppEndDate),
                VaccinationItem(name: "Rabies", endDate: rabiesEndDate),
                VaccinationItem(name: "CIV", endDate: civEndDate),
                VaccinationItem(name: "Leptospirosis", endDate: leptospirosisEndDate)
            ]
            
            let persistentDog = PersistentDog(
                id: id,
                name: name,
                ownerName: ownerName,
                ownerPhoneNumber: ownerPhoneNumber,
                age: age,
                gender: gender,
                vaccinations: vaccinations,
                isNeuteredOrSpayed: isNeuteredOrSpayed,
                allergiesAndFeedingInstructions: allergiesAndFeedingInstructions,
                profilePictureData: profilePictureData,
                visitCount: visitCount,
                lastVisitDate: lastVisitDate,
                needsWalking: needsWalking,
                walkingNotes: walkingNotes,
                isDaycareFed: isDaycareFed,
                notes: notes,
                specialInstructions: specialInstructions,
                isDeleted: isDeleted,
                createdAt: createdAt,
                updatedAt: updatedAt,
                createdBy: createdBy,
                lastModifiedBy: lastModifiedBy
            )
            
            persistentDogs.append(persistentDog)
        }
        
        #if DEBUG
        print("✅ Fetched \(persistentDogs.count) persistent dogs")
        #endif
        return persistentDogs
    }
    
    func deletePersistentDog(_ dog: PersistentDog) async throws {
        #if DEBUG
        print("🗑️ Deleting persistent dog: \(dog.name)")
        #endif
        
        let predicate = NSPredicate(format: "\(PersistentDogFields.id) == %@", dog.id.uuidString)
        let query = CKQuery(recordType: RecordTypes.persistentDog, predicate: predicate)
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let record = records.first else {
            throw CloudKitError.recordNotFound
        }
        
        try await publicDatabase.deleteRecord(withID: record.recordID)
        #if DEBUG
        print("✅ Deleted persistent dog: \(dog.name)")
        #endif
    }
    
    // MARK: - Utility Methods
    
    func findPersistentDogByNameAndOwner(name: String, ownerName: String?, ownerPhoneNumber: String?) -> PersistentDog? {
        // This will be implemented to find existing persistent dogs
        // For now, return nil as this is used during migration
        return nil
    }
}

// MARK: - CloudKit Error Extension
// Using CloudKitError from CloudKitService.swift 