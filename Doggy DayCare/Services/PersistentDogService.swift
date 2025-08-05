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
        static let vaccinations = "vaccinations"
        static let isNeuteredOrSpayed = "isNeuteredOrSpayed"
        static let allergiesAndFeedingInstructions = "allergiesAndFeedingInstructions"
        static let profilePictureData = "profilePictureData"
        static let medications = "medications"
        static let scheduledMedications = "scheduledMedications"
        static let visitCount = "visitCount"
        static let lastVisitDate = "lastVisitDate"
        static let isDeleted = "isDeleted"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
        static let createdBy = "createdBy"
        static let lastModifiedBy = "lastModifiedBy"
    }
    
    private init() {
        self.publicDatabase = container.publicCloudDatabase
        print("🔧 PersistentDogService initialized")
    }
    
    // MARK: - CRUD Operations
    
    func createPersistentDog(_ dog: PersistentDog) async throws {
        print("📝 Creating persistent dog: \(dog.name)")
        
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
        record[PersistentDogFields.isDeleted] = dog.isDeleted ? 1 : 0
        record[PersistentDogFields.createdAt] = dog.createdAt
        record[PersistentDogFields.updatedAt] = dog.updatedAt
        record[PersistentDogFields.createdBy] = dog.createdBy
        record[PersistentDogFields.lastModifiedBy] = dog.lastModifiedBy
        
        // Set vaccinations
        let vaccinationData = try JSONEncoder().encode(dog.vaccinations)
        record[PersistentDogFields.vaccinations] = vaccinationData
        
        // Set medications
        let medicationData = try JSONEncoder().encode(dog.medications)
        record[PersistentDogFields.medications] = medicationData
        
        // Set scheduled medications
        let scheduledMedicationData = try JSONEncoder().encode(dog.scheduledMedications)
        record[PersistentDogFields.scheduledMedications] = scheduledMedicationData
        
        try await publicDatabase.save(record)
        print("✅ Created persistent dog: \(dog.name)")
    }
    
    func updatePersistentDog(_ dog: PersistentDog) async throws {
        print("📝 Updating persistent dog: \(dog.name)")
        
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
        record[PersistentDogFields.isDeleted] = dog.isDeleted ? 1 : 0
        record[PersistentDogFields.updatedAt] = Date()
        record[PersistentDogFields.lastModifiedBy] = dog.lastModifiedBy
        
        // Update vaccinations
        let vaccinationData = try JSONEncoder().encode(dog.vaccinations)
        record[PersistentDogFields.vaccinations] = vaccinationData
        
        // Update medications
        let medicationData = try JSONEncoder().encode(dog.medications)
        record[PersistentDogFields.medications] = medicationData
        
        // Update scheduled medications
        let scheduledMedicationData = try JSONEncoder().encode(dog.scheduledMedications)
        record[PersistentDogFields.scheduledMedications] = scheduledMedicationData
        
        try await publicDatabase.save(record)
        print("✅ Updated persistent dog: \(dog.name)")
    }
    
    func fetchPersistentDogs(predicate: NSPredicate? = nil) async throws -> [PersistentDog] {
        print("🔍 Fetching persistent dogs...")
        
        let finalPredicate = predicate ?? NSPredicate(value: true)
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
            let isDeleted = (record[PersistentDogFields.isDeleted] as? Int64 ?? 0) == 1
            let createdAt = record[PersistentDogFields.createdAt] as? Date ?? Date()
            let updatedAt = record[PersistentDogFields.updatedAt] as? Date ?? Date()
            let createdBy = record[PersistentDogFields.createdBy] as? String
            let lastModifiedBy = record[PersistentDogFields.lastModifiedBy] as? String
            
            // Decode vaccinations
            var vaccinations: [VaccinationItem] = []
            if let vaccinationData = record[PersistentDogFields.vaccinations] as? Data {
                vaccinations = (try? JSONDecoder().decode([VaccinationItem].self, from: vaccinationData)) ?? []
            }
            
            // Decode medications
            var medications: [Medication] = []
            if let medicationData = record[PersistentDogFields.medications] as? Data {
                medications = (try? JSONDecoder().decode([Medication].self, from: medicationData)) ?? []
            }
            
            // Decode scheduled medications
            var scheduledMedications: [ScheduledMedication] = []
            if let scheduledMedicationData = record[PersistentDogFields.scheduledMedications] as? Data {
                scheduledMedications = (try? JSONDecoder().decode([ScheduledMedication].self, from: scheduledMedicationData)) ?? []
            }
            
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
                medications: medications,
                scheduledMedications: scheduledMedications,
                visitCount: visitCount,
                lastVisitDate: lastVisitDate,
                isDeleted: isDeleted,
                createdAt: createdAt,
                updatedAt: updatedAt,
                createdBy: createdBy,
                lastModifiedBy: lastModifiedBy
            )
            
            persistentDogs.append(persistentDog)
        }
        
        print("✅ Fetched \(persistentDogs.count) persistent dogs")
        return persistentDogs
    }
    
    func deletePersistentDog(_ dog: PersistentDog) async throws {
        print("🗑️ Deleting persistent dog: \(dog.name)")
        
        let predicate = NSPredicate(format: "\(PersistentDogFields.id) == %@", dog.id.uuidString)
        let query = CKQuery(recordType: RecordTypes.persistentDog, predicate: predicate)
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let record = records.first else {
            throw CloudKitError.recordNotFound
        }
        
        try await publicDatabase.deleteRecord(withID: record.recordID)
        print("✅ Deleted persistent dog: \(dog.name)")
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