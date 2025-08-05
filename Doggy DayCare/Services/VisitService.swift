import CloudKit
import Foundation

@MainActor
class VisitService: ObservableObject {
    static let shared = VisitService()
    
    private let container = CKContainer(identifier: "iCloud.GreenHouse.Doggy-DayCare")
    private let publicDatabase: CKDatabase
    
    // Record type names
    struct RecordTypes {
        static let visit = "Visit"
    }
    
    // Field names for Visit
    struct VisitFields {
        static let id = "id"
        static let dogId = "dogId"
        static let arrivalDate = "arrivalDate"
        static let departureDate = "departureDate"
        static let isBoarding = "isBoarding"
        static let boardingEndDate = "boardingEndDate"
        static let isDaycareFed = "isDaycareFed"
        static let notes = "notes"
        static let specialInstructions = "specialInstructions"
        static let needsWalking = "needsWalking"
        static let walkingNotes = "walkingNotes"
        static let isDeleted = "isDeleted"
        static let deletedAt = "deletedAt"
        static let deletedBy = "deletedBy"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
        static let createdBy = "createdBy"
        static let lastModifiedBy = "lastModifiedBy"
        static let feedingRecords = "feedingRecords"
        static let medicationRecords = "medicationRecords"
        static let pottyRecords = "pottyRecords"
    }
    
    private init() {
        self.publicDatabase = container.publicCloudDatabase
        print("🔧 VisitService initialized")
    }
    
    // MARK: - CRUD Operations
    
    func createVisit(_ visit: Visit) async throws {
        print("📝 Creating visit for dog: \(visit.dogId)")
        
        let record = CKRecord(recordType: RecordTypes.visit)
        
        // Set basic fields
        record[VisitFields.id] = visit.id.uuidString
        record[VisitFields.dogId] = visit.dogId.uuidString
        record[VisitFields.arrivalDate] = visit.arrivalDate
        record[VisitFields.departureDate] = visit.departureDate
        record[VisitFields.isBoarding] = visit.isBoarding ? 1 : 0
        record[VisitFields.boardingEndDate] = visit.boardingEndDate
        record[VisitFields.isDaycareFed] = visit.isDaycareFed ? 1 : 0
        record[VisitFields.notes] = visit.notes
        record[VisitFields.specialInstructions] = visit.specialInstructions
        record[VisitFields.needsWalking] = visit.needsWalking ? 1 : 0
        record[VisitFields.walkingNotes] = visit.walkingNotes
        record[VisitFields.isDeleted] = visit.isDeleted ? 1 : 0
        record[VisitFields.deletedAt] = visit.deletedAt
        record[VisitFields.deletedBy] = visit.deletedBy
        record[VisitFields.createdAt] = visit.createdAt
        record[VisitFields.updatedAt] = visit.updatedAt
        record[VisitFields.createdBy] = visit.createdBy
        record[VisitFields.lastModifiedBy] = visit.lastModifiedBy
        
        // Set records
        let feedingData = try JSONEncoder().encode(visit.feedingRecords)
        record[VisitFields.feedingRecords] = feedingData
        
        let medicationData = try JSONEncoder().encode(visit.medicationRecords)
        record[VisitFields.medicationRecords] = medicationData
        
        let pottyData = try JSONEncoder().encode(visit.pottyRecords)
        record[VisitFields.pottyRecords] = pottyData
        
        try await publicDatabase.save(record)
        print("✅ Created visit for dog: \(visit.dogId)")
    }
    
    func updateVisit(_ visit: Visit) async throws {
        print("📝 Updating visit: \(visit.id)")
        
        let predicate = NSPredicate(format: "\(VisitFields.id) == %@", visit.id.uuidString)
        let query = CKQuery(recordType: RecordTypes.visit, predicate: predicate)
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let record = records.first else {
            throw CloudKitError.recordNotFound
        }
        
        // Update fields
        record[VisitFields.departureDate] = visit.departureDate
        record[VisitFields.isBoarding] = visit.isBoarding ? 1 : 0
        record[VisitFields.boardingEndDate] = visit.boardingEndDate
        record[VisitFields.isDaycareFed] = visit.isDaycareFed ? 1 : 0
        record[VisitFields.notes] = visit.notes
        record[VisitFields.specialInstructions] = visit.specialInstructions
        record[VisitFields.needsWalking] = visit.needsWalking ? 1 : 0
        record[VisitFields.walkingNotes] = visit.walkingNotes
        record[VisitFields.isDeleted] = visit.isDeleted ? 1 : 0
        record[VisitFields.deletedAt] = visit.deletedAt
        record[VisitFields.deletedBy] = visit.deletedBy
        record[VisitFields.updatedAt] = Date()
        record[VisitFields.lastModifiedBy] = visit.lastModifiedBy
        
        // Update records
        let feedingData = try JSONEncoder().encode(visit.feedingRecords)
        record[VisitFields.feedingRecords] = feedingData
        
        let medicationData = try JSONEncoder().encode(visit.medicationRecords)
        record[VisitFields.medicationRecords] = medicationData
        
        let pottyData = try JSONEncoder().encode(visit.pottyRecords)
        record[VisitFields.pottyRecords] = pottyData
        
        try await publicDatabase.save(record)
        print("✅ Updated visit: \(visit.id)")
    }
    
    func fetchVisits(predicate: NSPredicate? = nil) async throws -> [Visit] {
        print("🔍 Fetching visits...")
        
        let finalPredicate = predicate ?? NSPredicate(value: true)
        let query = CKQuery(recordType: RecordTypes.visit, predicate: finalPredicate)
        query.sortDescriptors = [NSSortDescriptor(key: VisitFields.arrivalDate, ascending: false)]
        
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        var visits: [Visit] = []
        
        for record in records {
            guard let idString = record[VisitFields.id] as? String,
                  let id = UUID(uuidString: idString),
                  let dogIdString = record[VisitFields.dogId] as? String,
                  let dogId = UUID(uuidString: dogIdString),
                  let arrivalDate = record[VisitFields.arrivalDate] as? Date else {
                continue
            }
            
            let departureDate = record[VisitFields.departureDate] as? Date
            let isBoarding = (record[VisitFields.isBoarding] as? Int64 ?? 0) == 1
            let boardingEndDate = record[VisitFields.boardingEndDate] as? Date
            let isDaycareFed = (record[VisitFields.isDaycareFed] as? Int64 ?? 0) == 1
            let notes = record[VisitFields.notes] as? String
            let specialInstructions = record[VisitFields.specialInstructions] as? String
            let needsWalking = (record[VisitFields.needsWalking] as? Int64 ?? 0) == 1
            let walkingNotes = record[VisitFields.walkingNotes] as? String
            let isDeleted = (record[VisitFields.isDeleted] as? Int64 ?? 0) == 1
            let deletedAt = record[VisitFields.deletedAt] as? Date
            let deletedBy = record[VisitFields.deletedBy] as? String
            let createdAt = record[VisitFields.createdAt] as? Date ?? Date()
            let updatedAt = record[VisitFields.updatedAt] as? Date ?? Date()
            let createdBy = record[VisitFields.createdBy] as? String
            let lastModifiedBy = record[VisitFields.lastModifiedBy] as? String
            
            // Decode records
            var feedingRecords: [FeedingRecord] = []
            if let feedingData = record[VisitFields.feedingRecords] as? Data {
                feedingRecords = (try? JSONDecoder().decode([FeedingRecord].self, from: feedingData)) ?? []
            }
            
            var medicationRecords: [MedicationRecord] = []
            if let medicationData = record[VisitFields.medicationRecords] as? Data {
                medicationRecords = (try? JSONDecoder().decode([MedicationRecord].self, from: medicationData)) ?? []
            }
            
            var pottyRecords: [PottyRecord] = []
            if let pottyData = record[VisitFields.pottyRecords] as? Data {
                pottyRecords = (try? JSONDecoder().decode([PottyRecord].self, from: pottyData)) ?? []
            }
            
            let visit = Visit(
                id: id,
                dogId: dogId,
                arrivalDate: arrivalDate,
                departureDate: departureDate,
                isBoarding: isBoarding,
                boardingEndDate: boardingEndDate,
                isDaycareFed: isDaycareFed,
                notes: notes,
                specialInstructions: specialInstructions,
                needsWalking: needsWalking,
                walkingNotes: walkingNotes,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                deletedBy: deletedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                createdBy: createdBy,
                lastModifiedBy: lastModifiedBy,
                feedingRecords: feedingRecords,
                medicationRecords: medicationRecords,
                pottyRecords: pottyRecords
            )
            
            visits.append(visit)
        }
        
        print("✅ Fetched \(visits.count) visits")
        return visits
    }
    
    func fetchVisitsForDog(_ dogId: UUID, includeDeleted: Bool = false) async throws -> [Visit] {
        let predicate: NSPredicate
        if includeDeleted {
            predicate = NSPredicate(format: "\(VisitFields.dogId) == %@", dogId.uuidString)
        } else {
            predicate = NSPredicate(format: "\(VisitFields.dogId) == %@ AND \(VisitFields.isDeleted) != %@", 
                                   dogId.uuidString, NSNumber(value: true))
        }
        return try await fetchVisits(predicate: predicate)
    }
    
    func fetchActiveVisits() async throws -> [Visit] {
        let now = Date()
        
        let predicate = NSPredicate(format: "\(VisitFields.arrivalDate) <= %@ AND \(VisitFields.departureDate) == nil AND \(VisitFields.isDeleted) != %@", 
                                   now as NSDate, NSNumber(value: true))
        return try await fetchVisits(predicate: predicate)
    }
    
    func fetchVisitsForDate(_ date: Date) async throws -> [Visit] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = NSPredicate(format: "\(VisitFields.arrivalDate) >= %@ AND \(VisitFields.arrivalDate) < %@ AND \(VisitFields.isDeleted) != %@", 
                                   startOfDay as NSDate, endOfDay as NSDate, NSNumber(value: true))
        return try await fetchVisits(predicate: predicate)
    }
    
    func deleteVisit(_ visit: Visit) async throws {
        print("🗑️ Deleting visit: \(visit.id)")
        
        let predicate = NSPredicate(format: "\(VisitFields.id) == %@", visit.id.uuidString)
        let query = CKQuery(recordType: RecordTypes.visit, predicate: predicate)
        let result = try await publicDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }
        
        guard let record = records.first else {
            throw CloudKitError.recordNotFound
        }
        
        try await publicDatabase.deleteRecord(withID: record.recordID)
        print("✅ Deleted visit: \(visit.id)")
    }
    
    // MARK: - Utility Methods
    
    func getActiveVisit(for dogId: UUID) async throws -> Visit? {
        let visits = try await fetchVisitsForDog(dogId)
        return visits.first { $0.isCurrentlyPresent }
    }
} 